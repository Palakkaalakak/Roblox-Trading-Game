--!strict
-- QuickChatConfig: canned phrases for trading and for group chat.
--
-- WHY THIS EXISTS AND NOT JUST TEXT CHAT. Roblox restricts text chat between
-- accounts in different age groups, so a 12-year-old and a 15-year-old often
-- cannot type to each other at all. In a game whose entire loop is negotiating
-- with another person, that is not a minor limitation — it silently breaks the
-- core activity for a large share of the playerbase.
--
-- Canned phrases are not user-generated text: the client sends an ID, the
-- server looks the wording up in this file and relays it. Nothing a player
-- typed ever reaches another player, so there is nothing to filter and no age
-- restriction to apply. Everyone can talk to everyone.
--
-- The phrasing is real trading vocabulary rather than invented politeness —
-- "Add more", "Too much", "Clean trade?" are what traders actually say, so a
-- player who learns them here can read any trade thread in the wider community.
-- W/L grading is deliberately absent.
--
-- ITEM SLOTS. A phrase whose `slot` is "item" is completed with a specific
-- item ("I want your Storm Sigil"). That is the one that really matters for
-- players who cannot type: naming a thing is most of what negotiation is.

local QuickChatConfig = {
	-- Shown in the trade screen, grouped so the bar stays readable.
	TradePhrases = {
		-- ── what I think of this offer ──────────────────────────────────
		{ id = "fair", group = "verdict", text = "That looks fair" },
		{ id = "add", group = "verdict", text = "Add more" },
		{ id = "too_much", group = "verdict", text = "That's too much, take some back" },
		{ id = "close", group = "verdict", text = "Almost — a little more" },
		{ id = "lowball", group = "verdict", text = "That's way under value" },

		-- ── what I want ─────────────────────────────────────────────────
		{ id = "want_item", group = "want", text = "I want your %s", slot = "item" },
		{ id = "offer_item", group = "want", text = "I'll give you my %s", slot = "item" },
		{ id = "not_that", group = "want", text = "Not that one, sorry" },
		{ id = "clean", group = "want", text = "Clean trade? One for one" },
		{ id = "what_want", group = "want", text = "What do you want for it?" },

		-- ── flow ────────────────────────────────────────────────────────
		{ id = "ready", group = "flow", text = "Ready when you are" },
		{ id = "wait", group = "flow", text = "One moment" },
		{ id = "thinking", group = "flow", text = "Let me think about it" },
		{ id = "yes", group = "flow", text = "Yes" },
		{ id = "no", group = "flow", text = "No thanks" },

		-- ── manners. Cheap to include and they make the screen friendlier ──
		{ id = "hi", group = "social", text = "Hi!" },
		{ id = "thanks", group = "social", text = "Thanks!" },
		{ id = "sorry", group = "social", text = "Sorry!" },
		{ id = "gl", group = "social", text = "Good luck out there" },
	},

	GroupLabels = {
		verdict = "Offer",
		want = "Items",
		flow = "Trade",
		social = "Say",
	},
	GroupOrder = { "verdict", "want", "flow", "social" },
}

-- Look a trade phrase up by id. Returns nil for anything not in this file,
-- which is what stops a client sending arbitrary text through the relay.
function QuickChatConfig.tradePhrase(id: string): any?
	for _, phrase in QuickChatConfig.TradePhrases do
		if phrase.id == id then
			return phrase
		end
	end
	return nil
end

-- Render a phrase, substituting an item name when it takes one. The caller
-- resolves the name; this only formats, so a bad itemId can never inject text.
function QuickChatConfig.render(phrase: any, itemName: string?): string
	if phrase.slot == "item" then
		return (phrase.text):format(itemName or "that")
	end
	return phrase.text
end

return QuickChatConfig
