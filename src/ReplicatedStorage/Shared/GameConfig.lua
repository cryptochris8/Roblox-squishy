--!strict
-- GameConfig
-- All the kid-friendly tunable numbers for the Squishy Smash MVP in one place.
-- Change values HERE rather than deep in the game code.

local GameConfig = {}

-- Sparkle Coins
GameConfig.StartingSparkleCoins = 0

-- Squishing a sleepy friend fills its Joy Meter; when it's full the friend
-- gives a Happy Pop (sparkles + Sparkle Coins) and a new friend wakes up.
GameConfig.JoyPerSquish = 0.34            -- ~3 gentle squishes to fill the meter
GameConfig.SquishCooldownSeconds = 0.12   -- gentle anti-spam, per player per friend
GameConfig.HappyPopRespawnSeconds = 1.2   -- a new sleepy friend wakes up after a pop
GameConfig.HappyPopHoldSeconds = 1.1      -- keep a popped friend briefly so its Happy Pop plays out

-- First tutorial quest: wake up (Happy Pop) this many sleepy friends.
GameConfig.TutorialPopGoal = 3
GameConfig.TutorialRewardCoins = 100

-- The First Shard quest (Pudding Hills): wake this many sleepy friends to reveal
-- where the lost shard fell, then recover it from the orchard's edge.
GameConfig.FirstShardWakeGoal = 8
GameConfig.FirstShardRewardCoins = 150

-- The Sparkle Capsule: the very first one is a free gift after the tutorial.
GameConfig.FirstCapsuleIsFree = true

-- The friends who wander the Pudding Hills starter zone in the MVP.
GameConfig.PuddingHillsStarters = {
	"soft_dumpling",
	"jelly_bun",
	"peach_mochi",
	"cream_puff",
	"pudding_pop",
	"sparkle_mochi",
	"galaxy_dumpling",
}
GameConfig.PuddingHillsFriendCount = 12 -- sleepy friends spread across Pudding Hills

-- A few cozy display constants
GameConfig.ZoneName = "Pudding Hills"

return GameConfig
