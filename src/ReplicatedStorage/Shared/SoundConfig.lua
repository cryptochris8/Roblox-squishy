-- SoundConfig
-- One place for the game's sound asset ids.
--
-- SQUISH FEEDBACK uses Roblox's always-available BUILT-IN sounds, so it works out
-- of the box (no uploads needed). Swap for Audio Library ids anytime.
--
-- BACKGROUND MUSIC needs a track id you choose in Studio — Claude can't search or
-- upload audio from the terminal. To add music:
--   1. In Studio: Toolbox -> Audio, search e.g. "calm music box" / "cozy ambient".
--   2. Right-click a free track -> Copy Asset ID.
--   3. Paste it below as Music = "rbxassetid://<id>".
-- Left empty = no music plays (everything else still works).

return {
	-- Background music (looping, global). Empty = off until you paste a track id.
	Music = "",
	MusicVolume = 0.3,

	-- Squish feedback (built-in sounds; always available).
	Squish = "rbxassetid://116062165012558",             -- player-picked squish sound
	HappyPop = "rbxasset://sounds/electronicpingshort.wav", -- bright sparkle on Happy Pop
}
