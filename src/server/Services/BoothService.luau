--!strict
-- BoothService: player storefronts in the plaza.
--
-- A booth is a HAND-PLACED model tagged BoothConfig.Tag with a unique BoothId
-- attribute. This service never spawns one — it discovers what the place
-- contains, so adding or moving a booth is a Studio edit, not a code change.
--
-- CLAIMS ARE SERVER-LOCAL AND IN MEMORY. A booth is a physical spot in ONE
-- server, so "who holds booth 3" has no meaning anywhere else and nothing about
-- it needs to survive a restart. Deliberately NOT MemoryStore: that quota is
-- experience-wide and already tight, and claims are exactly the high-churn,
-- zero-durability state that must never go near it. The place's max player
-- count is set to the number of placed booths, so a booth is always free.
--
-- A booth SELLS NOTHING OF ITS OWN. Its slots are the owner's open `sell`
-- listings, posted through the ordinary board path, so the same stock shows on
-- the booth and in the Market at one price and nothing is ever held. Releasing
-- a booth does not touch listings: stock keeps selling while the owner is
-- offline, because board settlement already handles an absent poster.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local BoothConfig = require(ReplicatedStorage.Shared.Config.BoothConfig)
local Guard = require(ReplicatedStorage.Shared.Util.Guard)

local Net = require(script.Parent.Parent.Net)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local AnalyticsService = require(script.Parent.AnalyticsService)

local BoothService = {}

-- boothId -> { model, anchor, skinMount, prompt }
local booths: { [string]: any } = {}
-- boothId -> userId, and its inverse. Both server-local.
local claimedBy: { [string]: number } = {}
local boothOfUser: { [number]: string } = {}

local function syndicate(): any
	return require(script.Parent.SyndicateService)
end

local function board(): any
	return require(script.Parent.TradeBoardService)
end

--------------------------------------------------------------------------------
-- Discovery
--------------------------------------------------------------------------------

-- Register one placed model. Returns false (and warns) when the model is not a
-- usable booth, so a half-built one is loud at boot instead of mysteriously
-- inert at runtime.
local function register(model: Instance): boolean
	if not model:IsA("Model") then
		warn(("[BoothService] %s is tagged %s but is a %s, not a Model"):format(model:GetFullName(), BoothConfig.Tag, model.ClassName))
		return false
	end
	local id = model:GetAttribute(BoothConfig.IdAttribute)
	if type(id) ~= "string" or id == "" then
		warn(("[BoothService] %s has no %s attribute; skipped"):format(model:GetFullName(), BoothConfig.IdAttribute))
		return false
	end
	if booths[id] then
		warn(("[BoothService] duplicate %s %q on %s; skipped (already used by %s)"):format(
			BoothConfig.IdAttribute, id, model:GetFullName(), booths[id].model:GetFullName()))
		return false
	end
	-- The display board. A part literally named Anchor wins; failing that, any
	-- part already carrying a SurfaceGui (which is how most toolbox stalls ship
	-- their sign) is used instead, so a bought model usually needs no renaming.
	local anchor = model:FindFirstChild(BoothConfig.AnchorName, true)
	if anchor == nil or not anchor:IsA("BasePart") then
		for _, d in model:GetDescendants() do
			if d:IsA("SurfaceGui") and d.Parent and d.Parent:IsA("BasePart") then
				anchor = d.Parent
				break
			end
		end
	end
	if anchor == nil or not anchor:IsA("BasePart") then
		warn(("[BoothService] booth %q has no %s part and no SurfaceGui to borrow; skipped"):format(id, BoothConfig.AnchorName))
		return false
	end

	-- The prompt is the one thing worth creating for them: it is pure wiring
	-- with no art to it, and a stall model has no reason to ship one.
	local prompt = model:FindFirstChild(BoothConfig.PromptName, true)
	if prompt == nil or not prompt:IsA("ProximityPrompt") then
		local host = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if host == nil then
			warn(("[BoothService] booth %q has no BasePart to host a prompt; skipped"):format(id))
			return false
		end
		local made = Instance.new("ProximityPrompt")
		made.Name = BoothConfig.PromptName
		made.ObjectText = "Trade Booth"
		made.ActionText = "Set up shop"
		made.Parent = host
		prompt = made
	end
	prompt.HoldDuration = BoothConfig.ClaimHoldSeconds
	prompt.MaxActivationDistance = BoothConfig.MaxPromptDistance
	prompt.RequiresLineOfSight = false

	booths[id] = {
		id = id,
		model = model,
		anchor = anchor,
		skinMount = model:FindFirstChild(BoothConfig.SkinMountName, true),
		prompt = prompt,
	}
	return true
