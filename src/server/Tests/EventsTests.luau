--!strict
-- Unit tests: deterministic rotation + active-event/shelf resolution.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rotation = require(ReplicatedStorage.Shared.Util.Rotation)
local EventConfig = require(ReplicatedStorage.Shared.Config.EventConfig)

local function eq(a: any, b: any, label: string?)
	if a ~= b then
		error(("%s: expected %s, got %s"):format(label or "eq", tostring(b), tostring(a)), 2)
	end
end

return {
	name = "Events",
	tests = {
		["rotation: same window is deterministic, distinct indices"] = function()
			local a = Rotation.pick(5, 10, 3)
			local b = Rotation.pick(5, 10, 3)
			eq(#a, 3)
			eq(table.concat(a, ","), table.concat(b, ","), "same window must be stable")
			local seen = {}
			for _, v in a do
				assert(not seen[v], "picks must be distinct")
				assert(v >= 1 and v <= 10, "in range")
				seen[v] = true
			end
		end,

		["rotation: window index + end advance with time"] = function()
			eq(Rotation.windowIndex(0, 100), 0)
			eq(Rotation.windowIndex(99, 100), 0)
			eq(Rotation.windowIndex(100, 100), 1)
			eq(Rotation.windowEndsAt(50, 100), 100)
			eq(Rotation.windowEndsAt(150, 100), 200)
		end,

		["rotation: different windows usually differ"] = function()
			local changes = 0
			local prev = Rotation.pick(0, 10, 3)
			for w = 1, 12 do
				local cur = Rotation.pick(w, 10, 3)
				if table.concat(cur, ",") ~= table.concat(prev, ",") then
					changes += 1
				end
				prev = cur
			end
			assert(changes >= 6, "rotation should shuffle across windows: " .. changes)
		end,

		["rotation: count clamps to pool size"] = function()
			eq(#Rotation.pick(3, 4, 99), 4)
		end,

		["crafting: active events resolve without a player"] = function()
			local CraftingService = require(script.Parent.Parent.Services.CraftingService)
			local events = CraftingService.activeEvents(os.time())
			assert(#events >= 1, "expected at least one active event from config")
			-- rotating recipes present when configured
			if EventConfig.RotatingRecipes and EventConfig.RotatingRecipes.enabled then
				local hasRotating = false
				for _, e in events do
					if e.id == "evt_rotating" then
						hasRotating = true
						assert(#e.recipes == EventConfig.RotatingRecipes.ActiveCount, "rotating ActiveCount")
					end
				end
				assert(hasRotating, "rotating event should be active")
			end
		end,

		["crafting: findActiveRecipe matches only active recipes"] = function()
			local CraftingService = require(script.Parent.Parent.Services.CraftingService)
			local now = os.time()
			-- a configured always-on event recipe resolves
			local forge = CraftingService.findActiveRecipe("evt_forge", "molten_idol", now)
			assert(forge ~= nil, "forge recipe should be active")
			-- nonsense ids do not
			eq(CraftingService.findActiveRecipe("evt_forge", "nope", now), nil)
			eq(CraftingService.findActiveRecipe("evt_nope", "molten_idol", now), nil)
		end,

		["store: rotating shelf picks ActiveCount items deterministically"] = function()
			local StoreService = require(script.Parent.Parent.Services.StoreService)
			local StoreConfig = require(ReplicatedStorage.Shared.Config.StoreConfig)
			local shelf, rotatesAt = StoreService.activeShelf(os.time())
			local n = 0
			for _ in shelf do
				n += 1
			end
			if StoreConfig.Rotation and StoreConfig.Rotation.enabled then
				eq(n, StoreConfig.Rotation.ActiveCount, "shelf size = ActiveCount")
				assert(rotatesAt ~= nil, "rotating shelf has a rotatesAt")
			end
		end,
	},
}
