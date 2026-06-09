--!strict
-- CapsuleService (SERVER)
-- The Sparkle Capsule: a gentle, kid-friendly "discover a friend" machine (never
-- framed as gambling). Picks a rarity by weight, then a random friend of that
-- rarity from the allowed pack, and discovers it. Duplicates give a warm
-- "Friendship Bonus" instead of feeling like a miss. Server-authoritative RNG.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SquishyData = require(Shared:WaitForChild("SquishyData"))
local CapsuleConfig = require(Shared:WaitForChild("CapsuleConfig"))
local VariantConfig = require(Shared:WaitForChild("VariantConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local CapsuleService = {}

-- optional hook (wired by Main): onOpened(player, isNew), called after a capsule
-- successfully opens. Typed `any` so strict mode allows the late binding.
CapsuleService.onOpened = (nil :: any)

local capsuleResultEvent: RemoteEvent
local toastEvent: RemoteEvent
local rng = Random.new()

-- Group the allowed-pack friends by rarity, so we never roll a rarity that has
-- no friends in this capsule (e.g. the starter Squishy Foods pack has no
-- legendary-tier friend).
local function buildRarityPool(allowedPackIds: { string }): { [string]: { any } }
	local byRarity: { [string]: { any } } = {}
	for _, packId in ipairs(allowedPackIds) do
		for _, def in ipairs(SquishyData.getByPack(packId)) do
			local bucket = byRarity[def.Rarity]
			if not bucket then
				bucket = {}
				byRarity[def.Rarity] = bucket
			end
			table.insert(bucket, def)
		end
	end
	return byRarity
end

local function pickRarity(weights: { [string]: number }, byRarity: { [string]: { any } }): string?
	local total = 0
	local entries: { { rarity: string, w: number } } = {}
	for rarity, weight in pairs(weights) do
		local bucket = byRarity[rarity]
		if bucket and #bucket > 0 and weight > 0 then
			table.insert(entries, { rarity = rarity, w = weight })
			total += weight
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber(0, total)
	local acc = 0
	for _, entry in ipairs(entries) do
		acc += entry.w
		if roll <= acc then
			return entry.rarity
		end
	end
	return entries[#entries].rarity
end

function CapsuleService.tryOpen(player: Player, freeOverride: boolean?): boolean
	local cfg = CapsuleConfig.StarterCapsule

	-- Make sure we can actually give a friend BEFORE charging coins or using the
	-- free gift, so the player is never left empty-handed.
	local byRarity = buildRarityPool(cfg.AllowedPackIds)
	local rarity = pickRarity(cfg.RarityWeights, byRarity)
	if not rarity then
		toastEvent:FireClient(player, "The Sparkle Capsule is recharging - try again in a moment!")
		return false
	end

	-- The first capsule and the daily gift are free; otherwise it costs coins.
	local isFree = freeOverride == true
	if not isFree then
		if GameConfig.FirstCapsuleIsFree and not PlayerDataService.isFirstCapsuleClaimed(player) then
			isFree = true
			PlayerDataService.markFirstCapsuleClaimed(player)
		elseif not PlayerDataService.spendCoins(player, cfg.Cost) then
			toastEvent:FireClient(player, "You need " .. cfg.Cost .. " Sparkle Coins to open a Sparkle Capsule!")
			return false
		end
	end

	local bucket = byRarity[rarity]
	local def = bucket[rng:NextInteger(1, #bucket)]

	local isNew = PlayerDataService.discoverCard(player, def.Id)
	local bonusCoins = 0
	local variantLevel = 0
	local variantUpgraded = false
	if not isNew then
		-- A duplicate "shines up" the friend: Discovered -> Sparkly -> Rainbow.
		variantLevel = PlayerDataService.getVariant(player, def.Id)
		if variantLevel < VariantConfig.Max then
			variantLevel = PlayerDataService.upgradeVariant(player, def.Id)
			variantUpgraded = true
			local lv = VariantConfig.Levels[variantLevel]
			bonusCoins = (lv and lv.bonusCoins) or cfg.DuplicateRewardCoins or 0
		else
			bonusCoins = VariantConfig.MaxDuplicateCoins or cfg.DuplicateRewardCoins or 0
		end
		if bonusCoins > 0 then
			PlayerDataService.addCoins(player, bonusCoins)
		end
	end

	capsuleResultEvent:FireClient(player, {
		defId = def.Id,
		displayName = def.DisplayName,
		cardNumber = def.CardNumber,
		rarity = def.Rarity,
		imageAssetId = def.ImageAssetId,
		isNew = isNew,
		bonusCoins = bonusCoins,
		wasFree = isFree,
		variantLevel = variantLevel,
		variantUpgraded = variantUpgraded,
	})
	PlayerDataService.sync(player)
	if CapsuleService.onOpened then
		CapsuleService.onOpened(player, isNew)
	end
	return true
end

function CapsuleService.init()
	capsuleResultEvent = Remotes.get(Remotes.CapsuleResult)
	toastEvent = Remotes.get(Remotes.Toast)
end

return CapsuleService
