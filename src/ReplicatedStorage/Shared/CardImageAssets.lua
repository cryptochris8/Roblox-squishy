--!strict
-- CardImageAssets
-- Real Roblox image ids for the official card art, keyed by friend Id. This keeps
-- uploaded ids in one small place instead of editing the big generated
-- SquishyDefinitions table. Merged over the defs in SquishyData.
--
-- All 48 launch friends now have official card art (the final_48 trading cards,
-- uploaded 2026-06-09 via tools/card_art/upload_cards.ps1).
--
-- NOTE: these are the underlying IMAGE (texture) ids, not the Decal ids returned
-- by the Open Cloud upload. ImageLabel.Image needs the image id, so the decals
-- were resolved in Studio (InsertService:LoadAsset -> Decal.Texture). The raw
-- upload (friendId -> Decal id) map lives in tools/card_art/upload_result.json.
--
-- To add/replace one: drop the new image id below (a friend at 0 or not listed
-- keeps the coloured placeholder, so it is always safe to edit one at a time).
local CardImageAssets: { [string]: number } = {
	soft_dumpling = 134003206141337,           -- 001_Soft_Dumpling
	jelly_bun = 101548677986663,               -- 002_Jelly_Bun
	peach_mochi = 123087079074070,             -- 003_Peach_Mochi
	syrup_cube = 118666923004309,              -- 004_Syrup_Cube
	cream_puff = 118389095645312,              -- 005_Cream_Puff
	rice_ball_squish = 138536018217631,        -- 006_Rice_Ball_Squish
	marshmallow_puff = 84287463434915,         -- 007_Marshmallow_Puff
	pudding_pop = 129855830281019,             -- 008_Pudding_Pop
	strawberry_dumpling = 126961424252204,     -- 009_Strawberry_Dumpling
	rainbow_jelly_bun = 118687534332750,       -- 010_Rainbow_Jelly_Bun
	sparkle_mochi = 117712566564372,           -- 011_Sparkle_Mochi
	golden_syrup_cube = 81257502528468,        -- 012_Golden_Syrup_Cube
	galaxy_dumpling = 108980931929468,         -- 013_Galaxy_Dumpling
	crystal_mochi = 109932332617408,           -- 014_Crystal_Mochi
	neon_dessert_blob = 72143844702791,        -- 015_Neon_Dessert_Blob
	celestial_dumpling_core = 127991717112372, -- 016_Celestial_Dumpling_Core
	goo_ball = 95532675771642,                 -- 017_Goo_Ball
	bubble_blob = 134724170443184,             -- 018_Bubble_Blob
	stretch_cube = 117178163439799,            -- 019_Stretch_Cube
	soft_stress_orb = 125346361337369,         -- 020_Soft_Stress_Orb
	jelly_pad = 71165420312223,                -- 021_Jelly_Pad
	sticky_pop_ball = 126460546323986,         -- 022_Sticky_Pop_Ball
	wobble_drop = 120799273797406,             -- 023_Wobble_Drop
	squish_capsule = 70584457283998,           -- 024_Squish_Capsule
	glitter_goo_ball = 108802846918573,        -- 025_Glitter_Goo_Ball
	shockwave_blob = 139049775148835,          -- 026_Shockwave_Blob
	frost_gel_cube = 105520252958280,          -- 027_Frost_Gel_Cube
	prism_stress_orb = 111038571192895,        -- 028_Prism_Stress_Orb
	plasma_goo_ball = 81964772168248,          -- 029_Plasma_Goo_Ball
	aurora_stretch_cube = 73523219413320,      -- 030_Aurora_Stretch_Cube
	cosmic_jelly_pad = 89479966298641,         -- 031_Cosmic_Jelly_Pad
	singularity_goo_core = 125178414491564,    -- 032_Singularity_Goo_Core
	blushy_bun_bunny = 133857113236816,        -- 033_Blushy_Bun_Bunny
	squish_bat = 81395115013587,               -- 034_Squish_Bat
	puff_ghost = 72686851891358,               -- 035_Puff_Ghost
	wobble_kitty = 87994293124622,             -- 036_Wobble_Kitty
	tiny_blob_monster = 131006009643532,       -- 037_Tiny_Blob_Monster
	soft_fang_critter = 96709948954064,        -- 038_Soft_Fang_Critter
	sleepy_slime_pet = 86934117001706,         -- 039_Sleepy_Slime_Pet
	round_eared_creature = 132583230401421,    -- 040_Round_Eared_Creature
	star_eyed_bunny = 104786043577484,         -- 041_Star_Eyed_Bunny
	moon_bat_blob = 94451134403032,            -- 042_Moon_Bat_Blob
	glow_ghost_puff = 110425544571778,         -- 043_Glow_Ghost_Puff
	candy_fang_creature = 139982158653801,     -- 044_Candy_Fang_Creature
	dream_eater_squish = 122825300673147,      -- 045_Dream_Eater_Squish
	arcane_wobble_kitty = 124009678365463,     -- 046_Arcane_Wobble_Kitty
	phantom_jelly_beast = 72493061037906,      -- 047_Phantom_Jelly_Beast
	mythic_plush_familiar = 107444986316308,   -- 048_Mythic_Plush_Familiar

	-- ── The Family Three (Chris's daughters; uploaded 2026-06-13, all Approved) ──
	apple_addy = 73277969488811,               -- Apple Addy (Pudding Hills)
	eggy_ellie = 111971804512275,              -- Eggy Ellie (Goo Coast)
	hot_dog_heidi = 125141679529292,           -- Hot Dog Heidi (Moonlit Hollow)
}

return CardImageAssets
