--!strict
-- GardenConfig (SHARED)
-- The Sparkle Garden's source of truth — the same seed list, growth curve, and
-- watering rules that the server (GardenService) validates against and the client
-- (GardenUI / WaterFx) renders from. Prices come from docs/economy/ECONOMY_MODEL.md
-- §6 (yield ~1.5x price so patience always pays but never out-earns playing).
--
-- THE LAW: plants NEVER wilt, die, or get stolen. Growth only ACCUMULATES from an
-- os.time() delta computed on read — it grows while the kid is at school, with
-- nothing to miss and no timers. Watering is pure upside (adds sparkle; not
-- watering changes nothing). Never write neglect/decay/"your plant is sad" copy.

export type Seed = {
	id: string,
	name: string,
	icon: string, -- a well-supported emoji only (🌱🌸🌈 — NOT 🪙/✕)
	price: number, -- Sparkle Coins to plant
	growSeconds: number, -- real seconds from plant to fully bloomed (grows offline)
	harvestCoins: number, -- coins paid on harvest (~1.5x price)
	dropChance: number, -- chance of a bonus "sparkle bloom" on harvest (0 = never)
	dropCoins: number, -- the bonus coins if the drop hits
	color: Color3, -- the bloom's colour (for the rendered plant + UI)
}

local GardenConfig = {}

-- Three seeds, short → long. A day-1 kid can afford the Sprout before logging off
-- (the come-back-tomorrow hook); the Rainbow Bloom is a 5-day patience treat.
GardenConfig.Seeds = {
	{
		id = "sprout",
		name = "Sunny Sprout",
		icon = "🌱",
		price = 50,
		growSeconds = 86400, -- 1 day
		harvestCoins = 75,
		dropChance = 0,
		dropCoins = 0,
		color = Color3.fromRGB(255, 224, 130),
	},
	{
		id = "berry",
		name = "Berry Bloom",
		icon = "🌸",
		price = 150,
		growSeconds = 259200, -- 3 days
		harvestCoins = 240,
		dropChance = 0.15,
		dropCoins = 60,
		color = Color3.fromRGB(255, 150, 200),
	},
	{
		id = "rainbow",
		name = "Rainbow Bloom",
		icon = "🌈",
		price = 300,
		growSeconds = 432000, -- 5 days
		harvestCoins = 450,
		dropChance = 0.30, -- the doc's "incl. decor roll" — EV ≈ 450 + 0.30×150 ≈ 495
		dropCoins = 150,
		color = Color3.fromRGB(170, 200, 255),
	},
}

local byId: { [string]: Seed } = {}
for _, s in ipairs(GardenConfig.Seeds) do
	byId[s.id] = s
end

function GardenConfig.getSeed(id: string?): Seed?
	if type(id) ~= "string" then
		return nil
	end
	return byId[id]
end

-- Each player tends this many beds (a fast sprout + a slow bloom can grow together).
GardenConfig.BedsPerPlayer = 3
GardenConfig.BedIds = { "1", "2", "3" }

-- How many plot slots the shared district pre-places (a family + friends). A player
-- claims a free slot on join; unclaimed slots show as plain, ready-to-plant soil.
GardenConfig.PlotSlots = 8

-- The four visible growth stages (a plant model per stage). grownPct is 0..1.
GardenConfig.Stages = { "seedling", "sprouting", "budding", "bloomed" }

-- Growth is emergent, never ticked: how grown a bed is right now, in seconds.
function GardenConfig.grownSeconds(plantedAt: number, wateredBonus: number, now: number): number
	return math.max(0, (now - plantedAt) + (wateredBonus or 0))
end

-- 0..1 progress toward fully bloomed (clamped — it only ever goes UP, never back).
function GardenConfig.grownPct(seed: Seed, plantedAt: number, wateredBonus: number, now: number): number
	if seed.growSeconds <= 0 then
		return 1
	end
	return math.clamp(GardenConfig.grownSeconds(plantedAt, wateredBonus, now) / seed.growSeconds, 0, 1)
end

function GardenConfig.stageFor(pct: number): string
	if pct >= 1 then
		return "bloomed"
	elseif pct >= 0.6 then
		return "budding"
	elseif pct >= 0.25 then
		return "sprouting"
	end
	return "seedling"
end

function GardenConfig.isReady(seed: Seed, plantedAt: number, wateredBonus: number, now: number): boolean
	return GardenConfig.grownPct(seed, plantedAt, wateredBonus, now) >= 1
end

-- Kindness watering rules (v1 = same-server, online owners only).
GardenConfig.Watering = {
	PerDay = 5, -- waters a kid can GIVE per UTC day
	ReceivedPerDay = 3, -- waters a garden can RECEIVE per UTC day (owner keeps agency)
	Range = 14, -- server-checked stud range (generous, like Gifting)
	PromptDistance = 10, -- ProximityPrompt activation distance
	PairCooldown = 40, -- seconds between the same pair watering again (os.clock)
	BonusSeconds = 3600, -- growth (seconds) one water adds to each growing bed (a gentle nudge)
}

return GardenConfig
