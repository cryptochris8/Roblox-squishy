-- SoundConfig
-- One place for the game's sound asset ids. Everything below is from
-- Roblox's OFFICIAL free audio library (Pro Sound Effects / APM Music /
-- licensed-distribution partners) — verified loading in this place on
-- 2026-06-12, usable in any experience, nothing uploaded by us (so zero
-- moderation risk). Swap any id freely; ids live only here.

return {
	-- ── Per-land music (crossfaded by the client SoundScape as you travel) ──
	MusicByZone = {
		["Pudding Hills"] = "rbxassetid://1839580320", -- "Happy Forever Ukulele" (APM)
		["Goo Coast"] = "rbxassetid://1842199675", -- "Lazy Caribbean" (APM)
		["Moonlit Hollow"] = "rbxassetid://91539844933951", -- "Gentle Music Box"
	},
	MusicVolume = 0.25,

	-- ── Per-land nature, quiet under the music ──────────────────────────────
	AmbientByZone = {
		["Pudding Hills"] = "rbxassetid://9116969962", -- "Morning Birds 3"
		["Goo Coast"] = "rbxassetid://71778550603470", -- "Soft Ocean Waves"
		["Moonlit Hollow"] = "rbxassetid://108750790460172", -- "Night Cricket Stillness"
	},
	AmbientVolume = 0.16,

	-- ── Squish feedback (the originals; the kids know these) ────────────────
	Squish = "rbxassetid://116062165012558",
	HappyPop = "rbxasset://sounds/electronicpingshort.wav",

	-- ── Playground + moments (Pro Sound Effects library) ────────────────────
	Boing = "rbxassetid://6075441854", -- "Cartoon Spring Bounce"
	Splash = "rbxassetid://9119674632", -- "Surfacing Splash Kids Playing"
	Pop = "rbxassetid://9112872239", -- "Small Bubbles Pop"
	Whoosh = "rbxassetid://9116411685", -- "Magic Swoosh Fast Zooming"
	TrainWhistle = "rbxassetid://9120222876", -- "Toy Train Whistle 8"
	TrainChug = "rbxassetid://9119626154", -- "Steam Train 1" (loop)
	Chime = "rbxassetid://9116394876", -- "Magic Glows Soft Chiming Hits"
}