end

function BoothService.boothCount(): number
	local n = 0
	for _ in booths do
		n += 1
	end
	return n
end

--------------------------------------------------------------------------------
-- Skin (cosmetic only — never touches price, tax, or slot count)
--------------------------------------------------------------------------------

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Placeholder skins tint the placed geometry rather than swapping in a model,
-- so booths look distinct with no art dependency. At publish, give a skin a
-- `model` and mount that here instead; the rest of the system is unchanged.
-- Colours by PART NAME, so any model — a primitive placeholder or something
-- dragged out of the toolbox — becomes skinnable just by naming a few parts
-- `Canopy` and `Trim`. SkinMount counts as canopy so the simplest possible
-- booth still recolours with nothing else named.
local function applySkin(entry: any, skinId: string?)
	local skin = BoothConfig.resolveSkin(skinId)
	local canopy, trim = rgb(skin.canopy), rgb(skin.trim)
	if entry.skinMount then
		entry.skinMount.Color = canopy
	end
	for _, d in entry.model:GetDescendants() do
		if d:IsA("BasePart") then
			if d.Name == "Canopy" then
				d.Color = canopy
			elseif d.Name == "Trim" then
				d.Color = trim
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Claim / release
--------------------------------------------------------------------------------

local function profileBooth(player: Player): any
	local profile = DataService.getProfile(player)
	if profile == nil then
		return nil
	end
	profile.Booth = profile.Booth or { skinId = BoothConfig.DefaultSkinId, extraSlots = 0, tagline = "" }
	return profile.Booth
end

-- Everything the client needs to paint one booth. `listings` is the owner's
-- open sell listings — the booth's stocked slots.
local function describe(id: string): any
	local ownerId = claimedBy[id]
	if ownerId == nil then
		return { boothId = id, claimed = false }
	end
	local owner = Players:GetPlayerByUserId(ownerId)
	if owner == nil then
		return { boothId = id, claimed = false }
	end
	local booth = profileBooth(owner) or {}
	local rows = {}
	for _, l in board().sellListingsOf(ownerId) do
		local item = EconomyService.getItem(l.itemId)
		table.insert(rows, {
			listingId = l.id,
			itemId = l.itemId,
			name = item and item.name or l.itemId,
			imageId = item and item.imageId or nil,
			rarity = item and item.rarity or nil,
			gemsPerCopy = l.gemsPerCopy,
			remaining = l.remainingCount,
			createdAt = l.createdAt,
		})
	end
	table.sort(rows, function(a, b)
		return a.createdAt < b.createdAt
	end)

	local tag = ""
	pcall(function()
		tag = syndicate().tagFor(ownerId)
	end)

	return {
		boothId = id,
		claimed = true,
		ownerUserId = ownerId,
		ownerName = owner.DisplayName,
		groupTag = tag,
		skinId = booth.skinId or BoothConfig.DefaultSkinId,
		tagline = booth.tagline or "",
		slots = BoothConfig.slotsFor(booth.extraSlots),
		listings = rows,
	}
end

