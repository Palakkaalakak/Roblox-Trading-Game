--!strict
-- StoreAdapters: thin seams over DataStoreService / MemoryStoreService /
-- MessagingService with in-memory mock fallback.
--
-- Why: in Studio without published place + "Enable Studio Access to API
-- Services", all three services throw. Every consumer goes through these
-- adapters; availability is probed once at boot and the whole layer flips to
-- deterministic in-memory mocks (single-server semantics, loopback messaging).
-- Live and mock expose identical async signatures so no caller branches.
--
-- Mock semantics deliberately match what the code relies on:
--   * dataStore:  UpdateAsync(key, fn) atomic read-modify-write, Get/Set
--   * sortedMap:  UpdateAsync(key, fn, ttl) CAS-style transform, Get/Set/Remove
--   * messaging:  publish/subscribe loopback (fires local subscribers)

local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

-- STUDIO: MemoryStore is used for the cross-server order book, and under bot
-- load Studio's implementation throws "InternalError ... SortedMap.GetRange /
-- SortedMap.Get" constantly. Those come from inside the service and Studio logs
-- them itself, so our pcall/withRetry can swallow the failure but cannot stop
-- the log line — the output drowns in them (and it evicts everything else from
-- the buffer). A single Studio session has no other server to coordinate with
-- anyway, so the sorted map runs on the in-memory mock here. DataStore is
-- untouched, and production (IsStudio() == false) keeps the real MemoryStore.
-- Same rationale as SessionStore skipping lock contention in Studio.
local IN_STUDIO = RunService:IsStudio()

local Signal = require(game:GetService("ReplicatedStorage").Shared.Util.Signal)

local StoreAdapters = {}
StoreAdapters.mode = "unknown" -- "live" | "mock"

-- deep copy for mock isolation (values crossing the mock boundary must not alias)
local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = deepCopy(x)
	end
	return out
end

--------------------------------------------------------------------------------
-- Probe
--------------------------------------------------------------------------------

local function probeLive(): boolean
	local ok = pcall(function()
		local ds = DataStoreService:GetDataStore("__probe__")
		ds:GetAsync("__probe__")
	end)
	return ok
end

--------------------------------------------------------------------------------
-- Mock backends (module-level so all adapters share one world per server)
--------------------------------------------------------------------------------

local mockData: { [string]: { [string]: any } } = {} -- storeName -> key -> value
local mockMaps: { [string]: { [string]: any } } = {} -- mapName -> key -> value
local mockTopics: { [string]: any } = {} -- topic -> Signal

local function mockDataStore(name: string)
	mockData[name] = mockData[name] or {}
	local store = mockData[name]
	local api = {}
	function api.GetAsync(_, key: string): any
		return deepCopy(store[key])
	end
	function api.SetAsync(_, key: string, value: any)
		store[key] = deepCopy(value)
	end
	function api.UpdateAsync(_, key: string, transform: (any) -> any): any
		local new = transform(deepCopy(store[key]))
		if new ~= nil then
			store[key] = deepCopy(new)
		end
		return deepCopy(store[key])
	end
	return api
end

