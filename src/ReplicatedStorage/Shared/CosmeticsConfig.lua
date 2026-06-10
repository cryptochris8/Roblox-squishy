--!strict
-- CosmeticsConfig
-- The Sparkle Boutique catalog: cute things your buddy can WEAR, bought with
-- EARNED Sparkle Coins only (never Robux — sell style, never power; capsules
-- stay free). One slot per type: a hat, a trail, and a balloon can all be worn
-- at once. Shared so the client shop and the server validator always agree.
--
-- Prices are tuned against the kid economy: a cozy session earns ~100-300 coins
-- (pops + dailies + bits), the finale gifts 1000 — so small items are an
-- every-session treat and the crown/rainbow are real goals.

export type Cosmetic = {
	id: string,
	name: string,
	icon: string,
	type: string, -- "hat" | "trail" | "balloon"
	price: number,
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
}
CosmeticsConfig.Catalog = catalog

local byId: { [string]: Cosmetic } = {}
for _, item in ipairs(catalog) do
	byId[item.id] = item
end

function CosmeticsConfig.get(id: string): Cosmetic?
	return byId[id]
end

-- Catalog items of one type, in catalog (cheap -> fancy) order.
function CosmeticsConfig.ofType(cosmeticType: string): { Cosmetic }
	local list = {}
	for _, item in ipairs(CosmeticsConfig.Catalog) do
		if item.type == cosmeticType then
			list[#list + 1] = item
		end
	end
	return list
end

return CosmeticsConfig
