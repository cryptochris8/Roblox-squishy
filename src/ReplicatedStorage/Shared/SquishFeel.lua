-- SquishFeel
-- Per-friend squish "feel": four 0-1 dials that make each of the 56 friends
-- squish and pop a little differently, plus the colour lookups for their
-- ParticlePreset / DecalPreset. Read by SquishFx on the client (WO-1 items 5-6).
--
--   deform   — how FAR it squashes when squished    (squash amplitude)
--   elastic  — how SPRINGY the rebound is           (spring speed / overshoot)
--   goo      — how MUCH flies on a Happy Pop         (pop particle volume)
--   burst    — how EAGER it looks about-to-pop       (telegraph flavour)
--
-- 13 friends carry hand-tuned dials pulled verbatim from data/raw; the other 43
-- derive from their pack + theme so a doughy dumpling, a gooey blob, and a
-- bouncy stress ball all feel distinct, with a gentle per-id jitter so no two
-- friends are ever identical.

local Shared = script.Parent
local Definitions = require(Shared:WaitForChild("SquishyDefinitions"))

local SquishFeel = {}

-- { deform, elastic, goo, burst } — verbatim from data/raw for the friends that
-- ship hand-tuned physics.
local REAL = {
	round_eared_creature = { 0.78, 0.66, 0.61, 0.74 },
	candy_fang_creature = { 0.71, 0.59, 0.48, 0.81 },
	steamy = { 0.86, 0.6, 0.75, 0.8 },
	puffkin = { 0.9, 0.58, 0.68, 0.82 },
	dimpa = { 0.83, 0.66, 0.71, 0.77 },
	boblet = { 0.93, 0.52, 0.88, 0.71 },
	moshi = { 0.89, 0.54, 0.65, 0.84 },
	soupy_blob = { 0.94, 0.48, 0.95, 0.68 },
	gobble_puff = { 0.91, 0.55, 0.8, 0.86 },
	gold_dumplio = { 0.88, 0.62, 0.92, 0.9 },
	goo_ball = { 0.95, 0.78, 0.42, 0.92 },
	soft_dumpling = { 0.88, 0.62, 0.83, 0.79 },
	jelly_bun = { 0.74, 0.71, 0.57, 0.68 },
}

-- Fallback dials by pack category, so the three families read differently even
-- for the friends without hand-tuned data: food = doughy, creature = springy,
-- goo = gooey-or-bouncy (split by theme below).
local CATEGORY_BASE = {
	squishy_food = { 0.86, 0.60, 0.66, 0.78 },
	creepy_cute = { 0.78, 0.64, 0.55, 0.77 },
	goo_fidget = { 0.88, 0.56, 0.78, 0.76 },
}
-- Inside the goo pack, bouncy fidgets and true goo pull in opposite directions.
local BOUNCY_THEMES = {
	stress_ball = true, bubble = true, wobble = true, shockwave = true,
	stretch = true, plasma = true, squish_capsule = true,
}
local GOOEY_THEMES = {
	slime_pet = true, sticky = true, glitter_goo = true, jelly_pad = true, jelly = true,
}
local BOUNCY = { 0.80, 0.80, 0.45, 0.85 }
local GOOEY = { 0.93, 0.50, 0.90, 0.72 }
local DEFAULT = { 0.80, 0.60, 0.62, 0.79 }

local cache = {}

-- A stable integer seed from the friend id, so its jitter never changes between
-- sessions (plain arithmetic — Luau has no `~`/`&` bitwise operators).
local function seedFor(id: string): number
	local h = 0
	for i = 1, #id do
		h = (h * 31 + string.byte(id, i)) % 2147483647
	end
	return h + 1
end

function SquishFeel.get(defId: string)
	local hit = cache[defId]
	if hit then
		return hit
	end
	local def = Definitions[defId]
	local base
	if REAL[defId] then
		base = REAL[defId]
	elseif def then
		local theme = def.ThemeTag
		if def.Category == "goo_fidget" and theme and BOUNCY_THEMES[theme] then
			base = BOUNCY
		elseif def.Category == "goo_fidget" and theme and GOOEY_THEMES[theme] then
			base = GOOEY
		else
			base = CATEGORY_BASE[def.Category or ""] or DEFAULT
		end
	else
		base = DEFAULT
	end

	-- A small deterministic jitter so no two friends are byte-identical (skipped
	-- for the hand-tuned 13 — their values are already distinct).
	local out
	if REAL[defId] then
		out = { deform = base[1], elastic = base[2], goo = base[3], burst = base[4] }
	else
		local r = Random.new(seedFor(defId))
		local function j(v)
			return math.clamp(v + r:NextNumber(-0.03, 0.03), 0.4, 0.97)
		end
		out = { deform = j(base[1]), elastic = j(base[2]), goo = j(base[3]), burst = j(base[4]) }
	end
	cache[defId] = out
	return out
end

-- ParticlePreset / DecalPreset → a colour. The preset strings already live on
-- every def in SquishyDefinitions; this is just the paint chip for each.
local PARTICLE_COLOR = {
	pink_soup_burst = Color3.fromRGB(255, 150, 175),
	blue_jelly_burst = Color3.fromRGB(150, 180, 245),
	cream_puff_burst = Color3.fromRGB(255, 240, 205),
	purple_monster_burst = Color3.fromRGB(190, 120, 240),
	green_goo_burst = Color3.fromRGB(150, 225, 150),
	gold_mythic_burst = Color3.fromRGB(255, 215, 90),
}
local SPLAT_COLOR = {
	soft_peach_splat = Color3.fromRGB(255, 190, 175),
	cool_blue_smear = Color3.fromRGB(170, 200, 245),
	cream_smudge = Color3.fromRGB(250, 235, 205),
	purple_monster_splat = Color3.fromRGB(190, 130, 235),
	green_goo_smear = Color3.fromRGB(150, 220, 150),
	gold_mythic_splat = Color3.fromRGB(255, 220, 120),
}

function SquishFeel.particleColor(def): Color3?
	return def and def.ParticlePreset and PARTICLE_COLOR[def.ParticlePreset] or nil
end

function SquishFeel.splatColor(def): Color3?
	return def and def.DecalPreset and SPLAT_COLOR[def.DecalPreset] or nil
end

return SquishFeel
