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

-- magic word -> Sparkle Coins (doc 09: small and safe, no power)
local CODES: { [string]: number } = {
	SPLOINK = 150,
	THUP = 150,
	PMF = 200,
	EVERYSQUISH = 250,
	LOSTSPARKLE = 300,
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
		toastEvent:FireClient(player, "Hmm, that's not a magic word... check The Lost Sparkle storybook!")
		return
	end
	if PlayerDataService.hasRedeemedCode(player, code) then
		toastEvent:FireClient(player, "You've already used that magic word! ✨")
		return
	end

	PlayerDataService.markCodeRedeemed(player, code)
	PlayerDataService.addCoins(player, reward)
	toastEvent:FireClient(player, "✨ " .. code .. " is a magic word!  +" .. reward .. " Sparkle Coins!")
	PlayerDataService.sync(player)
end

function CodeService.init()
	toastEvent = Remotes.get(Remotes.Toast)
	Remotes.get(Remotes.RedeemCode).OnServerEvent:Connect(onRedeem)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastTry[player] = nil
	end)
end

return CodeService
