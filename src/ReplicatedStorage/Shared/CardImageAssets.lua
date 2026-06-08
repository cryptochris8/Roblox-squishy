--!strict
-- CardImageAssets
-- Real Roblox image ids for the official card art, keyed by friend Id. This keeps
-- uploaded ids in one small place instead of editing the big generated
-- SquishyDefinitions table.
--
-- HOW TO FILL THIS IN:
--   1. Upload the PNGs in assets/card_samples_png/ to Roblox (Studio Asset
--      Manager > Images, or the Open Cloud Assets API).
--   2. Paste each returned numeric id below, replacing the 0.
--
-- Friends left at 0 (or not listed) automatically keep the coloured placeholder,
-- so it is always safe to fill these in one at a time. Only the 8 friends with
-- official sample art are listed; the other 40 launch friends have no art yet.

-- NOTE: these are the underlying IMAGE (texture) ids, not the Decal ids returned
-- by the Open Cloud upload. ImageLabel.Image needs the image id, so the decals
-- were resolved once in Studio (InsertService:LoadAsset -> Decal.Texture).
local CardImageAssets: { [string]: number } = {
	soft_dumpling = 134003206141337,          -- 001_Soft_Dumpling.png
	jelly_bun = 101548677986663,              -- 002_Jelly_Bun.png
	galaxy_dumpling = 108980931929468,        -- 013_Galaxy_Dumpling.png
	singularity_goo_core = 125178414491564,   -- 032_Singularity_Goo_Core.png
	star_eyed_bunny = 104786043577484,        -- 041_Star_Eyed_Bunny.png
	glow_ghost_puff = 110425544571778,        -- 043_Glow_Ghost_Puff.png
	arcane_wobble_kitty = 124009678365463,    -- 046_Arcane_Wobble_Kitty.png
	mythic_plush_familiar = 107444986316308,  -- 048_Mythic_Plush_Familiar.png
}

return CardImageAssets
