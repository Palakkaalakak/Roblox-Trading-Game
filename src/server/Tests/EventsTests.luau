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

		["crafting: active events respect enabled flags + windows"] = function()
			local CraftingService = require(script.Parent.Parent.Services.CraftingService)
			local now = os.time()
			local events = CraftingService.activeEvents(now)
			local activeIds = {}
			for _, e in events do
				activeIds[e.id] = true
			end
			-- config truth: disabled events must NOT be active, enabled ones must
			for _, event in EventConfig.Events do
				local shouldBeActive = event.enabled
					and (event.startsAt == nil or now >= event.startsAt)
					and (event.endsAt == nil or now < event.endsAt)
				eq(activeIds[event.id] == true, shouldBeActive, "active state of " .. event.id)
			end
			-- rotating section present exactly when enabled
			local rot = EventConfig.RotatingRecipes
			eq(activeIds["evt_rotating"] == true, rot ~= nil and rot.enabled == true, "rotating section")
		end,

		["crafting: findActiveRecipe honors enabled flags"] = function()
			local CraftingService = require(script.Parent.Parent.Services.CraftingService)
			local now = os.time()
			for _, event in EventConfig.Events do
				-- `enabled` alone isn't enough: a seasonal event that has passed
				-- its endsAt is switched off by the clock, and asserting on the
				-- flag by itself makes this test fail on a date rather than on a
				-- regression (which is exactly what it did once Midsummer ended).
				local active = event.enabled
					and (event.startsAt == nil or now >= event.startsAt)
					and (event.endsAt == nil or now < event.endsAt)
				for _, recipe in event.recipes do
					local found = CraftingService.findActiveRecipe(event.id, recipe.rid, now)
					if active then
						-- a permanent recipe may be SUBSTITUTED once sold out, so
						-- what must hold is that the station still offers a recipe,
						-- not that this exact rid comes back
						local limited = (event.endsAt or event.startsAt) ~= nil
						if found == nil and not limited then
							local station = nil
							for _, e in CraftingService.activeEvents(now) do
								if e.id == event.id then
									station = e
								end
							end
							assert(
								station ~= nil and #station.recipes > 0,
								event.id .. "/" .. recipe.rid .. " vanished with no replacement"
							)
						else
							assert(found ~= nil, event.id .. "/" .. recipe.rid .. " should resolve")
						end
					else
						eq(found, nil, event.id .. "/" .. recipe.rid .. " must NOT resolve when inactive")
					end
				end
			end
			-- nonsense ids never resolve
			eq(CraftingService.findActiveRecipe("evt_nope", "nope", now), nil)
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