local function pushAll()
	local out = {}
	for id in booths do
		table.insert(out, describe(id))
	end
	table.sort(out, function(a, b)
		return a.boothId < b.boothId
	end)
	Net.fireAllClients("BoothsChanged", out)
end

local function release(userId: number)
	local id = boothOfUser[userId]
	if id == nil then
		return
	end
	boothOfUser[userId] = nil
	claimedBy[id] = nil
	local entry = booths[id]
	if entry then
		applySkin(entry, BoothConfig.DefaultSkinId)
	end
end

function BoothService.claim(player: Player, boothId: any): any
	if not BoothConfig.Enabled then
		return { ok = false, err = "disabled" }
	end
	if not Guard.isString(boothId, 64) then
		return { ok = false, err = "bad_args" }
	end
	local entry = booths[boothId :: string]
	if entry == nil then
		return { ok = false, err = "no_such_booth" }
	end
	if not DataService.isLoaded(player) then
		return { ok = false, err = "loading" }
	end
	local holder = claimedBy[boothId :: string]
	if holder ~= nil and holder ~= player.UserId then
		return { ok = false, err = "taken" }
	end
	-- one booth each: claiming a second releases the first rather than
	-- silently failing, which is what a player pressing E on a nicer spot means
	release(player.UserId)
	claimedBy[boothId :: string] = player.UserId
	boothOfUser[player.UserId] = boothId :: string
	local booth = profileBooth(player)
	applySkin(entry, booth and booth.skinId)
	pushAll()
	AnalyticsService.log("booth_claimed", { userId = player.UserId, boothId = boothId })
	return { ok = true, boothId = boothId }
end

function BoothService.release(player: Player): any
	release(player.UserId)
	pushAll()
	return { ok = true }
end

--------------------------------------------------------------------------------
-- Customisation
--------------------------------------------------------------------------------

function BoothService.setSkin(player: Player, skinId: any): any
	if not Guard.isString(skinId, 32) then
		return { ok = false, err = "bad_args" }
	end
	local skin = BoothConfig.skinById(skinId :: string)
	if skin == nil then
		return { ok = false, err = "no_such_skin" }
	end
	local booth = profileBooth(player)
	if booth == nil then
		return { ok = false, err = "loading" }
	end
	-- A skin must be owned. The default is free; everything else is granted by
	-- its purchase, which writes into owned. Checked here rather than trusted
	-- from the client, because the client sends the id.
	if skin.id ~= BoothConfig.DefaultSkinId then
		booth.owned = booth.owned or {}
		if not booth.owned[skin.id] then
			return { ok = false, err = "not_owned" }
		end
	end
	booth.skinId = skin.id
	local id = boothOfUser[player.UserId]
	if id and booths[id] then
		applySkin(booths[id], skin.id)
	end
	pushAll()
	return { ok = true, skinId = skin.id }
end

-- Grant a skin (called by ProductService on purchase). Idempotent.
function BoothService.grantSkin(player: Player, skinId: string): boolean
	local booth = profileBooth(player)
	if booth == nil or BoothConfig.skinById(skinId) == nil then
		return false
	end
	booth.owned = booth.owned or {}
	booth.owned[skinId] = true
	return true
end

-- Grant one extra slot (called by ProductService). Capped, so a repeated
-- purchase can never produce a booth with hundreds of shelves.
function BoothService.grantSlot(player: Player): boolean
	local booth = profileBooth(player)
	if booth == nil then
		return false
	end
	local slots = BoothConfig.slotsFor(booth.extraSlots)
	if slots >= BoothConfig.MaxSlots then
		return false -- at the ceiling; leave the receipt unprocessed
	end
	booth.extraSlots = (booth.extraSlots or 0) + 1
	pushAll()
	return true
end

