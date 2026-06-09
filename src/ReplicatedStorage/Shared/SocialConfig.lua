--!strict
-- SocialConfig
-- Tunables for the shared-world social layer (Phase C): the server-wide Sparkle
-- Surge meter, the "Everybody Squish!" golden-friend event, and the friendship
-- leaderboards. Everything scales with how many friends are online, so it all
-- works solo and feels like teamwork with a full server.

local SocialConfig = {}

-- ── Sparkle Surge (the server-wide meter) ───────────────────────────────────
-- Every Happy Pop by ANYONE adds 1 to one shared meter. When it fills, a Sparkle
-- Surge starts: double Sparkle Coins for everyone for a little while, then the
-- meter starts fresh.
SocialConfig.SurgePopsPerPlayer = 15
SocialConfig.SurgeGoalMin = 15
SocialConfig.SurgeGoalMax = 90
SocialConfig.SurgeDurationSeconds = 60
SocialConfig.SurgeCoinMultiplier = 2

-- ── "Everybody Squish!" (the co-op golden-friend event) ─────────────────────
-- Every few minutes, GOLDEN sleepy friends appear at the land where the most
-- players are. Everyone's golden Happy Pops count toward one shared goal; reach
-- it before they nap again and every friend online gets a Sparkle Coin gift.
SocialConfig.EventFirstDelaySeconds = 180 -- let everyone settle in first
SocialConfig.EventIntervalSeconds = 420   -- then roughly every 7 minutes
SocialConfig.EventDurationSeconds = 120   -- how long the golden friends stay awake
SocialConfig.EventGoalPerPlayer = 4       -- golden pops needed, per player online
SocialConfig.EventGoalMin = 4
SocialConfig.EventGoalMax = 12
SocialConfig.EventSpawnExtra = 2          -- spawn a couple more than the goal needs
SocialConfig.EventGoldenCoinMultiplier = 3 -- golden friends pay extra coins
SocialConfig.EventRewardCoins = 150       -- the everyone-online gift on success

-- ── Friendship leaderboards (the boards by the Pudding Hills travel hub) ────
SocialConfig.BoardRefreshSeconds = 120 -- how often the boards re-read the top list
SocialConfig.BoardTopCount = 10

return SocialConfig
