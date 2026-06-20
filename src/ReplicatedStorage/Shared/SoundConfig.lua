-- SoundConfig
-- One place for the game's sound asset ids. Everything here is now OUR OWN
-- ElevenLabs-generated audio uploaded as owned assets — music, SFX, AND per-land
-- ambience — so the soundscape is stable with no Roblox-library 403 dropouts.
-- Swap any id freely; ids live only here.

local SoundConfig = {
	-- ── Per-land music (crossfaded by the client SoundScape as you travel) ──
	MusicByZone = {
		["Pudding Hills"] = "rbxassetid://101719911506649", -- our cozy ukulele theme (ElevenLabs)
		["Goo Coast"] = "rbxassetid://111754435899050", -- our lazy calypso theme
		["Moonlit Hollow"] = "rbxassetid://86026581501038", -- our music-box lullaby
	},
	MusicVolume = 0.25,

	-- ── Per-land nature, quiet under the music ──────────────────────────────
	AmbientByZone = {
		["Pudding Hills"] = "rbxassetid://115201743653440", -- our meadow birds (ElevenLabs, looped)
		["Goo Coast"] = "rbxassetid://127711304647742", -- our calm shore waves
		["Moonlit Hollow"] = "rbxassetid://113331943734600", -- our night crickets
	},
	AmbientVolume = 0.16,

	-- ── Squish feedback (the originals; the kids know these) ────────────────
	Squish = "rbxassetid://116062165012558",
	HappyPop = "rbxasset://sounds/electronicpingshort.wav",

	-- ── Playground + moments (Pro Sound Effects library) ────────────────────
	Boing = "rbxassetid://118713267500225", -- our springy boing (ElevenLabs)
	Splash = "rbxassetid://118369676847068", -- our soft kid splash
	Pop = "rbxassetid://106359238383849", -- our bubble pop
	Whoosh = "rbxassetid://93019091138643", -- our zip whoosh
	TrainWhistle = "rbxassetid://92637900651163", -- our toy-train whistle
	TrainChug = "rbxassetid://104015401921394", -- our toy-train chug (loop)
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

	-- Per-friend signature squish, keyed by def.SignatureSound (the book's
	-- "Pmf / Sploink / Thup" chant) — SquishFx plays the friend's own.
	SignatureSounds = {
		Pmf = { "rbxassetid://89917384302600", "rbxassetid://94478471627920" },
		Sploink = { "rbxassetid://110605891641808", "rbxassetid://117457128212264" },
		Thup = { "rbxassetid://127526325190451", "rbxassetid://97735721668064" },
	},
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
