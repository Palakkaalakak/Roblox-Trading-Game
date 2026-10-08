--!strict
-- QuestConfig: the fixed quest ladder. One quest is ACTIVE at a time per
-- player (the next one in this list they haven't completed yet) -- a simple
-- checklist, not a rotating/daily system. `kind` matches the event name
-- QuestService.notify is called with from each service that produces it;
-- `target` is how many of that event complete the quest.
--
-- Completing a quest is what advances rank (RankConfig.questsRequired counts
-- position in THIS list, 1-indexed) -- so reordering this list reorders when
-- rank-gated features unlock. Add quests at the end, don't reorder past ones,
-- or a live player's progress silently means something different.

local QuestConfig = {
	-- Core chain: 3 chapters of 3. The payoff is the RANK-UP at each chapter
	-- end (RankConfig), which unlocks a major feature. Quests grant nothing
	-- else -- no currency, ever.
	Quests = {
		{ id = 1, kind = "starter", target = 1, title = "Open your starter pack" },
		{ id = 2, kind = "craft", target = 1, title = "Craft at the Crafter" },
		{ id = 3, kind = "roll", target = 3, title = "Do 3 rolls" },
		{ id = 4, kind = "market_check", target = 1, title = "Check an item's value in the Market" },
		{ id = 5, kind = "post_trade", target = 1, title = "Post a trade ad on the Board" },
		{ id = 6, kind = "complete_trade", target = 1, title = "Complete a trade" },
		{ id = 7, kind = "sell", target = 1, title = "Sell an item on the Board" },
		{ id = 8, kind = "bulk_contribute", target = 1, title = "Sell into a buy order" },
		{ id = 9, kind = "complete_trade", target = 3, title = "Complete 3 trades" },
	},
}

-- DAILY quests: 3 per player per UTC day (one of each difficulty), picked
-- deterministically from these pools. Progress = lifetime counter minus the
-- value it had when the day's set was rolled.
QuestConfig.Daily = {
	easy = {
		{ kind = "roll", target = 3, title = "Do 3 rolls" },
		{ kind = "post_trade", target = 1, title = "Post a trade ad" },
		{ kind = "craft", target = 1, title = "Craft an item" },
	},
	medium = {
		{ kind = "complete_trade", target = 2, title = "Complete 2 trades" },
		{ kind = "sell", target = 2, title = "Sell 2 items" },
		{ kind = "roll", target = 10, title = "Do 10 rolls" },
	},
	hard = {
		{ kind = "complete_trade", target = 5, title = "Complete 5 trades" },
		{ kind = "bulk_contribute", target = 2, title = "Fill 2 bulk orders" },
		{ kind = "craft", target = 5, title = "Craft 5 items" },
	},
}
QuestConfig.DailyOrder = { "easy", "medium", "hard" }

-- WEEKLY quests: unlocked (like dailies) by finishing every core quest. 3 per
-- player per week (Mon-Sun UTC), bigger targets.
QuestConfig.Weekly = {
	easy = {
		{ kind = "roll", target = 40, title = "Do 40 rolls" },
		{ kind = "post_trade", target = 15, title = "Post 15 trade ads" },
		{ kind = "craft", target = 10, title = "Craft 10 items" },
	},
	medium = {
		{ kind = "complete_trade", target = 15, title = "Complete 15 trades" },
		{ kind = "sell", target = 15, title = "Sell 15 items" },
		{ kind = "roll", target = 100, title = "Do 100 rolls" },
	},
	hard = {
		{ kind = "complete_trade", target = 40, title = "Complete 40 trades" },
		{ kind = "bulk_contribute", target = 10, title = "Fill 10 bulk orders" },
		{ kind = "craft", target = 30, title = "Craft 30 items" },
	},
}
QuestConfig.WeeklyOrder = { "easy", "medium", "hard" }


function QuestConfig.byId(id: number): any?
	return QuestConfig.Quests[id]
end

return QuestConfig