function BoothService.setTagline(player: Player, text: any): any
	if type(text) ~= "string" then
		return { ok = false, err = "bad_args" }
	end
	local booth = profileBooth(player)
	if booth == nil then
		return { ok = false, err = "loading" }
	end
	local trimmed = text:sub(1, BoothConfig.MaxTaglineLength)
	if trimmed ~= "" then
		-- Filtered per reader downstream; this pass just refuses anything the
		-- filter rejects outright. An empty result stays empty — never the raw
		-- string, which is how unfiltered text leaks.
		local ok, filtered = pcall(function()
			local res = TextService:FilterStringAsync(trimmed, player.UserId)
			return res:GetNonChatStringForBroadcastAsync()
		end)
		trimmed = (ok and type(filtered) == "string") and filtered or ""
	end
	booth.tagline = trimmed
	pushAll()
	return { ok = true, tagline = trimmed }
end

--------------------------------------------------------------------------------
-- Lifecycle
--------------------------------------------------------------------------------

function BoothService.Init()
	for _, model in CollectionService:GetTagged(BoothConfig.Tag) do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal(BoothConfig.Tag):Connect(function(model)
		if register(model) then
			pushAll()
		end
	end)
	CollectionService:GetInstanceRemovedSignal(BoothConfig.Tag):Connect(function(model)
		for id, entry in booths do
			if entry.model == model then
				local holder = claimedBy[id]
				if holder then
					boothOfUser[holder] = nil
				end
				claimedBy[id] = nil
				booths[id] = nil
				pushAll()
				break
			end
		end
	end)
end

function BoothService.Start()
	Net.bindFunction("GetBooths", function(player)
		local out = {}
		for id in booths do
			table.insert(out, describe(id))
		end
		table.sort(out, function(a, b)
			return a.boothId < b.boothId
		end)
		-- Skins go out with their live Robux price attached. Built as a copy:
		-- BoothConfig.Skins is a shared config table and writing a price into it
		-- would mutate config for everything else in the server.
		-- Lazy require: ProductService is a peer, and a top-level require here
		-- would order-couple two services that otherwise don't know each other.
		local pricer = require(script.Parent.ProductService)
		local skins = {}
		for _, skin in BoothConfig.Skins do
			local price: number? = nil
			if skin.offerId then
				pcall(function()
					price = pricer.priceOf(skin.offerId)
				end)
			end
			table.insert(skins, {
				id = skin.id,
				name = skin.name,
				blurb = skin.blurb,
				canopy = skin.canopy,
				trim = skin.trim,
				offerId = skin.offerId,
				robux = price, -- nil until the offer has a real product id
			})
		end

		return {
			ok = true,
			booths = out,
			yours = boothOfUser[player.UserId],
			skins = skins,
			owned = (profileBooth(player) or {}).owned or {},
		}
	end)

	Net.bindFunction("ClaimBooth", function(player, boothId)
		if not require(script.Parent.QuestService).hasUnlock(player.UserId, "booth") then
			return { ok = false, err = "rank_locked" }
		end
		return BoothService.claim(player, boothId)
	end)
	Net.bindFunction("ReleaseBooth", function(player)
		return BoothService.release(player)
	end)
	Net.bindFunction("SetBoothSkin", function(player, skinId)
		return BoothService.setSkin(player, skinId)
	end)
	Net.bindFunction("SetBoothTagline", function(player, text)
		return BoothService.setTagline(player, text)
	end)

	-- The booth is a spot in this server, so leaving frees it. Listings are
	-- untouched: they keep selling while the owner is away.
	Players.PlayerRemoving:Connect(function(player)
		if boothOfUser[player.UserId] then
			release(player.UserId)
			pushAll()
		end
	end)

	-- A booth face shows live listings, so it repaints on a slow tick: stock
	-- sells while the owner stands there and the shelf has to empty. Skipped
	-- entirely when nothing is claimed, so an idle server does no work.
	task.spawn(function()
		while true do
			task.wait(4)
			if next(boothOfUser) ~= nil then
				pushAll()
			end
		end
	end)
end

return BoothService
