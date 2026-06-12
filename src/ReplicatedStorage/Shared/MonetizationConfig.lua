--!strict
-- MonetizationConfig
-- Phase D: the REAL Creator Hub product ids (created by Chris on 2026-06-11)
-- and what each one unlocks. The guardrails live here as much as in code:
-- Sparkle Capsules stay FREE, nothing random is ever sold for Robux, every
-- friend stays earnable, and we sell style & convenience — never power.
-- Shared so the Boutique storefront and the server validator always agree.

export type PassInfo = {
	key: string,
	passId: number,
	name: string,
	icon: string,
	robux: number,
	blurb: string,
}

local MonetizationConfig = {}

MonetizationConfig.Passes = {
	BuddySlot = {
		key = "BuddySlot",
		passId = 1874460336,
		name = "Extra Buddy Slot",
		icon = "🧸",
		robux = 99,
		blurb = "Walk with TWO buddies at once!",
	},
	CoinBoost = {
		key = "CoinBoost",
		passId = 1874900312,
		name = "Coin Boost",
		icon = "⭐",
		robux = 149,
		blurb = "+25% Sparkle Coins from every Happy Pop!",
	},
	VIP = {
		key = "VIP",
		passId = 1875272322,
		name = "Sparkle Club VIP",
		icon = "👑",
		robux = 249,
		blurb = "Golden VIP sparkle + aura, and an extra daily gift!",
	},
} :: { [string]: PassInfo }

-- storefront display order (cheap -> fancy)
MonetizationConfig.PassOrder = { "BuddySlot", "CoinBoost", "VIP" }

-- what the perks actually do
MonetizationConfig.CoinBoostMultiplier = 1.25
MonetizationConfig.VipExtraDailyGifts = 1

-- Premium cosmetics (Developer Products): cosmetic item id -> live product id.
-- The items themselves live in CosmeticsConfig with premium = true, so the
-- Boutique, the buddy dresser, and the equip validator share one catalog.
MonetizationConfig.ProductIdByItem = {
	hat_strawberry_beret = 3604067414,
	balloon_rainbow_heart = 3604067788,
	hat_unicorn_horn = 3604067990,
	trail_comet = 3604068204,
	hat_golden_halo = 3604068473,
	trail_aurora = 3604068682,
} :: { [string]: number }

-- reverse lookup for ProcessReceipt (product id -> cosmetic item id)
local itemByProduct: { [number]: string } = {}
for itemId, productId in pairs(MonetizationConfig.ProductIdByItem) do
	itemByProduct[productId] = itemId
end

function MonetizationConfig.itemForProduct(productId: number): string?
	return itemByProduct[productId]
end

function MonetizationConfig.passForId(passId: number): PassInfo?
	for _, info in pairs(MonetizationConfig.Passes) do
		if info.passId == passId then
			return info
		end
	end
	return nil
end

return MonetizationConfig
