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

	local function clear()
		for _, inst in spawned do
			inst:Destroy()
		end
		table.clear(spawned)
	end

	-- BUY / OWNED state + purchase click. The button carries a green gradient
	-- from the template; OWNED disables it and greys it out.
	local function wireBuy(btn: TextButton, offer: any)
		if offer.owned then
			btn.Text = "OWNED"
			btn.AutoButtonColor = false
			local g = btn:FindFirstChildOfClass("UIGradient")
			if g then
				g.Enabled = false
			end
			btn.BackgroundColor3 = Theme.BgLight
			return
		end
		-- Roblox renders the real price in its own prompt, so the button just
		-- invites the click rather than restating a price we'd have to sync.
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

	-- Fields both card kinds share: name, art, gem/blurb line, bonus pill,
	-- strikethrough price, optional accent tint, and the buy button.
	local function fillCommon(cardInst: Frame, offer: any)
		local nameLabel = cardInst:WaitForChild("OfferName") :: TextLabel
		nameLabel.Text = offer.name
		if offer.nameColor then
			nameLabel.TextColor3 = Color3.fromRGB(offer.nameColor[1], offer.nameColor[2], offer.nameColor[3])
		end
		Components.setIcon(cardInst:WaitForChild("Icon") :: ImageLabel, { imageId = offer.imageId, name = offer.name })

		local contents = cardInst:WaitForChild("Contents") :: TextLabel
		if offer.gems then
			contents.Text = comma(offer.gems) .. " Gems"
			contents.TextColor3 = Theme.Gem
		else
			contents.Text = offer.description or ""
			contents.TextColor3 = Theme.TextPrimary
		end

		local bonus = cardInst:WaitForChild("Bonus") :: TextLabel
		if offer.bonusPercent then
			bonus.Text = ("+%d%% BONUS"):format(offer.bonusPercent)
			bonus.Visible = true
		else
			bonus.Visible = false
		end

		local wasPrice = cardInst:WaitForChild("WasPrice") :: TextLabel
		local strike = wasPrice:WaitForChild("Strike") :: Frame
		if offer.wasRobux then
			wasPrice.Text = "R$" .. comma(offer.wasRobux)
			strike.Visible = true
		else
			wasPrice.Text = ""
			strike.Visible = false
		end

		-- per-offer accent recolors the card's border (falls back to template)
		if offer.accent then
			local s = cardInst:FindFirstChildOfClass("UIStroke")
			if s then
				s.Color = Color3.fromRGB(offer.accent[1], offer.accent[2], offer.accent[3])
			end
		end

		wireBuy(cardInst:WaitForChild("BuyButton") :: TextButton, offer)
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

	local function refresh()
		task.spawn(function()
			local result = Net.invoke("GetShop")
			if result.ok and panel.Visible then
				render(result)
			end
		end)
	end

	function ShopScreen.open()
		Components.closeOtherPanels(panel)
		panel.Visible = true
		refresh()
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
