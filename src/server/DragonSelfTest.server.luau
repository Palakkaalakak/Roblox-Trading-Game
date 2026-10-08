--!strict
-- Studio-only diagnostics: transforms on spawn, prints one compact report. Disable via DragonConfig.SELF_TEST.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Dragon = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Dragon")
local Config = require(Dragon:WaitForChild("DragonConfig"))
local Joints = require(Dragon:WaitForChild("DragonJoints"))
if not (RunService:IsStudio() and Config.SELF_TEST) then
	return
end
local setForm = ReplicatedStorage:WaitForChild("DragonRemotes"):WaitForChild("SetForm") :: BindableEvent

local function run(player: Player)
	local char = player.Character or player.CharacterAdded:Wait()
	char:WaitForChild("HumanoidRootPart")
	task.wait(2)
	setForm:Fire(player, true)
	task.wait(0.5)
	local out = { "[DragonSelfTest]" }
	local src = require(Dragon:WaitForChild("DragonRig")).findSource()
	table.insert(out, "source model: " .. (if src then src:GetFullName() else "NOT FOUND (placeholders)"))
	local missing = {}
	for _, j in ipairs(Joints) do
		local p = src and src:FindFirstChild(j.name, true)
		if not (p and p:IsA("MeshPart")) then
			table.insert(missing, j.name)
		end
	end
	table.insert(out, "missing MeshParts: " .. (if #missing == 0 then "none" else table.concat(missing, ", ")))
	local d = char:FindFirstChild("WestDragon")
	if not d then
		table.insert(out, "dragon NOT built (check Output for errors above)")
		print(table.concat(out, "\n"))
		return
	end
	local motors, parts = 0, 0
	for _, x in ipairs(d:GetDescendants()) do
		if x:IsA("Motor6D") then motors += 1 elseif x:IsA("BasePart") then parts += 1 end
	end
	local cf, size = (d :: Model):GetBoundingBox()
	local hrp = char.HumanoidRootPart :: BasePart
	local head = d:FindFirstChild("Head") :: BasePart?
	local torso = d:FindFirstChild("Torso") :: BasePart?
	table.insert(out, string.format("parts=%d (want 45) motors=%d (want 44)", parts, motors))
	table.insert(out, string.format("bbox size=(%.1f, %.1f, %.1f) lowestY-HRP=%.1f", size.X, size.Y, size.Z, (cf.Position.Y - size.Y / 2) - hrp.Position.Y))
	if head and torso then
		local fwd = (head.Position - torso.Position) * Vector3.new(1, 0, 1)
		table.insert(out, string.format("head faces HRP look dot=%.2f (want ~+1)", fwd.Unit:Dot(hrp.CFrame.LookVector)))
	end
	table.insert(out, "anchored parts: " .. tostring(#(function() local a = {} for _, x in ipairs(d:GetDescendants()) do if x:IsA("BasePart") and x.Anchored then table.insert(a, x.Name) end end return a end)()))
	table.insert(out, "form attr=" .. tostring(char:GetAttribute("DragonForm")))
	print(table.concat(out, "\n"))
end

Players.PlayerAdded:Connect(function(p) task.spawn(run, p) end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(run, p) end
