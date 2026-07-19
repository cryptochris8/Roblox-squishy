-- BadgeConfig (SERVER)
-- Roblox badge ids for the achievement ladder. CHRIS: create these in Creator
-- Hub (Experience → Badges — 5 are free per experience per 24h, so spread the
-- set over ~3 days) and paste each id here. An id of 0 means "not created
-- yet" and that badge silently no-ops — safe to ship ahead of the ids.
--
-- Suggested names/descriptions when creating (kid-voice, no pressure):
--   Welcome            "Welcome to Pudding Hills!" — joined the game
--   FirstHappyPop      "Your very first Happy Pop!"
--   FirstCapsule       "You opened a Sparkle Capsule!"
--   FirstDiscovery     "You discovered your first Squishy Friend!"
--   Friends10/25/48    "10 / 25 / ALL 48 friends discovered!"
--   FirstSparkly       "Your first ✨ Sparkly friend!"
--   FirstRainbow       "Your first 🌈 Rainbow friend!"
--   ShardPuddingHills  "Pudding Hills shard recovered!"
--   ShardGooCoast      "Goo Coast shard recovered!"
--   ShardMoonlitHollow "Moonlit Hollow shard recovered!"
--   SparkleRestored    "You restored the Sparkle!"
--   AllSparkleBits     "Every hidden Sparkle Bit found in one day!"
--   AllStoryPages      "You found every page of The Lost Sparkle!"
--   KindFriend         "You gave your first gift 💝" (kindness badge — rare on
--                      the platform, very Squishy)
--
-- Icon pipeline: marketing/make_product_icons.py (the same pastel style that
-- already cleared moderation for the Phase D product icons).

return {
	Welcome = 0,
	FirstHappyPop = 0,
	FirstCapsule = 0,
	FirstDiscovery = 0,
	Friends10 = 0,
	Friends25 = 0,
	Friends48 = 0,
	FirstSparkly = 0,
	FirstRainbow = 0,
	ShardPuddingHills = 0,
	ShardGooCoast = 0,
	ShardMoonlitHollow = 0,
	SparkleRestored = 0,
	AllSparkleBits = 0,
	AllStoryPages = 0,
	KindFriend = 0,
}
