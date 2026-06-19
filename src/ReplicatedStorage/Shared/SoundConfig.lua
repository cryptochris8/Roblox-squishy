-- SoundConfig
-- One place for the game's sound asset ids. Everything below is from
-- Roblox's OFFICIAL free audio library (Pro Sound Effects / APM Music /
-- licensed-distribution partners) — verified loading in this place on
-- 2026-06-12, usable in any experience, nothing uploaded by us (so zero
-- moderation risk). Swap any id freely; ids live only here.

local SoundConfig = {
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

	-- ── Custom SFX we generated (ElevenLabs) + uploaded as OUR OWN assets ────
	-- Owned assets are stable (no Roblox-library 403 dropouts). Arrays are
	-- variation pools — call SoundConfig.pick(list) for a random one so the
	-- most-fired sounds never get repetitive. Uploaded 2026-06-18; these play
	-- once they clear Roblox moderation (publish AFTER they're Approved).
	SquishVariants = {
		"rbxassetid://121399769198652",
		"rbxassetid://120358439767829",
		"rbxassetid://135539135487499",
	},
	HappyPopVariants = {
		"rbxassetid://140344226127416",
		"rbxassetid://89368212106293",
		"rbxassetid://123992378529165",
	},
	SparkleBitVariants = {
		"rbxassetid://121268737505147",
		"rbxassetid://122332793140978",
	},
	CapsuleReveal = "rbxassetid://70404875944499",
	ShardRecovered = "rbxassetid://89953198547390",
	FinaleRestore = "rbxassetid://71127982595459",
	StoryPage = "rbxassetid://74051137788928",
}

-- Pick a random id from a variation pool (or return a plain value as-is).
function SoundConfig.pick(list)
	if type(list) == "table" then
		if #list == 0 then return nil end
		return list[math.random(1, #list)]
	end
	return list
end

return SoundConfig
