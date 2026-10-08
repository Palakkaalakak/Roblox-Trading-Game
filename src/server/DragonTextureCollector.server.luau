--!nocheck
-- Synced by Rojo (src/server). Studio only, gated by DragonConfig.COLLECT_TEXTURES. Press Play.
-- It reads Workspace.textures (a Folder), one child per texture named like the config key
-- (flame_orange_4x4, spark_star, ...), resolves each to a real image id, preloads it to check it,
-- and prints a ready-to-paste TEXTURES table. It also stores the same text in
-- ServerStorage.DragonTextureIdsLua (StringValue): while still in Play mode select it in the
-- Explorer and copy its Value from Properties, then stop Play and paste into DragonConfig.TEXTURES
-- (or send it to Claude).
--
-- Each child of the textures folder may be any of: Decal / Texture (Texture), ImageLabel /
-- ImageButton (Image), MeshPart (TextureID), SurfaceAppearance (ColorMap), String/NumberValue
-- (asset id), or a Part/Folder/Model holding one of those. The child's NAME is the key
-- (".png" and spaces/dashes are normalised).

local ContentProvider = game:GetService("ContentProvider")
local InsertService = game:GetService("InsertService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Cfg = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Dragon"):WaitForChild("DragonConfig"))
if not (RunService:IsStudio() and RunService:IsRunning() and Cfg.COLLECT_TEXTURES) then
	return
end
task.wait(2) -- let the workspace finish loading
local function dbg(...)
	print("[TexDebug]", ...)
end
dbg("running as", script:GetFullName(), "| studio:", RunService:IsStudio(), "| server:", RunService:IsServer())
local ok0, err0 = pcall(function()

local KEYS = {
	"flame_orange_4x4", "flame_violet_4x4", "flame_crimson_4x4",
	"explosion_orange_4x4", "explosion_violet_4x4", "explosion_crimson_4x4",
	"smoke_2x2", "spark_star", "shock_ring", "slash_arc",
	"beam_lightning", "beam_flame_orange", "beam_flame_violet",
	"crack_burst", "sigil", "lava_rock",
}
local known = {}
for _, k in ipairs(KEYS) do
	known[k] = true
end

local function normalise(name: string): string
	name = string.lower(name)
	name = string.gsub(name, "%.png$", "")
	name = string.gsub(name, "[%s%-]+", "_")
	return name
end

local function rawIdOf(inst: Instance): string?
	if inst:IsA("Decal") or inst:IsA("Texture") then
		return inst.Texture
	elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
		return inst.Image
	elseif inst:IsA("MeshPart") and inst.TextureID ~= "" then
		return inst.TextureID
	elseif inst:IsA("SurfaceAppearance") then
		return inst.ColorMap
	elseif inst:IsA("StringValue") then
		return inst.Value
	elseif inst:IsA("NumberValue") or inst:IsA("IntValue") then
		return tostring(inst.Value)
	end
	return nil
end

local function findRaw(inst: Instance): string?
	local r = rawIdOf(inst)
	if r and r ~= "" then
		return r
	end
	for _, d in ipairs(inst:GetDescendants()) do
		local rr = rawIdOf(d)
		if rr and rr ~= "" then
			return rr
		end
	end
	return nil
end

-- A "Decal" asset id is not an image id: load it and read the real image id out of it.
local function resolve(raw: string): (string?, string)
	local num = string.match(raw, "%d+")
	if not num then
		return nil, "no id in '" .. raw .. "'"
	end
	-- LoadAsset can yield for a long time (or forever) on non-model ids: give it 8 s.
	local done, ok, model = false, false, nil
	task.spawn(function()
		ok, model = pcall(InsertService.LoadAsset, InsertService, tonumber(num))
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 8 do
		task.wait(0.1)
	end
	if done and ok and model then
		local inner = model:FindFirstChildWhichIsA("Decal", true) or model:FindFirstChildWhichIsA("Texture", true)
		local img = inner and (inner :: any).Texture
		model:Destroy()
		local n2 = img and string.match(img, "%d+")
		if n2 then
			return "rbxassetid://" .. n2, "resolved decal " .. num .. " -> image " .. n2
		end
	end
	return "rbxassetid://" .. num, "used as image id"
end

local folder = workspace:FindFirstChild("textures") or workspace:FindFirstChild("Textures")
if not folder then
	local names = {}
	for _, c in ipairs(workspace:GetChildren()) do
		table.insert(names, c.Name)
	end
	warn("[CollectTextureIds] no Folder named 'textures' in Workspace. Workspace children: " .. table.concat(names, ", "))
	return
end
dbg("folder:", folder:GetFullName(), folder.ClassName)

print("[CollectTextureIds] " .. #folder:GetChildren() .. " items in " .. folder.Name)
local found: { [string]: string } = {}
local notes, unmatched = {}, {}
for _, child in ipairs(folder:GetChildren()) do
	local key = normalise(child.Name)
	local raw = findRaw(child)
	dbg(string.format("item '%s' (%s) key=%s known=%s raw=%s", child.Name, child.ClassName, key, tostring(known[key]), tostring(raw)))
	if not raw then
		table.insert(unmatched, child.Name .. " (no texture/id found)")
	elseif not known[key] then
		table.insert(unmatched, child.Name .. " (name is not a config key)")
	else
		local id, note = resolve(raw)
		dbg("  resolve ->", tostring(id), "|", note)
		if id then
			found[key] = id
			table.insert(notes, key .. ": " .. note)
		else
			table.insert(unmatched, child.Name .. " (" .. note .. ")")
		end
	end
end

-- Preload to verify each id actually loads as an image.
local failed = {}
for key, id in pairs(found) do
	local img = Instance.new("ImageLabel")
	img.Image = id
	ContentProvider:PreloadAsync({ img }, function(url, status)
		dbg("  preload", key, tostring(status), url)
		if status ~= Enum.AssetFetchStatus.Success then
			failed[key] = tostring(status)
		end
	end)
	img:Destroy()
end

local lines = { "TEXTURES = {" }
local missing = {}
for _, k in ipairs(KEYS) do
	if found[k] then
		table.insert(lines, string.format('\t%s = "%s",', k, found[k]))
	else
		table.insert(lines, string.format('\t%s = "",', k))
		table.insert(missing, k)
	end
end
table.insert(lines, "},")
local text = table.concat(lines, "\n")

local sv = ServerStorage:FindFirstChild("DragonTextureIdsLua") or Instance.new("StringValue")
sv.Name = "DragonTextureIdsLua"
sv.Value = text
sv.Parent = ServerStorage

local report = { "[CollectTextureIds] " .. #KEYS - #missing .. "/" .. #KEYS .. " textures found" }
for _, n in ipairs(notes) do
	table.insert(report, "  " .. n)
end
for k, st in pairs(failed) do
	table.insert(report, "  LOAD FAILED " .. k .. ": " .. st .. " (wrong id type or not approved)")
end
for _, u in ipairs(unmatched) do
	table.insert(report, "  skipped: " .. u)
end
if #missing > 0 then
	table.insert(report, "  missing: " .. table.concat(missing, ", "))
end
table.insert(report, "--- paste into DragonConfig.luau (replace the TEXTURES table) ---")
table.insert(report, text)
print(table.concat(report, "\n"))
end)
if not ok0 then
	warn("[TexDebug] collector crashed: " .. tostring(err0))
end
