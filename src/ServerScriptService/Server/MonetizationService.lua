--!strict
-- MonetizationService (SERVER)
-- Phase D, kept honest: three QoL/style Game Passes and six premium cosmetics
-- as Developer Products — style and convenience, never power. Capsules stay
-- free and nothing random is ever sold for Robux.
--
-- Passes: ownership is checked on join (retried; Roblox is the source of
-- truth) and cached for the session; PromptGamePassPurchaseFinished grants
-- instantly mid-session (which is also what makes Studio test purchases
-- work, since those never persist to the real pass inventory).
--
-- Products: ProcessReceipt grants the premium cosmetic into the SAME
-- Cosmetics.Owned set the coin items use (so wearing/validating is shared),
-- auto-wears it, and only returns PurchaseGranted after the profile has
-- actually SAVED with the receipt id recorded — a crash can never eat a paid
-- purchase, and a replayed receipt is a no-op. Temp-profile sessions return
-- NotProcessedYet so Roblox retries when the player is back on a real save.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local MonetizationConfig = require(Shared:WaitForChild("MonetizationConfig"))
local CosmeticsConfig = require(Shared:WaitForChild("CosmeticsConfig"))
local GiftConfig = require(Shared:WaitForChild("GiftConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local MonetizationService = {}

-- Set by Main: the player's buddy needs re-dressing (new premium item worn,
-- or a pass that changes the buddy's look/slots arrived).
MonetizationService.onPremiumGranted = nil :: ((Player) -> ())?
MonetizationService.onPassesChanged = nil :: ((Player) -> ())?

local toastEvent: RemoteEvent

-- session cache: player -> { [passKey]: true }
local ownedPasses: { [Player]: { [string]: boolean } } = {}

function MonetizationService.ownsPass(player: Player, passKey: string): boolean
	local cache = ownedPasses[player]
	return (cache ~= nil) and (cache[passKey] == true)
end

-- snapshot()'s view of the cache (what the Boutique storefront renders from)
local function passesFor(player: Player): { [string]: boolean }
	local out = {}
	for key, owned in pairs(ownedPasses[player] or {}) do
		if owned then
			out[key] = true
		end
	end
	return out
end

-- What to multiply a Happy Pop's coins by for this player (Coin Boost pass).
function MonetizationService.coinMultiplier(player: Player): number
	return if MonetizationService.ownsPass(player, "CoinBoost")
		then MonetizationConfig.CoinBoostMultiplier
		else 1
end

-- Today's gift budget for this player (VIP carries one extra).
function MonetizationService.giftLimit(player: Player): number
	local limit = GiftConfig.DailyGiftLimit
	if MonetizationService.ownsPass(player, "VIP") then
		limit += MonetizationConfig.VipExtraDailyGifts
	end
	return limit
end

-- Check every pass with Roblox (retried — a flaky moment must not silently
-- strip a paid perk for the whole session).
local function refreshPasses(player: Player)
	local cache = ownedPasses[player]
	if not cache then
		return
	end
	for key, info in pairs(MonetizationConfig.Passes) do
		for attempt = 1, 3 do
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, info.passId)
			end)
			if ok then
				if owns then
					cache[key] = true
				end
				break
			end
			if attempt < 3 then
				task.wait(2 * attempt)
			else
				warn("[Squishy Smash] Pass check failed for " .. player.Name .. " / " .. info.name)
			end
		end
	end
end

-- The Sparkle Club welcome: a little red carpet, only after their first join
-- check (never on every sync).
local function vipWelcome(player: Player)
	toastEvent:FireClient(player, "👑 Welcome back to the Sparkle Club, " .. player.DisplayName .. "!")
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			toastEvent:FireClient(other, "👑 Sparkle Club VIP " .. player.DisplayName .. " has arrived!")
		end
	end
end

-- ── storefront requests (the Boutique's Premium shelf) ──────────────────────
local function onBuyPass(player: Player, passKey: any)
	if type(passKey) ~= "string" then
		return
	end
	local info = MonetizationConfig.Passes[passKey]
	if not info then
		return
	end
	if MonetizationService.ownsPass(player, passKey) then
		toastEvent:FireClient(player, "You already have " .. info.name .. "! " .. info.icon)
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, info.passId)
end

local function onBuyPremium(player: Player, itemId: any)
	if type(itemId) ~= "string" then
		return
	end
	local item = CosmeticsConfig.get(itemId)
	local productId = MonetizationConfig.ProductIdByItem[itemId]
	if not item or not item.premium or not productId then
		return
	end
	if PlayerDataService.ownsCosmetic(player, itemId) then
		toastEvent:FireClient(player, "You already have the " .. item.name .. "! Tap it to wear it.")
		return
	end
	MarketplaceService:PromptProductPurchase(player, productId)
