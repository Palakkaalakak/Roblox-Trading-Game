--!strict
-- RankTitleController: the floating title above every player's head (social
-- proof for rank/quest progress). Purely cosmetic -- reads the RankTitle
-- attribute QuestService stamps onto each Player instance server-side and
-- keeps a BillboardGui in sync with it. No remote calls of its own.

local Players = game:GetService("Players")

local RankTitleController = {}

local function attach(player: Player)
	local function onCharacter(character: Model)
		local head = character:WaitForChild("Head", 5)
		if head == nil then
			return
		end
		local existing = head:FindFirstChild("RankTitleTag")
		if existing then
			existing:Destroy()
		end

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "RankTitleTag"
		-- Scale (studs), NOT offset (pixels): the tag is a fixed size IN THE WORLD, so
		-- it shrinks/grows on screen as the camera zooms like any other object.
		billboard.Size = UDim2.fromScale(7, 0.9)
		billboard.MaxDistance = 120
		billboard.StudsOffset = Vector3.new(0, 1.87, 0) -- just above the head
		billboard.AlwaysOnTop = true
		billboard.Parent = head

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		-- Noob stays plain white; earned titles are gold
		local function paint()
			local t = (player:GetAttribute("RankTitle") :: string?) or ""
			label.Text = t
			-- Entry titles are plain white: Noob/Casual quest ranks and the first
			-- (plain) profit tier. Everything above earns gold.
			local low = (player:GetAttribute("RankId") or 1) <= 2 or player:GetAttribute("RankTier") == 1
			label.TextColor3 = low and Color3.new(1, 1, 1) or Color3.fromRGB(255, 215, 0)
		end
		paint()
		label.Parent = billboard
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = 1.2
		stroke.Parent = label

		-- Effects per profit tier (gradients, glow, etc.) land later -- this is
		-- deliberately just the text for now.
		player:GetAttributeChangedSignal("RankTitle"):Connect(paint)
	end

	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

function RankTitleController.Init() end

function RankTitleController.Start()
	for _, player in Players:GetPlayers() do
		attach(player)
	end
	Players.PlayerAdded:Connect(attach)
end

return RankTitleController
