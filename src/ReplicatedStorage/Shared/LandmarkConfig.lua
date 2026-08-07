-- LandmarkConfig
-- The one registry of "places you can go" in every land, and the source of
-- truth for the Sparkle Beacon system.
--
-- WHY THIS EXISTS (measured 2026-08-07): standing at the Pudding Hills spawn,
-- facing forward, a player could read exactly ONE destination name in the whole
-- game. WorldService labels default to MaxDistance 60 while destinations sit
-- 50-150 studs apart, so a genuinely large world announced nothing about
-- itself. The 60-stud cap was never wrong — an offset-sized BillboardGui holds
-- CONSTANT SCREEN SIZE at any distance, so a dozen distant labels really do
-- stack into word soup. The fix is not "raise the number", it is two tiers:
--
--   TIER 1 (server, LandmarkService): a physical candy balloon over every
--   landmark. Parts have no MaxDistance, so it is visible from anywhere, and
--   it carries NO text — which is also why a six-year-old who can't read yet
--   can still navigate by colour and icon.
--
--   TIER 2 (client, LandmarkBeacons): the NAME, shown only in a middle
--   distance band, capped and de-overlapped so it can never become soup.
--
--   TIER 3: everything else keeps MaxDistance 60. Unchanged, and correct.
--
-- POSITIONS ARE FINAL WORLD LITERALS. Landmarks were never run through
-- ZoneConfig.spread (only pads, paths, treats and scatter props are), so do
-- NOT spread these. Land centres: Pudding (0,0,0), Goo (600,0,0),
-- Moonlit (1200,0,0).
--
-- ICONS ARE A FIXED VOCABULARY: 🎁 always means capsule, in all three lands.
-- A kid learns ten glyphs in one session; she cannot learn ten sentences at
-- 200 studs. Every glyph here is from the project's proven-good set
-- (docs/14 §2) or already ships in a live string.

local LandmarkConfig = {}

export type Landmark = {
	id: string,
	land: string,
	pos: Vector3, -- FINAL world position (the balloon floats above this)
	icon: string,
	name: string,
	color: Color3,
	height: number?, -- balloon height above the ribbon's foot (default 30)
	-- Start the ribbon at this Y instead of raycasting for the ground. Needed
	-- wherever the structure below is CanQuery = false (every CoasterService and
	-- PlaygroundService part is), because the build-time ray passes straight
	-- through it and the ribbon would spear a roof.
	footY: number?,
	-- This landmark's OWN world label range. Below it the banner stays silent so
	-- the place is never named twice. Defaults to NearBand.
	nearBand: number?,
}

local C = Color3.fromRGB

LandmarkConfig.DefaultHeight = 30

