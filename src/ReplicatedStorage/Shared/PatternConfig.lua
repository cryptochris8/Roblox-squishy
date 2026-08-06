-- PatternConfig
-- Sparkle Patterns (doc 15 §7.1): a third, horizontal collection axis — a
-- "coat" a friend can wear. Rolled server-side with EVERY capsule open
-- (discovery or duplicate alike), purely additive, never lost, no FOMO:
-- every pattern drops everywhere forever; land bias only changes WHERE the
-- hunting is best. Shared so the server roller, the Book, the reveal, and the
-- odds surfaces always agree.
--
-- LAW LOCKS baked in: zero power, zero price differences (one small flat
-- "new pattern!" coin bonus), all odds public, Classic is guaranteed at
-- discovery so no friend is ever pattern-less, and a roll that lands a
-- pattern the friend already wears is simply a quiet nothing — never a miss.

local PatternConfig = {}

-- The friend's built-in look. Not stored, not rolled: every discovered friend
-- "owns" Classic by definition, and wearing Classic = no WornPatterns entry.
PatternConfig.ClassicId = "classic"
PatternConfig.ClassicName = "Classic"

-- Flat Sparkle Coins the FIRST time a given pattern lands on a given friend.
PatternConfig.NewPatternBonusCoins = 15

-- Weights are "per 10,000 capsule opens" (so kid-readable odds stay exact):
-- berry/mint ~1 in 6, honey ~1 in 12, starlight/moonlit ~1 in 25,
-- galaxy ~1 in 100, golden ~1 in 250. Everything else rolls NO pattern —
-- which is not a miss, it's just the friend arriving as their classic self.
--
-- Visuals are programmatic only (zero uploads): tint blends over the model's
-- own colours, material swaps are gentle, particles/light are small and
-- budget-scaled by the applier.
PatternConfig.Patterns = {
	{
		id = "berry_swirl",
		name = "Berry Swirl",
		weight = 1667,
		tint = Color3.fromRGB(255, 150, 190),
		tintStrength = 0.35,
		particle = "drift",
		particleColor = Color3.fromRGB(255, 120, 170),
		badgeColor = Color3.fromRGB(235, 110, 160),
	},
	{
		id = "mint_drizzle",
		name = "Mint Drizzle",
		weight = 1667,
		tint = Color3.fromRGB(150, 235, 200),
		tintStrength = 0.35,
		particle = "drip",
		particleColor = Color3.fromRGB(120, 225, 185),
		badgeColor = Color3.fromRGB(80, 190, 150),
	},
	{
		id = "honey_glaze",
		name = "Honey Glaze",
		weight = 833,
		tint = Color3.fromRGB(255, 205, 110),
		tintStrength = 0.4,
		material = Enum.Material.Glass,
		particle = "drift",
		particleColor = Color3.fromRGB(255, 215, 130),
		badgeColor = Color3.fromRGB(225, 165, 60),
	},
	{
		id = "starlight_freckles",
		name = "Starlight Freckles",
		weight = 400,
		tint = Color3.fromRGB(120, 130, 200),
		tintStrength = 0.3,
		particle = "freckle",
		particleColor = Color3.fromRGB(255, 255, 255),
		badgeColor = Color3.fromRGB(110, 120, 210),
	},
	{
		id = "moonlit",
		name = "Moonlit",
		weight = 400,
		tint = Color3.fromRGB(160, 190, 255),
		tintStrength = 0.3,
		light = { color = Color3.fromRGB(170, 200, 255), brightness = 0.8, range = 9 },
		particle = "drift",
		particleColor = Color3.fromRGB(190, 215, 255),
		badgeColor = Color3.fromRGB(130, 160, 240),
	},
	{
		id = "galaxy_swirl",
		name = "Galaxy Swirl",
		weight = 100,
		tint = Color3.fromRGB(130, 90, 200),
		tintStrength = 0.45,
		material = Enum.Material.ForceField,
		particle = "spiral",
		particleColor = Color3.fromRGB(130, 220, 220),
		badgeColor = Color3.fromRGB(140, 90, 220),
	},
	{
		id = "golden_crumb",
		name = "Golden Crumb",
		weight = 40,
		golden = true, -- rendered via SquishyModelFactory's applyGolden path
		tint = Color3.fromRGB(255, 200, 70),
		tintStrength = 0.6,
		particle = "drift",
		particleColor = Color3.fromRGB(255, 225, 120),
		badgeColor = Color3.fromRGB(230, 175, 40),
	},
}

-- Where the hunting is best (never the only place): a capsule can multiply a
-- pattern's weight. Every pattern still drops from every capsule.
PatternConfig.CapsuleBias = {
	StarterCapsule = { honey_glaze = 2 },
	GooCapsule = { mint_drizzle = 2 },
	MoonlitCapsule = { moonlit = 3 },
}

PatternConfig.TotalWeight = 10000 -- the "no new pattern this time" remainder fills to here

local byId = {}
for _, pat in ipairs(PatternConfig.Patterns) do
	byId[pat.id] = pat
end

function PatternConfig.get(id)
	return byId[id]
end

function PatternConfig.nameFor(id)
	if id == PatternConfig.ClassicId then
		return PatternConfig.ClassicName
	end
	local pat = byId[id]
	return pat and pat.name or ""
end

-- The effective weight table for one capsule (bias applied).
function PatternConfig.weightsFor(capsuleKey)
	local bias = PatternConfig.CapsuleBias[capsuleKey] or {}
	local out = {}
	for _, pat in ipairs(PatternConfig.Patterns) do
		out[pat.id] = pat.weight * (bias[pat.id] or 1)
	end
	return out
end

return PatternConfig
