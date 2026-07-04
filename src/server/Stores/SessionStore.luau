--!strict
-- SessionStore: session-locked player persistence (ProfileStore-equivalent,
-- deliberately minimal; swap for loleris/ProfileStore later without touching
-- callers — DataService is the only consumer).
--
-- Locking: profile key holds { Lock = {owner, expiry}, Data = {...} }.
-- Load takes the lock via UpdateAsync CAS; a live, foreign lock rejects the
-- load (caller kicks the player). Heartbeat refreshes lock + saves Data.
-- Release saves and clears the lock. Prevents the same profile being active on
-- two servers -> the classic duplication exploit.

local StoreAdapters = require(script.Parent.StoreAdapters)

local LOCK_TTL = 90 -- seconds a lock is honored without heartbeat
local HEARTBEAT = 30 -- autosave + lock refresh cadence

local SessionStore = {}
SessionStore.__index = SessionStore

export type Session = {
	key: string,
	Data: any,
	release: (self: Session) -> (),
	save: (self: Session) -> boolean,
	isActive: (self: Session) -> boolean,
}

local ownerId = game.JobId ~= "" and game.JobId or "studio-" .. tostring(math.floor(os.clock() * 1000))

function SessionStore.new(storeName: string, template: () -> any)
	local self = setmetatable({
		_store = StoreAdapters.dataStore(storeName),
		_template = template,
		_sessions = {} :: { [string]: any },
		_closing = false,
	}, SessionStore)

	-- heartbeat: refresh locks + persist data for all active sessions
	task.spawn(function()
		while not self._closing do
			task.wait(HEARTBEAT)
			for key, session in self._sessions do
				if session._active then
					task.spawn(function()
						session:save()
					end)
				end
			end
		end
	end)

	return self
end

-- Attempt to load + lock. Returns Session or (nil, reason).
function SessionStore.load(self: any, key: string): (Session?, string?)
	if self._closing then
		return nil, "shutting_down"
	end
	if self._sessions[key] then
		return nil, "already_loaded_here"
	end

	local now = os.time()
	local locked = false
	local ok, err = pcall(function()
		self._store:UpdateAsync(key, function(old)
			old = old or {}
			local lock = old.Lock
			if lock and lock.owner ~= ownerId and lock.expiry > now then
				locked = true
				return nil -- abort: someone else holds a live lock
			end
			old.Lock = { owner = ownerId, expiry = now + LOCK_TTL }
			if old.Data == nil then
				old.Data = self._template()
			end
			return old
		end)
	end)
	if not ok then
		return nil, "store_error:" .. tostring(err)
	end
	if locked then
		return nil, "session_locked_elsewhere"
	end

	-- re-read to get the committed Data (UpdateAsync returned value already is it,
	-- but keep one canonical read path)
	local record
	local ok2, err2 = pcall(function()
		record = self._store:GetAsync(key)
	end)
	if not ok2 or record == nil or record.Data == nil then
		return nil, "post_load_read_failed:" .. tostring(err2)
	end

	local session = setmetatable({
		key = key,
		Data = record.Data,
		_active = true,
		_parent = self,
	}, {
		__index = {
			save = function(s): boolean
				if not s._active then
					return false
				end
				local saved = pcall(function()
					s._parent._store:UpdateAsync(s.key, function(old)
						old = old or {}
						old.Data = s.Data
						old.Lock = { owner = ownerId, expiry = os.time() + LOCK_TTL }
						return old
					end)
				end)
				return saved
			end,
			release = function(s)
				if not s._active then
					return
				end
				s._active = false
				s._parent._sessions[s.key] = nil
				pcall(function()
					s._parent._store:UpdateAsync(s.key, function(old)
						old = old or {}
						old.Data = s.Data
						old.Lock = nil
						return old
					end)
				end)
			end,
			isActive = function(s): boolean
				return s._active
			end,
		},
	})

	self._sessions[key] = session
	return (session :: any) :: Session, nil
end

-- Transform a profile's Data WITHOUT holding the session (offline-safe writes).
-- Only use for stores designed for concurrent append (e.g. mailbox), never for
-- whole-profile mutation — the session owner's saves would clobber it.
function SessionStore.updateDetached(self: any, key: string, transform: (any) -> any): boolean
	local ok = pcall(function()
		self._store:UpdateAsync(key, transform)
	end)
	return ok
end

function SessionStore.peek(self: any, key: string): any
	local record
	pcall(function()
		record = self._store:GetAsync(key)
	end)
	return record
end

function SessionStore.releaseAll(self: any)
	self._closing = true
	for _, session in self._sessions do
		session:release()
	end
end

return SessionStore
