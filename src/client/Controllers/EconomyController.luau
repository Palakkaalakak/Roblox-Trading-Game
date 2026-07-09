--!strict
-- EconomyController: client mirror of per-item stat snapshots (value/demand/
-- supply/RAP with N/A states) + the current starter pool. Snapshots arrive
-- from StatsUpdated pushes; ensure() fetches anything not yet seen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.Util.State)
local Net = require(script.Parent.Parent.Net)

local EconomyController = {}

-- itemId -> StatSnapshot. Whole-table Value; set with force so observers fire.
EconomyController.stats = State.Value({} :: { [string]: any })
EconomyController.pool = State.Value(nil :: any) -- {poolId, seq, items}

local pendingRequest: { [string]: boolean } = {}

local function absorb(snapshots: { any })
	local current = EconomyController.stats:get()
	for _, snap in snapshots do
		current[snap.itemId] = snap
		pendingRequest[snap.itemId] = nil
	end
	EconomyController.stats:set(current, true)
end

-- Request snapshots for ids we don't have yet (batched, deduped).
function EconomyController.ensure(itemIds: { string })
	local missing = {}
	local have = EconomyController.stats:get()
	for _, itemId in itemIds do
		if have[itemId] == nil and not pendingRequest[itemId] then
			pendingRequest[itemId] = true
			table.insert(missing, itemId)
		end
	end
	if #missing == 0 then
		return
	end
	task.spawn(function()
		local result = Net.invoke("GetStats", missing)
		if result.ok then
			absorb(result.snapshots)
		else
			for _, itemId in missing do
				pendingRequest[itemId] = nil -- allow retry
			end
		end
	end)
end

-- Force-refetch snapshots for ids we already have (join-time pushes can be
-- lost while the client is still initializing; this reconciles).
function EconomyController.refresh(itemIds: { string })
	if #itemIds == 0 then
		return
	end
	task.spawn(function()
		local result = Net.invoke("GetStats", itemIds)
		if result.ok then
			absorb(result.snapshots)
		end
	end)
end

function EconomyController.get(itemId: string): any?
	return EconomyController.stats:get()[itemId]
end

function EconomyController.nameFor(itemId: string): string
	local snap = EconomyController.get(itemId)
	return snap and snap.name or itemId
end

function EconomyController.Init() end

function EconomyController.Start()
	Net.on("StatsUpdated", function(snapshots)
		if type(snapshots) == "table" then
			absorb(snapshots)
		end
	end)

	-- pre-warm current pool stats (fast retries while the server boots)
	task.spawn(function()
		for _ = 1, 60 do
			local result = Net.invoke("GetCurrentPool")
			if result.ok then
				EconomyController.pool:set({ poolId = result.poolId, seq = result.seq, items = result.items })
				absorb(result.items)
				break
			end
			task.wait(0.3)
		end
		-- reconcile pass: early snapshots may predate join-time economy writes
		task.wait(1)
		local known = {}
		for itemId in EconomyController.stats:get() do
			table.insert(known, itemId)
		end
		EconomyController.refresh(known)
	end)

	-- periodic re-sync: guarantees every client converges on identical stats
	-- even if a push was missed (nobody sees Value 1 while another sees N/A)
	task.spawn(function()
		while true do
			task.wait(45)
			local known = {}
			for itemId in EconomyController.stats:get() do
				table.insert(known, itemId)
			end
			if #known > 0 then
				EconomyController.refresh(known)
			end
		end
	end)
end

return EconomyController
