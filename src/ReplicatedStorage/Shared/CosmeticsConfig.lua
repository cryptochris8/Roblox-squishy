--!strict
-- CosmeticsConfig
-- The Sparkle Boutique catalog: cute things your buddy can WEAR, bought with
-- EARNED Sparkle Coins only (never Robux — sell style, never power; capsules
-- stay free). One slot per type: a hat, a trail, and a balloon can all be worn
-- at once. Shared so the client shop and the server validator always agree.
--
-- Prices are tuned against the kid economy (measured in docs/economy/
-- ECONOMY_MODEL.md: a 30-min session earns ~2,000 new-player to ~8,000
-- endgame) — so small items are an every-session treat and the crown/rainbow
-- are near-term goals; bigger sinks belong in future catalog waves.

export type Cosmetic = {
	id: string,
	name: string,
	icon: string,
	type: string, -- "hat" | "trail" | "balloon"
	price: number?, -- Sparkle Coins (nil for premium items)
	-- Phase D premium items: sold once for Robux (Developer Product ids live
	-- in MonetizationConfig); ownership lands in the same Cosmetics.Owned set
	premium: boolean?,
	robux: number?,
	-- Earned-only rewards (e.g. the Rainbow Keeper Crown): never sold for coins
	-- OR Robux — granted by MilestoneService, then wearable like anything else
	reward: boolean?,
	-- builder hints (colors etc.) used by BuddyService's prop builders
	color: Color3?,
	color2: Color3?,
}

local CosmeticsConfig = {}

CosmeticsConfig.Types = { "hat", "trail", "balloon" }
CosmeticsConfig.TypeLabel = {
	hat = "Hats",
	trail = "Sparkle Trails",
	balloon = "Balloons",
}

local catalog: { Cosmetic } = {
	-- ── Hats ────────────────────────────────────────────────────────────────
	{ id = "hat_party", name = "Party Hat", icon = "🎉", type = "hat", price = 150,
		color = Color3.fromRGB(255, 150, 180), color2 = Color3.fromRGB(255, 226, 140) },
	{ id = "hat_star", name = "Star Clip", icon = "⭐", type = "hat", price = 150,
		color = Color3.fromRGB(255, 220, 110) },
	{ id = "hat_bow", name = "Big Bow", icon = "🎀", type = "hat", price = 200,
		color = Color3.fromRGB(255, 130, 170) },
	{ id = "hat_flowers", name = "Flower Crown", icon = "🌸", type = "hat", price = 250,
		color = Color3.fromRGB(255, 170, 200), color2 = Color3.fromRGB(200, 230, 180) },
	{ id = "hat_mushroom", name = "Mushroom Cap", icon = "🍄", type = "hat", price = 250,
		color = Color3.fromRGB(235, 120, 140), color2 = Color3.fromRGB(255, 248, 240) },
	{ id = "hat_crown", name = "Tiny Crown", icon = "👑", type = "hat", price = 400,
		color = Color3.fromRGB(255, 208, 90) },

	-- ── Sparkle Trails ──────────────────────────────────────────────────────
	{ id = "trail_bubbles", name = "Bubble Trail", icon = "🫧", type = "trail", price = 250,
		color = Color3.fromRGB(190, 235, 255) },
	{ id = "trail_hearts", name = "Heart Sparkles", icon = "💖", type = "trail", price = 300,
		color = Color3.fromRGB(255, 140, 180) },
	{ id = "trail_stars", name = "Star Sparkles", icon = "⭐", type = "trail", price = 300,
		color = Color3.fromRGB(255, 224, 130) },
	{ id = "trail_rainbow", name = "Rainbow Ribbon", icon = "🌈", type = "trail", price = 600 },

	-- ── Balloons ────────────────────────────────────────────────────────────
	{ id = "balloon_pink", name = "Pink Balloon", icon = "🎈", type = "balloon", price = 200,
		color = Color3.fromRGB(255, 150, 180) },
	{ id = "balloon_gold", name = "Gold Balloon", icon = "💛", type = "balloon", price = 200,
		color = Color3.fromRGB(255, 208, 100) },

	-- ── Premium Sparkles (Phase D — Robux, one-time, style only) ────────────
	{ id = "hat_strawberry_beret", name = "Strawberry Beret", icon = "🍓", type = "hat",
		premium = true, robux = 79,
		color = Color3.fromRGB(232, 64, 92), color2 = Color3.fromRGB(255, 226, 150) },
	{ id = "balloon_rainbow_heart", name = "Rainbow Heart Balloon", icon = "💖", type = "balloon",
		premium = true, robux = 99,
		color = Color3.fromRGB(255, 110, 140) },
	{ id = "hat_unicorn_horn", name = "Unicorn Horn", icon = "🦄", type = "hat",
		premium = true, robux = 149,
		color = Color3.fromRGB(255, 201, 84), color2 = Color3.fromRGB(240, 160, 40) },
	{ id = "trail_comet", name = "Comet Trail", icon = "🌠", type = "trail",
		premium = true, robux = 199,
		color = Color3.fromRGB(255, 228, 140) },
	{ id = "hat_golden_halo", name = "Golden Halo", icon = "😇", type = "hat",
		premium = true, robux = 249,
		color = Color3.fromRGB(255, 214, 90) },
	{ id = "trail_aurora", name = "Aurora Ribbon", icon = "🌌", type = "trail",
		premium = true, robux = 249,
		color = Color3.fromRGB(140, 230, 200), color2 = Color3.fromRGB(190, 150, 255) },

	-- ── Earned rewards (never sold — see MilestoneService) ──────────────────
	{ id = "hat_rainbow_keeper", name = "Rainbow Keeper Crown", icon = "🌈", type = "hat",
		reward = true,
		color = Color3.fromRGB(255, 214, 90) },
}
CosmeticsConfig.Catalog = catalog

local byId: { [string]: Cosmetic } = {}
for _, item in ipairs(catalog) do
	byId[item.id] = item
end

function CosmeticsConfig.get(id: string): Cosmetic?
	return byId[id]
end

-- COIN items of one type, in catalog (cheap -> fancy) order. Premium items
-- are excluded here — they render on the Boutique's own Premium shelf — and so
-- are earned rewards (the shop can't sell what can only be earned).
function CosmeticsConfig.ofType(cosmeticType: string): { Cosmetic }
	local list = {}
	for _, item in ipairs(CosmeticsConfig.Catalog) do
		if item.type == cosmeticType and not item.premium and not item.reward then
			list[#list + 1] = item
		end
	end
	return list
end

-- Earned-only rewards of one type (shown on a shelf only once owned, so kids
-- can re-wear them after trying something else on).
function CosmeticsConfig.rewardItems(cosmeticType: string): { Cosmetic }
	local list = {}
	for _, item in ipairs(CosmeticsConfig.Catalog) do
		if item.type == cosmeticType and item.reward then
			list[#list + 1] = item
		end
	end
	return list
end

-- The Premium shelf, in catalog (cheap -> fancy) order.
function CosmeticsConfig.premiumItems(): { Cosmetic }
	local list = {}
	for _, item in ipairs(CosmeticsConfig.Catalog) do
		if item.premium then
			list[#list + 1] = item
		end
	end
	return list
end

return CosmeticsConfig
