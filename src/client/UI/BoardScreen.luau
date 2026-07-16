--!strict
-- Trade board wiring (the pillar). Panel + templates live in StarterGui.
-- Two tabs:
--   * TRADES — item-for-item swap listings (AUTO = instant accept, ASK =
--     register interest). Posting opens the trade window in compose mode;
--     the want side accepts trade-ad tokens (Upgrade, Any, …) from
--     WildcardConfig, which force the listing to ask-first.
--   * MARKET — the per-item order book (buy orders + sell listings, priced
--     in gems). All of it lives in MarketScreen; this file just switches.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local WildcardConfig = require(ReplicatedStorage.Shared.Config.WildcardConfig)
local Tax = require(ReplicatedStorage.Shared.Util.Tax)
local Net = require(script.Parent.Parent.Net)
local EconomyController = require(script.Parent.Parent.Controllers.EconomyController)
local TradeController = require(script.Parent.Parent.Controllers.TradeController)
local NotificationController = require(script.Parent.Parent.Controllers.NotificationController)
local TradeScreen = require(script.Parent.TradeScreen)
local MarketScreen = require(script.Parent.MarketScreen)

local BoardScreen = {}

function BoardScreen.wire(gui: ScreenGui, tooltip: any, toast: (text: string, color: Color3) -> ())
	MarketScreen.wire(gui, tooltip, toast)

	local panel = gui:WaitForChild("BoardPanel") :: Frame
	local list = panel:WaitForChild("ListingList") :: ScrollingFrame
	local rowTemplate = list:WaitForChild("ListingRow") :: Frame
	local chipTemplate = (rowTemplate:WaitForChild("GiveHolder") :: Frame):WaitForChild("Chip") :: Frame
	local emptyLabel = panel:WaitForChild("EmptyLabel") :: TextLabel

	local spawned: { Instance } = {}
	local lastListings: { any }? = nil
	local busy = false
	local refresh
	local activeTab: "swap" | "market" = "swap"

	local closeBtn = panel:WaitForChild("CloseButton") :: TextButton
	closeBtn.Activated:Connect(function()
		panel.Visible = false
		MarketScreen.hide() -- stop background refreshes while closed
	end)

	local function clearRendered()
		for _, inst in spawned do
			inst:Destroy()
		end
		table.clear(spawned)
	end

	-- One offer chip. Real items hover to live stats; trade-ad tokens hover
	-- to their explanation. Gems are never a chip — see fillOfferChips.
	local function addChip(holder: Frame, imageId: string?, name: string, countText: string, order: number, itemId: string?, isWildcard: boolean?)
		local chip = chipTemplate:Clone()
		chip.Visible = true
		chip.LayoutOrder = order
		Components.setIcon(chip:WaitForChild("Icon") :: ImageLabel, { imageId = imageId, name = name })
		;(chip:WaitForChild("CountLabel") :: TextLabel).Text = countText
		chip.Parent = holder
		table.insert(spawned, chip)
		if itemId and not isWildcard then
			EconomyController.ensure({ itemId })
		end
		tooltip.attach(chip, function()
			if isWildcard and itemId then
				return WildcardConfig.snapshot(itemId), nil
			end
			if itemId then
				return EconomyController.get(itemId) or { name = name, imageId = imageId }, nil
			end
			return { name = name, imageId = imageId }, nil
		end)
	end

	-- Item cards only in the chip row; gems are never a fake item card — just
	-- an icon + "+N gems (after tax)" line under the holder.
	local function fillOfferChips(holder: Frame, gemsIcon: ImageLabel, gemsLabel: TextLabel, offer: any)
		local order = 0
		for _, entry in offer.items do
			order += 1
			local countText = entry.wildcard and "" or ("x" .. entry.count)
			addChip(holder, entry.imageId, entry.name, countText, order, entry.itemId, entry.wildcard)
		end
		local hasGems = offer.gems > 0
		gemsIcon.Visible = hasGems
		gemsLabel.Text = hasGems and ("+%d gems (after tax)"):format(Tax.split(offer.gems)) or ""
	end

	local function invokeAction(fn: () -> any): any
		if busy then
			return nil
		end
		busy = true
		local result = fn()
		busy = false
		return result
	end

	local function renderListing(listing: any, order: number)
		local row = rowTemplate:Clone()
		row.Name = "listing_" .. listing.id
		row.Visible = true
		row.LayoutOrder = order
		row.Parent = list
		table.insert(spawned, row)

		local giveHolder = row:WaitForChild("GiveHolder") :: Frame
		local wantHolder = row:WaitForChild("WantHolder") :: Frame
		local giveGemsIcon = row:WaitForChild("GiveGemsIcon") :: ImageLabel
		local giveGemsLabel = row:WaitForChild("GiveGemsLabel") :: TextLabel
		local wantGemsIcon = row:WaitForChild("WantGemsIcon") :: ImageLabel
		local wantGemsLabel = row:WaitForChild("WantGemsLabel") :: TextLabel
		local info = row:WaitForChild("InfoLabel") :: TextLabel
		local badge = row:WaitForChild("Badge") :: TextLabel
		local countBox = row:WaitForChild("CountBox") :: TextBox
		local action = row:WaitForChild("ActionButton") :: TextButton
		countBox.Visible = false
		;(row:WaitForChild("PosterLabel") :: TextLabel).Text = listing.posterName
			.. (listing.mine and " (you)" or "")

		badge.Text = listing.autoTrade and "AUTO-TRADE" or "ASK FIRST"
		badge.TextColor3 = listing.autoTrade and Theme.Good or Theme.Warn
		fillOfferChips(giveHolder, giveGemsIcon, giveGemsLabel, listing.give) -- what the poster GIVES you
		fillOfferChips(wantHolder, wantGemsIcon, wantGemsLabel, listing.want) -- what they WANT from you
		if listing.mine and #listing.interested > 0 then
			local names = {}
			for _, e in listing.interested do
				table.insert(names, e.name)
			end
			info.Text = "Interested: " .. table.concat(names, ", ")
		end

		if listing.mine then
			if #listing.interested > 0 then
				action.Text = "Invite: " .. listing.interested[1].name
				action.BackgroundColor3 = Theme.Accent
				action.Activated:Connect(function()
					TradeController.requestTrade(listing.interested[1].userId)
					toast("Trade request sent to " .. listing.interested[1].name, Theme.Good)
				end)
				badge.Text ..= "  (yours)"
			else
				action.Text = "Cancel"
				action.BackgroundColor3 = Theme.Bad
				action.Activated:Connect(function()
					local result = invokeAction(function()
						return Net.invoke("CancelListing", listing.id)
					end)
					if result and result.ok then
						toast("Listing cancelled — escrow returned.", Theme.Warn)
					end
					refresh()
				end)
			end
		elseif listing.autoTrade then
			action.Text = "Accept"
			action.BackgroundColor3 = Theme.Good
			action.Activated:Connect(function()
				local result = invokeAction(function()
					return Net.invoke("AcceptListing", listing.id)
				end)
				if result then
					if result.ok then
						toast("Trade complete!", Theme.Good)
					elseif result.err == "gone" then
						toast("Too late — that listing is gone.", Theme.Warn)
					else
						toast("Couldn't accept: " .. tostring(result.err), Theme.Bad)
					end
				end
				refresh()
			end)
		else
			action.Text = "I'm interested"
			action.BackgroundColor3 = Theme.Accent
			action.Activated:Connect(function()
				local result = invokeAction(function()
					return Net.invoke("RegisterInterest", listing.id)
				end)
				if result then
					if result.ok then
						toast("The poster has been notified!", Theme.Good)
					elseif result.err == "already_interested" then
						toast("You already pinged this one.", Theme.Warn)
					else
						toast("Failed: " .. tostring(result.err), Theme.Bad)
					end
				end
			end)
		end
	end

	local function renderBoard(listings: { any })
		clearRendered()
		local shown = 0
		for _, listing in listings do
			if listing.kind == "swap" then
				shown += 1
				renderListing(listing, shown)
			end
		end
		emptyLabel.Visible = shown == 0 and activeTab == "swap"
		emptyLabel.Text = "No trades posted — hit + to post one!"
	end

	refresh = function()
		task.spawn(function()
			local result = Net.invoke("GetBoard")
			if result.ok then
				lastListings = result.listings
				if panel.Visible and activeTab == "swap" then
					renderBoard(result.listings)
				end
			end
		end)
	end

	--------------------------------------------------------------------------
	-- Tabs
	--------------------------------------------------------------------------

	local postBtn = panel:WaitForChild("PostButton") :: TextButton
	postBtn.Text = "+ Post trade"

	local tabRow = panel:WaitForChild("TabRow") :: Frame
	local tabButtons = {
		swap = tabRow:WaitForChild("TabTrades") :: TextButton,
		market = tabRow:WaitForChild("TabMarket") :: TextButton,
	}
	local function selectTab(tab: "swap" | "market")
		activeTab = tab
		for key, btn in tabButtons do
			btn.BackgroundColor3 = (key == tab) and Theme.Accent or Theme.BgLight
		end
		if tab == "swap" then
			MarketScreen.hide()
			list.Visible = true
			postBtn.Visible = true
			if lastListings then
				renderBoard(lastListings)
			end
			refresh()
		else
			clearRendered()
			emptyLabel.Visible = false
			list.Visible = false
			postBtn.Visible = false
			MarketScreen.show()
		end
	end
	for tab, btn in tabButtons do
		btn.Activated:Connect(function()
			selectTab(tab :: any)
		end)
	end

	function BoardScreen.open()
		Components.closeOtherPanels(panel)
		panel.Visible = true
		selectTab(activeTab)
	end

	function BoardScreen.toggle()
		if panel.Visible then
			panel.Visible = false
			MarketScreen.hide()
		else
			BoardScreen.open()
		end
	end

	-- public: open the board straight to a given tab (pillar deep-link / tests)
	function BoardScreen.openTab(tab: "swap" | "market")
		activeTab = tab
		BoardScreen.open()
	end

	--------------------------------------------------------------------------
	-- Posting a swap: the trade window in compose mode
	--------------------------------------------------------------------------

	postBtn.Activated:Connect(function()
		panel.Visible = false
		TradeScreen.openCompose(function(give, want, auto)
			task.spawn(function()
				local result = Net.invoke("PostListing", {
					kind = "swap",
					give = give,
					want = want,
					autoTrade = auto,
				})
				toast(result.ok and "Posted to the board!" or ("Couldn't post: " .. tostring(result.err)), result.ok and Theme.Good or Theme.Bad)
				if result.ok then
					NotificationController.promptOptIn(
						"Enable notifications so we can tell you about activity on this trade!",
						toast
					)
				end
				BoardScreen.open()
			end)
		end)
	end)

	selectTab("swap")
end

return BoardScreen
