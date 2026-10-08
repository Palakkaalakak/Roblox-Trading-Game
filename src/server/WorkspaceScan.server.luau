--!strict
-- Studio-only: prints workspace structure + where the dragon model lives, so remote (non-Studio) Claude sessions can read it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Dragon = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dragon")
local Config = require(Dragon:WaitForChild("DragonConfig"))
if not (RunService:IsStudio() and Config.SCAN) then
	return
end
task.wait(3)

local function fmt(i: Instance): string
	local s = i.ClassName .. " " .. i.Name
	if i:IsA("BasePart") then
		s ..= string.format(" size(%.1f,%.1f,%.1f) pos(%.1f,%.1f,%.1f)%s", i.Size.X, i.Size.Y, i.Size.Z, i.Position.X, i.Position.Y, i.Position.Z, if i.Anchored then " A" else "")
	end
	return s
end

local out = { "[WorkspaceScan] descendants=" .. #workspace:GetDescendants() }
local function walk(inst: Instance, depth: number, maxDepth: number)
	local kids = inst:GetChildren()
	-- collapse runs of same-named/same-class children
	local seen: { [string]: number } = {}
	for _, k in ipairs(kids) do
		local key = k.ClassName .. "|" .. k.Name
		seen[key] = (seen[key] or 0) + 1
		if seen[key] == 1 then
			local n = #k:GetChildren()
			table.insert(out, string.rep("  ", depth) .. fmt(k) .. (if n > 0 then " [" .. n .. " children]" else ""))
			if depth < maxDepth then
				walk(k, depth + 1, maxDepth)
			end
		end
	end
end
walk(workspace, 1, 2)

-- Texture folder + config ids, so texture problems are visible in one block.
local tf = workspace:FindFirstChild("textures") or workspace:FindFirstChild("Textures")
table.insert(out, "[TexturesFolder] " .. (if tf then tf:GetFullName() .. " children=" .. #tf:GetChildren() else "NOT FOUND in Workspace"))
if tf then
	for _, c in ipairs(tf:GetChildren()) do
		local x = c :: any
		local val = x.Texture or x.Image or x.TextureID or x.Value or x.ColorMap
		table.insert(out, "  " .. c.ClassName .. " " .. c.Name .. " -> " .. tostring(val))
	end
end
local set, total = 0, 0
for k, v in pairs(Config.TEXTURES or {}) do
	total += 1
	if v ~= "" then
		set += 1
	end
end
table.insert(out, string.format("[Config.TEXTURES] %d/%d ids set", set, total))
-- Dragon source model: full tree with sizes/positions.
local src = require(Dragon:WaitForChild("DragonRig")).findSource()
table.insert(out, "[DragonSource] " .. (if src then src:GetFullName() .. " (" .. src.ClassName .. ")" else "NOT FOUND"))
if src then
	for _, d in ipairs(src:GetDescendants()) do
		table.insert(out, "  " .. fmt(d) .. " <" .. d.Parent.Name .. ">" .. (if d:IsA("MeshPart") then " tex=" .. (if d.TextureID ~= "" then "y" else "n") else ""))
	end
end
for _, svc in ipairs({ ReplicatedStorage, game:GetService("ServerStorage") }) do
	for _, c in ipairs(svc:GetChildren()) do
		if c:IsA("Model") then
			table.insert(out, "[" .. svc.Name .. "] Model " .. c.Name .. " [" .. #c:GetDescendants() .. " descendants]")
		end
	end
end
print(table.concat(out, "\n"))
