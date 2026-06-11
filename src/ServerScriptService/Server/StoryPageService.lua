--!strict
-- StoryPageService (SERVER)
-- Validates hidden storybook-page pickups (the client renders each player's
-- unfound pages and notices the walk-up, same trusted pattern as Sparkle
-- Bits): page must be real, not already found, and the character genuinely
-- near it. Awards coins, persists, and celebrates the full set.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local StoryPageConfig = require(Shared:WaitForChild("StoryPageConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local StoryPageService = {}

local collectedEvent: RemoteEvent
local toastEvent: RemoteEvent
local CLAIM_RANGE = 18

local function onCollect(player: Player, id: any)
	if type(id) ~= "string" then
		return
	end
	local page = StoryPageConfig.get(id)
	if not page then
		return
	end
	if not PlayerDataService.isReady(player) then
		return
	end
	local profile = PlayerDataService.get(player)
	if not profile or profile.StoryPages[id] then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	if (root.Position - page.position).Magnitude > CLAIM_RANGE then
		return
	end

	profile.StoryPages[id] = true
	PlayerDataService.addCoins(player, StoryPageConfig.PageCoins)
	local count = 0
	for _ in pairs(profile.StoryPages) do
		count += 1
	end
	local total = StoryPageConfig.count()
	local all = count >= total
	local bonus = 0
	if all then
		bonus = StoryPageConfig.AllBonus
		PlayerDataService.addCoins(player, bonus)
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				toastEvent:FireClient(other, "📖 " .. player.DisplayName .. " found EVERY page of The Lost Sparkle storybook!")
			end
		end
	end

	collectedEvent:FireClient(player, {
		id = id,
		n = page.n,
		count = count,
		total = total,
		coins = StoryPageConfig.PageCoins,
		all = all,
		bonus = bonus,
	})
	PlayerDataService.sync(player)
end

function StoryPageService.init()
	collectedEvent = Remotes.get(Remotes.StoryPageCollected)
	toastEvent = Remotes.get(Remotes.Toast)
	Remotes.get(Remotes.CollectStoryPage).OnServerEvent:Connect(onCollect)
end

return StoryPageService
