--!strict
-- Shop screen (Robux). Renders whatever MonetizationConfig declares — gem
-- packs today, gamepasses / subscriptions / bundles the moment they're added
-- to the config. One card template covers every product kind, so a new offer
-- needs no code here.
--
-- Sections come from the server payload, ordered by MonetizationConfig
-- .SectionOrder; a section with no live offers is skipped entirely, which is
-- why unreleased categories simply don't appear.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Net = require(script.Parent.Parent.Net)

local ShopScreen = {}

-- "1200" -> "1,200"
local function comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function timeLeftText(untilUnix: number): string
	local remaining = math.max(0, untilUnix - os.time())
	local days = math.floor(remaining / 86400)
	if days >= 1 then
		return ("%d day%s left"):format(days, days == 1 and "" or "s")
	end
	local hours = math.floor(remaining / 3600)
	if hours >= 1 then
		return ("%d hour%s left"):format(hours, hours == 1 and "" or "s")
	end
	return ("%d min left"):format(math.max(1, math.floor(remaining / 60)))
end

function ShopScreen.wire(gui: ScreenGui, tooltip: any, toast: (text: string, color: Color3) -> ())
	local panel = gui:WaitForChild("ShopPanel") :: Frame
	local body = panel:WaitForChild("Body") :: ScrollingFrame
	local sectionTemplate = body:WaitForChild("SectionTemplate") :: Frame
	local gridTemplate = sectionTemplate:WaitForChild("Grid") :: Frame
	local featuresTemplate = sectionTemplate:WaitForChild("Features") :: Frame
	local cardTemplate = gridTemplate:WaitForChild("OfferCard") :: Frame
	local featureTemplate = featuresTemplate:WaitForChild("FeatureCard") :: Frame
	local emptyLabel = panel:WaitForChild("EmptyLabel") :: TextLabel

	local closeBtn = (panel:WaitForChild("TitleBar") :: Frame):WaitForChild("CloseButton") :: TextButton
	closeBtn.Activated:Connect(function()
		panel.Visible = false
	end)

	local spawned: { Instance } = {}
	local busy = false
	-- section name or offer id to scroll to once the next render finishes.
	-- Cleared after it is honoured, so a later plain open() lands at the top.
	local pendingFocus: string? = nil

	local function clear()
		for _, inst in spawned do
			inst:Destroy()
		end
		table.clear(spawned)
	end

	-- BUY / OWNED state + purchase click. The button carries a green gradient
	-- from the template; OWNED disables it and greys it out.
	local function wireBuy(btn: TextButton, offer: any)
		local priceLbl = btn:WaitForChild("PriceLabel") :: TextLabel
		local robux = btn:FindFirstChild("RobuxIcon") :: ImageLabel?
		if offer.owned then
			priceLbl.Text = "OWNED"
			if robux then
				robux.Visible = false
			end
			btn.AutoButtonColor = false
			local g = btn:FindFirstChildOfClass("UIGradient")
			if g then
				g.Enabled = false
			end
			btn.BackgroundColor3 = Theme.BgLight
			return
		end
		-- show the real Robux price with the Bobux icon, Blox-Fruits style; fall
		-- back to a plain BUY only if the price couldn't be resolved
		if offer.price then
			priceLbl.Text = comma(offer.price)
			if robux then
				robux.Visible = true
			end
		else
			priceLbl.Text = "BUY"
			if robux then
				robux.Visible = false
			end
		end
		btn.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			local result = Net.invoke("PromptPurchase", offer.id)
			busy = false
			if result and not result.ok then
				toast("Couldn't open that purchase.", Theme.Bad)
			end
		end)
	end

	-- Fields both card kinds share: name, art, gem/blurb line, bonus line,
	-- strikethrough price, optional accent tint, and the buy button.
	--
	-- The Blox-Fruits card nests things (the name lives in the coloured banner,
	-- the old price sits inside the green price bar), so these are found
	-- recursively rather than as direct children.
	-- Development toggle, rendered ONLY when the server said so. The server
	-- attaches offer.adPerk for one account and omits it for everyone else, so
	-- there is nothing here to discover or spoof -- a client that fakes the
	-- field still gets refused by SetPerkDebug.
	--
	-- It exists because owning a pass is permanent: without this there is no way
	-- to see what the game looks like without one on an account that bought it.
	local refreshShop: () -> ()
	local function wirePerkDebug(cardInst: Frame, offer: any)
		local existing = cardInst:FindFirstChild("PerkDebugToggle")
		if existing then
			existing:Destroy()
		end
		if offer.adPerk == nil then
			return
		end
		local on = offer.perkOn == true
		local btn = Instance.new("TextButton")
		btn.Name = "PerkDebugToggle"
		-- Sits just ABOVE the buy button (which starts at 0.815 of the card), not
		-- over it. Anchored bottom so it grows upward and never eats the price.
		btn.AnchorPoint = Vector2.new(0.5, 1)
		btn.Position = UDim2.fromScale(0.5, 0.805)
		btn.Size = UDim2.fromScale(0.92, 0.10)
		btn.BackgroundColor3 = on and Theme.Good or Theme.Bad
		btn.BorderSizePixel = 0
		btn.Font = Enum.Font.GothamBold
		btn.TextScaled = true
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Text = on and "DEBUG: perk ON" or "DEBUG: perk OFF"
		btn.ZIndex = 20
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = btn
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = 12
		cap.Parent = btn
		btn.Parent = cardInst
		btn.Activated:Connect(function()
			local result = Net.invoke("SetPerkDebug", offer.id, not on)
			if result and result.ok then
				refreshShop()
			end
		end)
	end

	local function fillCommon(cardInst: Frame, offer: any)
		local nameLabel = cardInst:FindFirstChild("OfferName", true) :: TextLabel
		nameLabel.Text = offer.name
		if offer.nameColor then
			nameLabel.TextColor3 = Color3.fromRGB(offer.nameColor[1], offer.nameColor[2], offer.nameColor[3])
		end
		Components.setIcon(cardInst:WaitForChild("Icon") :: ImageLabel, { imageId = offer.imageId, name = offer.name })

		-- the art panel is light, so these read as dark ink (the reference does
		-- the same); gem counts stay the emphasis line, just not cyan-on-white
		local contents = cardInst:WaitForChild("Contents") :: TextLabel
		contents.Text = offer.gems and (comma(offer.gems) .. " Gems") or (offer.description or "")

		local bonus = cardInst:WaitForChild("Bonus") :: TextLabel
		if offer.bonusPercent then
			bonus.Text = ("+%d%% BONUS"):format(offer.bonusPercent)
			bonus.Visible = true
		else
			bonus.Visible = false
		end

		local wasPrice = cardInst:FindFirstChild("WasPrice", true) :: TextLabel
		local strike = wasPrice:WaitForChild("Strike") :: Frame
		if offer.wasRobux then
			wasPrice.Text = comma(offer.wasRobux)
			strike.Visible = true
		else
			wasPrice.Text = ""
			strike.Visible = false
		end

		-- per-offer accent recolors the card's border AND its name banner, so a
		-- card reads as one colour the way the reference's do
		if offer.accent then
			local tint = Color3.fromRGB(offer.accent[1], offer.accent[2], offer.accent[3])
			local s = cardInst:FindFirstChildOfClass("UIStroke")
			if s then
				s.Color = tint
			end
			local bannerInst = cardInst:FindFirstChild("NameBanner") :: Frame?
			if bannerInst then
				bannerInst.BackgroundColor3 = tint
			end
		end

		wireBuy(cardInst:WaitForChild("BuyButton") :: TextButton, offer)
		wirePerkDebug(cardInst, offer)
	end

	-- medium card (grid)
	local function renderCard(offer: any, parent: Frame, order: number)
		local card = cardTemplate:Clone()
		card.Name = "offer_" .. offer.id
		card.Visible = true
		card.LayoutOrder = order
		fillCommon(card, offer)

		local timeLeft = card:WaitForChild("TimeLeft") :: TextLabel
		timeLeft.Text = offer.availableUntil and timeLeftText(offer.availableUntil) or ""

		local badge = card:WaitForChild("Badge") :: TextLabel
		badge.Visible = offer.badge ~= nil
		badge.Text = offer.badge or ""

		card.Parent = parent
		table.insert(spawned, card)
	end

	-- wide hero card (feature). The badge becomes the ribbon headline.
	local function renderFeature(offer: any, parent: Frame, order: number)
		local card = featureTemplate:Clone()
		card.Name = "offer_" .. offer.id
		card.Visible = true
		card.LayoutOrder = order
		fillCommon(card, offer)

		local timeLeft = card:WaitForChild("TimeLeft") :: TextLabel
		timeLeft.Text = offer.availableUntil and timeLeftText(offer.availableUntil) or ""

		local ribbon = card:WaitForChild("Ribbon") :: Frame
		;(ribbon:WaitForChild("RibbonText") :: TextLabel).Text = offer.badge or "FEATURED"

		card.Parent = parent
		table.insert(spawned, card)
	end

	local function render(payload: any)
		clear()
		local offers = payload.offers or {}
		emptyLabel.Visible = #offers == 0
		if #offers == 0 then
			return
		end

		-- group by section, then lay sections out in the configured order
		local bySection: { [string]: { any } } = {}
		for _, offer in offers do
			local list = bySection[offer.section]
			if list == nil then
				list = {}
				bySection[offer.section] = list
			end
			table.insert(list, offer)
		end

		local layouts = payload.sectionLayout or {}

		local order = 0
		local seen: { [string]: boolean } = {}
		local function emitSection(sectionName: string)
			local list = bySection[sectionName]
			if list == nil or seen[sectionName] then
				return
			end
			seen[sectionName] = true
			order += 1
			local sec = sectionTemplate:Clone()
			sec.Name = "section_" .. sectionName
			sec.Visible = true
			sec.LayoutOrder = order
			;((sec:WaitForChild("SectionHeader") :: Frame):WaitForChild("Label") :: TextLabel).Text = sectionName

			local features = sec:WaitForChild("Features") :: Frame
			local grid = sec:WaitForChild("Grid") :: Frame

			-- per-section card size, so packs and passes aren't forced into one
			-- cell shape; sections without an entry keep the template's size
			local sizing = layouts[sectionName]
			if sizing then
				local gridLayout = grid:FindFirstChildOfClass("UIGridLayout")
				if gridLayout then
					gridLayout.CellSize = UDim2.fromOffset(sizing.width, sizing.height)
				end
			end
			-- drop the template clones that rode along
			for _, holder in { features, grid } do
				for _, child in holder:GetChildren() do
					if child:IsA("Frame") and (child.Name == "FeatureCard" or child.Name == "OfferCard") then
						child:Destroy()
					end
				end
			end

			-- featured offers become hero cards; the rest fill the grid
			local featOrder, gridOrder = 0, 0
			for _, offer in list do
				if offer.featured then
					featOrder += 1
					renderFeature(offer, features, featOrder)
				else
					gridOrder += 1
					renderCard(offer, grid, gridOrder)
				end
			end
			features.Visible = featOrder > 0
			grid.Visible = gridOrder > 0

			sec.Parent = body
			table.insert(spawned, sec)
		end

		for _, sectionName in payload.sectionOrder or {} do
			emitSection(sectionName)
		end
		-- any section the config didn't order still shows, just at the end
		for sectionName in bySection do
			emitSection(sectionName)
		end
	end

	-- Scroll the body so `target` sits at the top. Runs a frame late because a
	-- UIListLayout has not assigned AbsolutePosition to the freshly-parented
	-- sections yet at the moment render() returns.
	local function applyFocus()
		local target = pendingFocus
		pendingFocus = nil
		if target == nil then
			body.CanvasPosition = Vector2.new()
			return
		end
		task.defer(function()
			local node = body:FindFirstChild("section_" .. target)
				or body:FindFirstChild("offer_" .. target, true)
			if node == nil or not node:IsA("GuiObject") then
				return
			end
			-- walk up to the top-level section: scrolling to the card itself
			-- would hide the header that says what the player is looking at
			local top: GuiObject = node
			while top.Parent ~= body and top.Parent ~= nil and top.Parent:IsA("GuiObject") do
				top = top.Parent :: GuiObject
			end
			local offset = top.AbsolutePosition.Y - body.AbsolutePosition.Y + body.CanvasPosition.Y
			body.CanvasPosition = Vector2.new(0, math.max(0, offset - 8))
		end)
	end

	local function refresh()
		task.spawn(function()
			local result = Net.invoke("GetShop")
			if result.ok and panel.Visible then
				render(result)
				applyFocus()
			end
		end)
	end

	refreshShop = refresh

	function ShopScreen.open()
		Components.closeOtherPanels(panel)
		panel.Visible = true
		refresh()
	end

	-- Open the shop anchored on one section (its header text) or one offer (its
	-- id). Used by the trade board's boost affordances so "get boosts" lands on
	-- the boost shelves inside the real shop instead of opening a second
	-- storefront of its own.
	function ShopScreen.openAt(sectionOrOfferId: string)
		pendingFocus = sectionOrOfferId
		ShopScreen.open()
	end

	function ShopScreen.toggle()
		if panel.Visible then
			panel.Visible = false
		else
			ShopScreen.open()
		end
	end
end

return ShopScreen
