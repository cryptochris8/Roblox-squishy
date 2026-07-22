--!strict
-- CodeService (SERVER)
-- Storybook "magic words": promo codes from The Lost Sparkle book (and future
-- toys/cards) redeemable ONCE per player for a small, safe Sparkle Coin gift.
-- The code table lives server-side only, so curious kids can't peek the list
-- from the client — they have to find the words in the book, which is the point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local CodeService = {}

-- Wired by Main so a code-granted cosmetic can appear on the buddy right away.
CodeService.onCosmeticGranted = nil :: ((player: Player) -> ())?

-- A magic word grants a small, safe Sparkle Coin gift (doc 09: small, no power),
-- and OPTIONALLY a cosmetic. The table lives server-side only, so kids have to
-- find the words in the books / videos — which is the whole point, and lets each
-- channel's word double as an attribution counter (redemptions persist per code).
type CodeReward = { coins: number, cosmetic: string? }
local CODES: { [string]: CodeReward } = {
	-- Storybook words (printed in the picture books). The two BOOK words each
	-- grant the exclusive Storybook Halo — a keepsake you can't get any other way.
	SPLOINK = { coins = 150 },
	THUP = { coins = 150 },
	PMF = { coins = 200 },
	EVERYSQUISH = { coins = 250 },
	LOSTSPARKLE = { coins = 300, cosmetic = "hat_storybook_halo" }, -- Book 2 "The Lost Sparkle"
	MEETTHESQUISHIES = { coins = 300, cosmetic = "hat_storybook_halo" }, -- Book 1 "Meet the Squishies"
	-- Channel words (end-cards on the videos) — coins only; redemptions per code
	-- tell us which channel actually drives real plays.
	TIKTOK = { coins = 250 },
	SHORTS = { coins = 250 },
	YOUTUBE = { coins = 250 },
	DISCORD = { coins = 250 },
	SPARKLE = { coins = 200 },
}

local toastEvent: RemoteEvent
local lastTry: { [Player]: number } = {}

local function onRedeem(player: Player, text: any)
	if type(text) ~= "string" then
		return
	end
	-- gentle anti-mash: one guess per second
	local now = os.clock()
	if now - (lastTry[player] or 0) < 1 then
		return
	end
	lastTry[player] = now
	if not PlayerDataService.isReady(player) then
		return
	end

	-- forgiving normalize: trim, drop inner spaces, uppercase ("sploink " works)
	local code = string.upper((string.gsub(text, "%s+", "")))
	if #code == 0 or #code > 24 then
		return
	end

	local reward = CODES[code]
	if not reward then
		toastEvent:FireClient(player, "Hmm, that's not a magic word... check a Squishy storybook!")
		return
	end
	if PlayerDataService.hasRedeemedCode(player, code) then
		toastEvent:FireClient(player, "You've already used that magic word! ✨")
		return
	end

	PlayerDataService.markCodeRedeemed(player, code)
	PlayerDataService.addCoins(player, reward.coins)

	-- A book word can also grant its keepsake cosmetic — auto-wear it on the
	-- hat slot (the premium/crown pattern), then refresh the buddy so it shows.
	local gotCosmetic = false
	if reward.cosmetic and not PlayerDataService.ownsCosmetic(player, reward.cosmetic) then
		PlayerDataService.grantCosmetic(player, reward.cosmetic)
		PlayerDataService.setEquippedCosmetic(player, "hat", reward.cosmetic)
		gotCosmetic = true
	end

	if gotCosmetic then
		toastEvent:FireClient(
			player,
			"📖 " .. code .. " is a magic word!  +" .. reward.coins .. " Sparkle Coins + the Storybook Halo!",
			"celebration"
		)
	else
		toastEvent:FireClient(player, "✨ " .. code .. " is a magic word!  +" .. reward.coins .. " Sparkle Coins!")
	end
	PlayerDataService.sync(player)
	if gotCosmetic and CodeService.onCosmeticGranted then
		CodeService.onCosmeticGranted(player)
	end
end

function CodeService.init()
	toastEvent = Remotes.get(Remotes.Toast)
	Remotes.get(Remotes.RedeemCode).OnServerEvent:Connect(onRedeem)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastTry[player] = nil
	end)
end

return CodeService
