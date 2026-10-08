--!strict
-- RewardsBar: the Community Rewards progress bar at the top of the HUD.
-- GuiBuilder builds it (ensureHudNode); this only fills it and routes clicks.
-- The bar and its info button both call onOpen (init.client wires this to
-- the standalone RewardsPanel).

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local State = require(ReplicatedStorage.Shared.Util.State)
local GuiBuilder = require(ReplicatedStorage.Shared.GuiBuilder)
local RewardsController = require(script.Parent.Parent.Controllers.RewardsController)
local Theme = require(script.Parent.Theme)

local FILL_TWEEN = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local RewardsBar = {}

function RewardsBar.wire(hud: ScreenGui, onOpen: () -> (), toast: (string, Color3) -> ())
	local bar = GuiBuilder.ensureHudNode(hud, "RewardsBar") :: TextButton
	local track = bar:WaitForChild("Track") :: Frame
	local fill = track:WaitForChild("Fill") :: Frame
	local percent = track:WaitForChild("Percent") :: TextLabel
	local info = bar:WaitForChild("Info") :: TextButton

	bar.Activated:Connect(onOpen)
	info.Activated:Connect(onOpen)

	local painted = false
	local wasEligible: boolean? = nil
	State.Observe(RewardsController.status, function(status)
		-- tell them when they reach 100%: on the crossing, or once on join if
		-- they are already there
		if status.eligible and wasEligible ~= true then
			toast("Robux Rewards: 100%! You can now convert your gems. Tap the bar for details.", Theme.Gold)
		end
		wasEligible = status.eligible
		local shown = status.displayFraction
		percent.Text = ("%d%%"):format(math.floor(shown * 100))
		local size = UDim2.fromScale(shown, 1)
		-- Gold at 0%, shading toward red as it nears 100%. Exponent >1 so it
		-- starts clearly gold (not reddish at 1%, which a straight lerp did --
		-- Gold and Bad are both warm/red-leaning colors), but still under 2 so
		-- every percentage tick visibly shifts the color instead of sitting
		-- flat near-gold for a long stretch before snapping red at the end.
		local color = Theme.Gold:Lerp(Theme.Bad, shown ^ 1.4)
		if painted then
			TweenService:Create(fill, FILL_TWEEN, { Size = size, BackgroundColor3 = color }):Play()
		else
			fill.Size = size
			fill.BackgroundColor3 = color
			painted = true
		end
	end)
end

return RewardsBar
