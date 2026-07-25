--!strict
-- Free Gems screen. Its own panel, its own cyan identity — nothing here points
-- at the Robux shop.
--
-- Two states, driven entirely by the server snapshot:
--   * LOCKED  — the community goal bar. Free gems need the game to be
--     ads-eligible (Roblox requires 2,000+ visitors), so the requirement is
--     shown as a shared target everyone moves just by playing.
--   * UNLOCKED — the watch-an-ad view: reward, daily allowance, cooldown.
--
-- The watch button hides itself whenever Roblox reports no ad fill, so the
-- screen never offers something that would fail.

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Net = require(script.Parent.Parent.Net)

local FreeGemsScreen = {}

local function comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function mmss(seconds: number): string
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	if m > 0 then
		return ("%dm %02ds"):format(m, s)
	end
	return ("%ds"):format(s)
end

function FreeGemsScreen.wire(gui: ScreenGui, toast: (text: string, color: Color3) -> ())
	local panel = gui:WaitForChild("FreeGemsPanel") :: Frame
	local goalView = panel:WaitForChild("GoalView") :: Frame
	local watchView = panel:WaitForChild("WatchView") :: Frame

	local barFill = (goalView:WaitForChild("BarTrack") :: Frame):WaitForChild("BarFill") :: Frame
	local progressLbl = goalView:WaitForChild("ProgressLabel") :: TextLabel
	local goalBlurb = goalView:WaitForChild("GoalBlurb") :: TextLabel
	local inviteBtn = goalView:WaitForChild("InviteButton") :: TextButton
	local bonusBlurb = goalView:WaitForChild("BonusBlurb") :: TextLabel

	local rewardLbl = watchView:WaitForChild("RewardLabel") :: TextLabel
	local watchBtn = watchView:WaitForChild("WatchButton") :: TextButton
	local remainingLbl = watchView:WaitForChild("RemainingLabel") :: TextLabel
	local statusLbl = watchView:WaitForChild("StatusLabel") :: TextLabel

	;(panel:WaitForChild("CloseButton") :: TextButton).Activated:Connect(function()
		panel.Visible = false
	end)

	local busy = false
	local latest: any = nil

	-- Roblox's own invite prompt. The launch data names this player, so when a
	-- friend accepts and joins, the server can credit the referral (see
	-- ReferralService). SocialService is client-only, and CanSendGameInviteAsync
	-- can be false (age/platform), in which case we say so instead of opening a
	-- prompt that would fail.
	inviteBtn.Activated:Connect(function()
		local player = Players.LocalPlayer
		local canInvite = false
		pcall(function()
			canInvite = SocialService:CanSendGameInviteAsync(player)
		end)
		if not canInvite then
			toast("You can't send invites on this account.", Theme.Warn)
			return
		end
		local ok = pcall(function()
			local options = Instance.new("ExperienceInviteOptions")
			options.launchData = "ref_" .. tostring(player.UserId)
			options.promptMessage = "Join me — help us hit the goal and unlock free gems!"
			SocialService:PromptGameInvite(player, options)
		end)
		if not ok then
			-- older clients don't take ExperienceInviteOptions; still invite,
			-- just without referral attribution
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		end
	end)

	local function render(snap: any)
		latest = snap
		goalView.Visible = not snap.unlocked
		watchView.Visible = snap.unlocked

		if not snap.unlocked then
			barFill.Size = UDim2.fromScale(snap.progress, 1)
			progressLbl.Text = ("%s / %s players"):format(comma(snap.players), comma(snap.target))
			goalBlurb.Text = ("When we reach %s players ANYONE will be able to get gems with just a few ads!")
				:format(comma(snap.target))
			-- the referral offer, and how close this player is to earning it
			if snap.bonusEligible then
				bonusBlurb.Text = ("★ Bonus unlocked — you and your friends get +%d%% gems on your first %d ad watches!")
					:format(snap.bonusPercent, snap.bonusLeft > 0 and snap.bonusLeft or 0)
			else
				bonusBlurb.Text = ("Invite %d friends who join and all %d of you get +%d%% gems on your first %d ad watches. (%d/%d invited)")
					:format(
						snap.referralsNeeded,
						snap.referralsNeeded + 1,
						snap.bonusPercent,
						15,
						math.min(snap.referrals, snap.referralsNeeded),
						snap.referralsNeeded
					)
			end
			return
		end

		rewardLbl.Text = snap.bonusEligible and snap.bonusLeft > 0
				and ("Watch a short ad for +%d gems  (+%d%% bonus, %d left)"):format(snap.reward, snap.bonusPercent, snap.bonusLeft)
			or ("Watch a short ad for +%d gems"):format(snap.reward)
		remainingLbl.Text = ("%d / %d today"):format(snap.remaining, snap.cap)

		-- the button only appears when Roblox will actually serve an ad
		if snap.remaining <= 0 then
			watchBtn.Visible = false
			statusLbl.Text = "You've claimed every ad reward for today — come back tomorrow."
		elseif snap.cooldown > 0 then
			watchBtn.Visible = false
			statusLbl.Text = ("Next ad in %s."):format(mmss(snap.cooldown))
		elseif not snap.available then
			watchBtn.Visible = false
			statusLbl.Text = "No ad available right now. Try again in a bit."
		else
			watchBtn.Visible = true
			statusLbl.Text = ""
		end
	end

	local function refresh()
		task.spawn(function()
			local result = Net.invoke("GetFreeGems")
			if result and result.ok and panel.Visible then
				render(result)
			end
		end)
	end

	watchBtn.Activated:Connect(function()
		if busy then
			return
		end
		busy = true
		watchBtn.Visible = false
		statusLbl.Text = "Loading ad…"
		local result = Net.invoke("WatchAd")
		busy = false
		if result and result.ok then
			-- gems arrive through the purchase pipeline, so the balance updates
			-- on its own; just re-read the counters
			toast(("+%d gems — thanks for watching!"):format(latest and latest.reward or 0), Theme.Good)
		elseif result then
			local why = ({
				locked = "Free gems aren't unlocked yet.",
				daily_cap = "That's every ad reward for today.",
				cooldown = "Not just yet — give it a moment.",
				no_ad = "No ad available right now.",
				ad_failed = "That ad couldn't be loaded.",
				not_completed = "You need to watch the whole ad to get the gems.",
			})[result.err] or "Couldn't play that ad."
			toast(why, Theme.Warn)
		end
		refresh()
	end)

	-- keep the cooldown honest while the panel sits open
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.Visible and latest and latest.unlocked and latest.cooldown > 0 then
				latest.cooldown -= 1
				render(latest)
			end
		end
	end)

	function FreeGemsScreen.open()
		Components.closeOtherPanels(panel)
		panel.Visible = true
		refresh()
	end

	function FreeGemsScreen.toggle()
		if panel.Visible then
			panel.Visible = false
		else
			FreeGemsScreen.open()
		end
	end
end

return FreeGemsScreen