local function mockSortedMap(name: string)
	mockMaps[name] = mockMaps[name] or {}
	local map = mockMaps[name]
	local api = {}
	function api.GetAsync(_, key: string): any
		return deepCopy(map[key])
	end
	function api.SetAsync(_, key: string, value: any, _ttl: number?)
		map[key] = deepCopy(value)
	end
	function api.UpdateAsync(_, key: string, transform: (any) -> any, _ttl: number?): any
		local new = transform(deepCopy(map[key]))
		if new == nil then
			-- MemoryStore semantics: nil from transform aborts the update
			return nil
		end
		map[key] = deepCopy(new)
		return deepCopy(new)
	end
	function api.RemoveAsync(_, key: string)
		map[key] = nil
	end
	-- `count` entries by key order (direction-aware), paged via `bound`
	-- (exclusive: after it when Ascending, before it when Descending).
	function api.GetRangeAsync(_, direction: any, count: number, bound: string?): { any }
		local descending = direction == Enum.SortDirection.Descending
		local keys = {}
		for k in map do
			if bound == nil or (descending and k < bound) or (not descending and k > bound) then
				table.insert(keys, k)
			end
		end
		table.sort(keys, function(a, b)
			if descending then
				return a > b
			end
			return a < b
		end)
		local out = {}
		for i = 1, math.min(count, #keys) do
			table.insert(out, { key = keys[i], value = deepCopy(map[keys[i]]) })
		end
		return out
	end
	return api
end

-- Ordered store: leaderboards. Same shape as OrderedDataStore — SetAsync a
-- numeric score per key, then read the top N descending. The mock keeps the
-- pairs in a table and sorts on read, which matches what callers rely on
-- (ranking + "my score"), not OrderedDataStore's paging internals.
local mockOrdered: { [string]: { [string]: number } } = {} -- storeName -> key -> score

local function mockOrderedStore(name: string)
	mockOrdered[name] = mockOrdered[name] or {}
	local store = mockOrdered[name]
	local api = {}
	function api.SetAsync(_, key: string, value: number)
		store[key] = value
	end
	function api.GetAsync(_, key: string): number?
		return store[key]
	end
	-- top `count` entries, highest score first; ties broken by key for
	-- determinism so a page never reorders between reads
	function api.GetTopAsync(_, count: number): { { key: string, value: number } }
		local rows = {}
		for k, v in store do
			table.insert(rows, { key = k, value = v })
		end
		table.sort(rows, function(a, b)
			if a.value ~= b.value then
				return a.value > b.value
			end
			return a.key < b.key
		end)
		local out = {}
		for i = 1, math.min(count, #rows) do
			out[i] = rows[i]
		end
		return out
	end
	return api
end

--------------------------------------------------------------------------------
-- Live wrappers (retry with backoff; MemoryStore map passed through)
--------------------------------------------------------------------------------

local function withRetry<T>(label: string, attempts: number, fn: () -> T): (boolean, T?)
	local delaySec = 0.5
	for i = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("[Stores] %s failed (attempt %d/%d): %s"):format(label, i, attempts, tostring(result)))
		if i < attempts then
			task.wait(delaySec)
			delaySec = math.min(delaySec * 2, 8)
		end
	end
	return false, nil
end

local function liveDataStore(name: string)
	local ds = DataStoreService:GetDataStore(name)
	local api = {}
	function api.GetAsync(_, key: string): any
		local ok, v = withRetry("GetAsync " .. name .. "/" .. key, 3, function()
			return ds:GetAsync(key)
		end)
		if not ok then
			error("datastore_get_failed:" .. key)
		end
		return v
	end
	function api.SetAsync(_, key: string, value: any)
		local ok = withRetry("SetAsync " .. name .. "/" .. key, 3, function()
			return ds:SetAsync(key, value)
		end)
		if not ok then
			error("datastore_set_failed:" .. key)
		end
	end
	function api.UpdateAsync(_, key: string, transform: (any) -> any): any
		local ok, v = withRetry("UpdateAsync " .. name .. "/" .. key, 3, function()
			return ds:UpdateAsync(key, transform)
		end)
		if not ok then
			error("datastore_update_failed:" .. key)
		end
		return v
	end
	return api
end

local function liveSortedMap(name: string)
	local map = MemoryStoreService:GetSortedMap(name)
	local DEFAULT_TTL = 30 * 24 * 3600 -- 30d, well under the 45d cap
	local api = {}
	function api.GetAsync(_, key: string): any
		local ok, v = withRetry("Map GetAsync " .. name .. "/" .. key, 3, function()
			return map:GetAsync(key)
		end)
		if not ok then
			error("map_get_failed:" .. key)
		end
		return v
	end
	function api.SetAsync(_, key: string, value: any, ttl: number?)
		local ok = withRetry("Map SetAsync " .. name .. "/" .. key, 3, function()
			return map:SetAsync(key, value, ttl or DEFAULT_TTL)
		end)
		if not ok then
			error("map_set_failed:" .. key)
		end
	end
	function api.UpdateAsync(_, key: string, transform: (any) -> any, ttl: number?): any
		local ok, v = withRetry("Map UpdateAsync " .. name .. "/" .. key, 3, function()
			return map:UpdateAsync(key, transform, ttl or DEFAULT_TTL)
		end)
		if not ok then
			error("map_update_failed:" .. key)
		end
		return v
	end
	function api.RemoveAsync(_, key: string)
		withRetry("Map RemoveAsync " .. name .. "/" .. key, 2, function()
			return map:RemoveAsync(key)
		end)
	end
	-- `bound` pages: keys strictly AFTER it (Ascending) / BEFORE it (Descending).
	function api.GetRangeAsync(_, direction: any, count: number, bound: string?): { any }
		direction = direction or Enum.SortDirection.Ascending
		local ok, page = withRetry("Map GetRangeAsync " .. name, 3, function()
			if direction == Enum.SortDirection.Descending then
				return map:GetRangeAsync(direction, math.min(count, 200), nil, bound)
			end
			return map:GetRangeAsync(direction, math.min(count, 200), bound, nil)
		end)
		if not ok or page == nil then
			return {}
		end
		return page
	end
	return api
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function StoreAdapters.init()
	if StoreAdapters.mode ~= "unknown" then
		return
	end
	StoreAdapters.mode = probeLive() and "live" or "mock"
	print("[Stores] mode = " .. StoreAdapters.mode)
end

function StoreAdapters.dataStore(name: string)
	assert(StoreAdapters.mode ~= "unknown", "StoreAdapters.init() not called")
	if StoreAdapters.mode == "live" then
		return liveDataStore(name)
	end
	return mockDataStore(name)
end

-- Leaderboard backend. Live uses OrderedDataStore; Studio/mock keeps an
-- in-memory table with the same three calls, so LeaderboardService never
-- branches on mode (same live/mock split as dataStore and sortedMap).
function StoreAdapters.orderedStore(name: string)
	assert(StoreAdapters.mode ~= "unknown", "StoreAdapters.init() not called")
	if StoreAdapters.mode ~= "live" then
		return mockOrderedStore(name)
	end
	local store = DataStoreService:GetOrderedDataStore(name)
	local api = {}
	function api.SetAsync(_, key: string, value: number)
		withRetry("Ordered SetAsync " .. name, 3, function()
			store:SetAsync(key, value)
		end)
	end
	function api.GetAsync(_, key: string): number?
		local ok, v = withRetry("Ordered GetAsync " .. name, 3, function()
			return store:GetAsync(key)
		end)
		return ok and v or nil
	end
	function api.GetTopAsync(_, count: number): { { key: string, value: number } }
		local ok, page = withRetry("Ordered GetSorted " .. name, 3, function()
			return store:GetSortedAsync(false, math.min(count, 100)):GetCurrentPage()
		end)
		if not ok or page == nil then
			return {}
		end
		local out = {}
		for i, entry in page do
			out[i] = { key = entry.key, value = entry.value }
		end
		return out
	end
	return api
end

function StoreAdapters.sortedMap(name: string)
	assert(StoreAdapters.mode ~= "unknown", "StoreAdapters.init() not called")
	-- see IN_STUDIO at the top of this file: Studio's MemoryStore spams internal
	-- errors under load and we cannot suppress its own logging
	if StoreAdapters.mode == "live" and not IN_STUDIO then
		return liveSortedMap(name)
	end
	return mockSortedMap(name)
end

-- publish/subscribe: topic strings, table payloads (<=~1KB in live mode —
-- callers publish invalidation pings + ids, never full records).
function StoreAdapters.publish(topic: string, payload: any)
	if StoreAdapters.mode == "live" then
		task.spawn(function()
			local ok, err = pcall(function()
				MessagingService:PublishAsync(topic, HttpService:JSONEncode(payload))
			end)
			if not ok then
				warn("[Stores] publish failed on " .. topic .. ": " .. tostring(err))
			end
		end)
	else
		local sig = mockTopics[topic]
		if sig then
			sig:Fire(deepCopy(payload))
		end
	end
end

function StoreAdapters.subscribe(topic: string, fn: (payload: any) -> ())
	if StoreAdapters.mode == "live" then
		task.spawn(function()
			local ok, err = pcall(function()
				MessagingService:SubscribeAsync(topic, function(message)
					local decoded = nil
					pcall(function()
						decoded = HttpService:JSONDecode(message.Data)
					end)
					if decoded ~= nil then
						fn(decoded)
					end
				end)
			end)
			if not ok then
				warn("[Stores] subscribe failed on " .. topic .. ": " .. tostring(err))
			end
		end)
	else
		mockTopics[topic] = mockTopics[topic] or Signal.new()
		mockTopics[topic]:Connect(fn)
	end
end

return StoreAdapters
