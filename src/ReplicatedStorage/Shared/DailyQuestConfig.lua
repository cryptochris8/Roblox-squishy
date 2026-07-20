--!strict
-- DailyQuestConfig
-- Rotating daily objectives — the "this session" layer of goals. The active set
-- for a day is derived from the UTC day index (the same set for everyone), so it
-- rotates daily and is social ("did you do today's quests?"). Shared so the client
-- (Daily panel) and server (award logic) agree on the active set.

local DailyQuestConfig = {}

DailyQuestConfig.PerDay = 3

-- `type` matches the events DailyService tracks: "pop", "bit", "capsule", "discover", "water".
-- `text` is a format string; %d is filled with the goal (a text with no %d is fine).
DailyQuestConfig.Quests = {
	{ id = "wake",     type = "pop",      goal = 10, reward = 50, text = "Wake %d sleepy friends" },
	{ id = "explore",  type = "bit",      goal = 2,  reward = 45, text = "Find %d hidden Sparkle Bits" },
	{ id = "open",     type = "capsule",  goal = 2,  reward = 35, text = "Open %d Sparkle Capsules" },
	{ id = "discover", type = "discover", goal = 1,  reward = 60, text = "Discover a new friend" },
	{ id = "wakemore", type = "pop",      goal = 20, reward = 70, text = "Wake %d sleepy friends" },
	{ id = "water",    type = "water",    goal = 1,  reward = 55, text = "Water a friend's garden" },
}

-- The PerDay quests active on a given UTC day index — a rotating window, so the
-- set changes daily but is deterministic and identical for all players.
function DailyQuestConfig.forDay(dayIndex: number)
	local list = {}
	local n = #DailyQuestConfig.Quests
	for i = 0, DailyQuestConfig.PerDay - 1 do
		list[#list + 1] = DailyQuestConfig.Quests[((dayIndex + i) % n) + 1]
	end
	return list
end

return DailyQuestConfig