end

-- A pass purchase finished (real or Studio test): grant it for this session
-- right away. Roblox persists real pass ownership itself.
local function onPassPurchaseFinished(player: Player, passId: number, wasPurchased: boolean)
	if not wasPurchased then
		return
	end
	local info = MonetizationConfig.passForId(passId)
	local cache = ownedPasses[player]
	if not (info and cache) or cache[info.key] then
		return
	end
	cache[info.key] = true
	toastEvent:FireClient(player, info.icon .. " " .. info.name .. " is yours — enjoy!")
	if info.key == "VIP" then
		vipWelcome(player)
	end
	PlayerDataService.sync(player)
	if MonetizationService.onPassesChanged then
		MonetizationService.onPassesChanged(player)
	end
end

-- OWNER-ONLY demo/testing: grant a pass for THIS SESSION only (no Robux, not
-- persisted — real ownership always comes from Roblox). Main gates the remote
-- to the place owner, same as the Event/Surge demo buttons.
function MonetizationService.debugGrantPass(player: Player, passKey: string)
	local info = MonetizationConfig.Passes[passKey]
	local cache = ownedPasses[player]
	if not (info and cache) or cache[passKey] then
		return
	end
	cache[passKey] = true
	toastEvent:FireClient(player, info.icon .. " (demo) " .. info.name .. " is on for this visit!")
	if passKey == "VIP" then
		vipWelcome(player)
	end
	PlayerDataService.sync(player)
	if MonetizationService.onPassesChanged then
		MonetizationService.onPassesChanged(player)
	end
end

-- ── Developer Product receipts ──────────────────────────────────────────────
-- Exposed by name so a Studio probe can exercise it with a fake receipt.
function MonetizationService.processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- retried on next join
	end
	-- the profile loads async; give it a moment before punting
	local deadline = os.clock() + 10
	while not PlayerDataService.isReady(player) and player.Parent ~= nil and os.clock() < deadline do
		task.wait(0.25)
	end
	if not PlayerDataService.isReady(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not PlayerDataService.isSavable(player) then
		-- temp profile (lock held elsewhere / DataStore down): never consume a
		-- paid receipt we can't persist
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receiptInfo.PurchaseId)
	if PlayerDataService.hasProcessedReceipt(player, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- replay: already granted
	end
	local itemId = MonetizationConfig.itemForProduct(tonumber(receiptInfo.ProductId) or 0)
	local item = itemId and CosmeticsConfig.get(itemId)
	if not itemId or not item then
		warn("[Squishy Smash] Receipt for UNKNOWN product " .. tostring(receiptInfo.ProductId) .. " — leaving unprocessed.")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	PlayerDataService.grantCosmetic(player, itemId)
	PlayerDataService.setEquippedCosmetic(player, item.type, itemId) -- auto-wear, like every Boutique buy
	PlayerDataService.markReceiptProcessed(player, purchaseId)
	if not PlayerDataService.saveNow(player) then
		-- could not persist: hand the receipt back to Roblox to retry later.
		-- (The grant lives only in memory; re-granting on retry is a no-op.)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	toastEvent:FireClient(player, item.icon .. " The " .. item.name .. " is yours — your buddy is wearing it!")
	PlayerDataService.sync(player)
	if MonetizationService.onPremiumGranted then
		MonetizationService.onPremiumGranted(player)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.init()
	toastEvent = Remotes.get(Remotes.Toast)
	Remotes.get(Remotes.BuyPass).OnServerEvent:Connect(onBuyPass)
	Remotes.get(Remotes.BuyPremium).OnServerEvent:Connect(onBuyPremium)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(onPassPurchaseFinished)
	MarketplaceService.ProcessReceipt = MonetizationService.processReceipt

	-- snapshot() asks us which passes a player owns
	PlayerDataService.passProvider = passesFor

	local function onPlayerAdded(player: Player)
		ownedPasses[player] = {}
		task.spawn(function()
			refreshPasses(player)
			if player.Parent == nil then
				return
			end
			PlayerDataService.sync(player)
			if MonetizationService.ownsPass(player, "VIP") then
				vipWelcome(player)
			end
			if next(ownedPasses[player] or {}) and MonetizationService.onPassesChanged then
				MonetizationService.onPassesChanged(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		ownedPasses[player] = nil
	end)
end

return MonetizationService
