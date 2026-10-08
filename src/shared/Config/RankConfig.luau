--!strict
-- RankConfig: the progression ladder. Ranks gate a small set of real features
-- (not just cosmetics) so a brand-new player meets a simpler game and unlocks
-- the rest by playing -- Quests raise `completedQuests`, which is all a rank
-- check reads. Floating title is shown above the character (see QuestService/
-- the client rank-title controller); `unlocks` keys are checked with
-- RankConfig.unlocked(rank, key) at every gated entry point, server AND client.

local RankConfig = {
	-- Ordered low -> high. `id` is stored on the profile; `questsRequired` is
	-- the CUMULATIVE completed-quest count needed to hold this rank.
	Ranks = {
		{ id = 1, title = "Noob", questsRequired = 0, unlocks = {} },
		{ id = 2, title = "Casual", questsRequired = 3, unlocks = {} },
		{ id = 3, title = "Regular", questsRequired = 6, unlocks = { bulkbuy = true } },
		{ id = 4, title = "Trader", questsRequired = 9, unlocks = { syndicate = true, booth = true } },
	},
}

-- The highest rank whose threshold `completedQuests` meets or beats.
function RankConfig.rankFor(completedQuests: number): any
	local best = RankConfig.Ranks[1]
	for _, rank in RankConfig.Ranks do
		if completedQuests >= rank.questsRequired then
			best = rank
		end
	end
	return best
end

function RankConfig.byId(id: number): any?
	for _, rank in RankConfig.Ranks do
		if rank.id == id then
			return rank
		end
	end
	return nil
end

-- True once `completedQuests` has unlocked `key` (on ANY rank up to and
-- including the current one -- unlocks are cumulative, never lost on the way
-- up the ladder).
function RankConfig.unlocked(completedQuests: number, key: string): boolean
	local rank = RankConfig.rankFor(completedQuests)
	for _, r in RankConfig.Ranks do
		if r.questsRequired <= rank.questsRequired and r.unlocks[key] then
			return true
		end
	end
	return false
end

-- The next rank up, or nil at the top of the ladder.
function RankConfig.nextAfter(rank: any): any?
	for i, r in RankConfig.Ranks do
		if r.id == rank.id then
			return RankConfig.Ranks[i + 1]
		end
	end
	return nil
end

return RankConfig