LandmarkConfig.Landmarks = {
	-- ── Pudding Hills ───────────────────────────────────────────────────────
	{ id = "ph_capsule", land = "Pudding Hills", pos = Vector3.new(-17, 3.5, -52),
	  icon = "🎁", name = "Sparkle Capsule", color = C(255, 150, 195) },
	{ id = "ph_garden", land = "Pudding Hills", pos = Vector3.new(0, 0, 95),
	  icon = "🌱", name = "Sparkle Garden", color = C(140, 220, 150), height = 26, nearBand = 112 },
	{ id = "ph_switcheroo", land = "Pudding Hills", pos = Vector3.new(112, 0, -46),
	  icon = "💝", name = "Switcheroo Station", color = C(235, 110, 120) },
	{ id = "ph_boutique", land = "Pudding Hills", pos = Vector3.new(78, 0, 26),
	  icon = "🎀", name = "Sparkle Boutique", color = C(255, 175, 205) },
	{ id = "ph_travel", land = "Pudding Hills", pos = Vector3.new(116, 0, 31),
	  icon = "🌈", name = "Travel Pads", color = C(170, 190, 255) },
	{ id = "ph_shard", land = "Pudding Hills", pos = Vector3.new(68, 0, -58),
	  icon = "⭐", name = "Sparkle Shard", color = C(255, 215, 120), nearBand = 152 },
	-- footY: start the ribbon ABOVE a structure the build-time raycast cannot
	-- see. CoasterService/PlaygroundService parts are CanQuery = false, so the
	-- ray passes straight through their canopies and towers (review catch) —
	-- these beacons read as "tied to the roof", which is what we wanted anyway.
	{ id = "ph_coaster", land = "Pudding Hills", pos = Vector3.new(10, 0, 131),
	  icon = "🚂", name = "Sparkle Express", color = C(255, 190, 120), height = 30, footY = 13.5, nearBand = 102 },
	{ id = "ph_plunge", land = "Pudding Hills", pos = Vector3.new(78, 0, 104),
	  icon = "🍮", name = "Pudding Plunge", color = C(150, 210, 255), height = 40, footY = 23, nearBand = 82 },
	{ id = "ph_wheel", land = "Pudding Hills", pos = Vector3.new(67, 0, 3),
	  icon = "🎈", name = "Sparkle Wheel", color = C(255, 200, 230), height = 46, footY = 34 },
	{ id = "ph_tent", land = "Pudding Hills", pos = Vector3.new(-49, 0, 68),
	  icon = "💖", name = "Visiting Friend", color = C(255, 170, 160), height = 24 },
	{ id = "ph_photo", land = "Pudding Hills", pos = Vector3.new(-40, 0, 6),
	  icon = "📸", name = "Photo Spot", color = C(255, 210, 160), height = 22 },

	-- ── Goo Coast ───────────────────────────────────────────────────────────
	{ id = "gc_capsule", land = "Goo Coast", pos = Vector3.new(545, 3.5, 49),
	  icon = "🎁", name = "Goo Capsule", color = C(120, 220, 200) },
	{ id = "gc_guide", land = "Goo Coast", pos = Vector3.new(615, 2.5, 20),
	  icon = "🧸", name = "Bloop the Guide", color = C(150, 226, 234), height = 22 },
	{ id = "gc_shard", land = "Goo Coast", pos = Vector3.new(668, 0, -58),
	  icon = "⭐", name = "Sparkle Shard", color = C(255, 215, 120), nearBand = 152 },
	{ id = "gc_travel", land = "Goo Coast", pos = Vector3.new(675, 0, 10),
	  icon = "🌈", name = "Travel Pads", color = C(170, 190, 255) },
	{ id = "gc_bog", land = "Goo Coast", pos = Vector3.new(630, 0, 80),
	  icon = "😄", name = "Bounce Bog", color = C(180, 240, 200), height = 30, nearBand = 82 },
	{ id = "gc_cannon", land = "Goo Coast", pos = Vector3.new(608, 0, -4),
	  icon = "🌟", name = "Sparkle-Pop Cannon", color = C(255, 190, 150), height = 24, nearBand = 82 },
	{ id = "gc_river", land = "Goo Coast", pos = Vector3.new(628, 0, -20),
	  icon = "💧", name = "Lazy Goo River", color = C(160, 230, 255), height = 22, nearBand = 82 },
	{ id = "gc_photo", land = "Goo Coast", pos = Vector3.new(516, 0, 24),
	  icon = "📸", name = "Photo Spot", color = C(255, 210, 160), height = 22 },

	-- ── Moonlit Hollow ──────────────────────────────────────────────────────
	{ id = "mh_capsule", land = "Moonlit Hollow", pos = Vector3.new(1249, 3.5, 49),
	  icon = "🎁", name = "Moonlit Capsule", color = C(180, 150, 240) },
	{ id = "mh_guide", land = "Moonlit Hollow", pos = Vector3.new(1180, 2.5, 23),
	  icon = "🧸", name = "Nox the Guide", color = C(176, 152, 224), height = 22 },
	{ id = "mh_shard", land = "Moonlit Hollow", pos = Vector3.new(1268, 0, -58),
	  icon = "⭐", name = "Sparkle Shard", color = C(255, 215, 120), nearBand = 152 },
	{ id = "mh_travel", land = "Moonlit Hollow", pos = Vector3.new(1252, 0, -88),
	  icon = "🌈", name = "Travel Pads", color = C(170, 190, 255) },
	{ id = "mh_hops", land = "Moonlit Hollow", pos = Vector3.new(1224, 0, -42),
	  icon = "🍄", name = "Mushroom Hops", color = C(220, 160, 240), height = 26 },
	{ id = "mh_zip", land = "Moonlit Hollow", pos = Vector3.new(1150, 0, 8),
	  icon = "✨", name = "Firefly Zip Line", color = C(200, 230, 255), height = 34, footY = 18, nearBand = 82 },
	{ id = "mh_photo", land = "Moonlit Hollow", pos = Vector3.new(1266, 0, -80),
	  icon = "📸", name = "Photo Spot", color = C(255, 210, 160), height = 22 },
}

-- Which land a world position belongs to (lands sit at x = 0 / 600 / 1200).
function LandmarkConfig.landAt(pos: Vector3): string
	if pos.X < 300 then
		return "Pudding Hills"
	elseif pos.X < 900 then
		return "Goo Coast"
	end
	return "Moonlit Hollow"
end

function LandmarkConfig.forLand(land: string): { Landmark }
	local out = {}
	for _, lm in ipairs(LandmarkConfig.Landmarks) do
		if lm.land == land then
			table.insert(out, lm)
		end
	end
	return out
end

function LandmarkConfig.get(id: string): Landmark?
	for _, lm in ipairs(LandmarkConfig.Landmarks) do
		if lm.id == id then
			return lm
		end
	end
	return nil
end

-- ── The distance bands (shared so server and client agree) ──────────────────
-- Under the near band a landmark's OWN world label is already showing, so the
-- banner stays silent — never two names for one place. Most labels cap at 60
-- (WorldService's default), but several services set their own much longer
-- ranges (quest shards 160, the garden arch 120, the coaster station 110, every
-- playground sign 90), so those landmarks carry an explicit `nearBand`. The
-- default is 52 rather than 60 because BillboardGui.MaxDistance measures from
-- the CAMERA, which third-person sits ~12 studs behind the character.
LandmarkConfig.NearBand = 52
LandmarkConfig.NameBand = 210 -- ..up to here the banner shows icon + name
-- Beyond NameBand only the physical balloon speaks (colour + icon, no text).

-- ── The anti-soup contract (hard caps; see the WorldService.lua:52 scar) ────
LandmarkConfig.MaxNames = 3 -- named banners on screen at once
LandmarkConfig.MaxNamesCompact = 1 -- ...on a phone
LandmarkConfig.MinNameSpacingPx = 120 -- closer than this on screen: demote the farther one
LandmarkConfig.MinNameSpacingPxCompact = 90

return LandmarkConfig
