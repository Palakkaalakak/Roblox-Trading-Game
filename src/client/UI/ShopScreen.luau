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
	local cardTemplate = (sectionTemplate:WaitForChild("Grid") :: Frame):WaitForChild("OfferCard") :: Frame
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

	local function renderCard(offer: any, parent: Frame, order: number)
		local card = cardTemplate:Clone()
		card.Name = "offer_" .. offer.id
		card.Visible = true
		card.LayoutOrder = order

		local nameLabel = card:WaitForChild("OfferName") :: TextLabel
		nameLabel.Text = offer.name
		if offer.nameColor then
			nameLabel.TextColor3 = Color3.fromRGB(offer.nameColor[1], offer.nameColor[2], offer.nameColor[3])
		end
		Components.setIcon(card:WaitForChild("Icon") :: ImageLabel, { imageId = offer.imageId, name = offer.name })

		-- contents: gems get the cyan treatment, everything else its blurb
		local contents = card:WaitForChild("Contents") :: TextLabel
		if offer.gems then
			contents.Text = comma(offer.gems) .. " Gems"
			contents.TextColor3 = Theme.Gem
		else
			contents.Text = offer.description or ""
			contents.TextColor3 = Theme.TextPrimary
		end

		local bonus = card:WaitForChild("Bonus") :: TextLabel
		bonus.Text = offer.bonusPercent and ("+%d%% BONUS"):format(offer.bonusPercent) or ""

		local timeLeft = card:WaitForChild("TimeLeft") :: TextLabel
		timeLeft.Text = offer.availableUntil and timeLeftText(offer.availableUntil) or ""

		-- strikethrough original price
		local wasPrice = card:WaitForChild("WasPrice") :: TextLabel
		local strike = wasPrice:WaitForChild("Strike") :: Frame
		if offer.wasRobux then
			wasPrice.Text = "R$" .. comma(offer.wasRobux)
			strike.Visible = true
		else
			wasPrice.Text = ""
			strike.Visible = false
		end

		local badge = card:WaitForChild("Badge") :: TextLabel
		badge.Visible = offer.badge ~= nil
		badge.Text = offer.badge or ""

		local buyBtn = card:WaitForChild("BuyButton") :: TextButton
		if offer.owned then
			buyBtn.Text = "OWNED"
			buyBtn.BackgroundColor3 = Theme.BgLight
			buyBtn.AutoButtonColor = false
		else
			-- Roblox renders the real price in its own purchase prompt, so the
			-- button just invites the click rather than restating a price we'd
			-- have to keep in sync with the product.
			buyBtn.Text = "BUY"
			buyBtn.BackgroundColor3 = Theme.Good
			buyBtn.Activated:Connect(function()
				if busy or offer.owned then
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
			;(sec:WaitForChild("SectionHeader") :: TextLabel).Text = sectionName
			local grid = sec:WaitForChild("Grid") :: Frame
			-- drop the template clone that came along for the ride
			local tmpl = grid:FindFirstChild("OfferCard")
			if tmpl then
				tmpl:Destroy()
			end
			for i, offer in list do
				renderCard(offer, grid, i)
			end
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
