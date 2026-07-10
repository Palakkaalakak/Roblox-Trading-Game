--!strict
-- NotificationController: client-side entry point for Roblox's real
-- ExperienceNotificationService opt-in prompt. Safe to call from multiple
-- trigger points — Roblox itself won't show it twice (already opted in,
-- already declined/seen within 30 days, or under 13 all silently no-op).
-- Roblox's own permission dialog text is fixed and NOT customizable, so the
-- "explain why" is our own toast shown just before it, only when Roblox
-- confirms the system dialog will actually appear (no toast otherwise).

local NotificationController = {}

-- Call at any moment that "warrants a future notification" (Roblox's own
-- guidance) — e.g. right after posting a board listing, not just once
-- generically on join. `explainText`/`toast` are optional; pass both to show
-- a one-line reason before the OS prompt, or neither for a silent attempt.
function NotificationController.promptOptIn(explainText: string?, toast: ((text: string, color: Color3) -> ())?)
	task.spawn(function()
		local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
		local ok, canPrompt = pcall(function()
			return ExperienceNotificationService:CanPromptOptInAsync()
		end)
		if not ok or not canPrompt then
			return
		end
		if explainText and toast then
			toast(explainText, Color3.fromRGB(120, 220, 232))
			task.wait(1.5) -- let them read it before the OS dialog steals focus
		end
		pcall(function()
			ExperienceNotificationService:PromptOptIn()
		end)
	end)
end

function NotificationController.Init() end
function NotificationController.Start() end

return NotificationController
