--!strict
-- PlayerDataService (SERVER)
-- The single owner of each player's progress: Sparkle Coins, discovered friends,
-- totals, equipped buddy, and tutorial state. Everything is server-side and
-- validated. (MVP keeps this in memory; DataStore save/load drops in later.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerDataService = {}

export type Profile = {
	SparkleCoins: number,
	TotalSquishes: number,
	TotalHappyPops: number,
	Discovered: { [string]: boolean },
	DiscoveredCount: number,
	EquippedBuddyId: string?,
	TutorialDone: boolean,
	FirstCapsuleClaimed: boolean,
}

local profiles: { [Player]: Profile } = {}
local stateSyncEvent: RemoteEvent

local function newProfile(): Profile
	return {
		SparkleCoins = GameConfig.StartingSparkleCoins,
		TotalSquishes = 0,
		TotalHappyPops = 0,
		Discovered = {},
		DiscoveredCount = 0,
		EquippedBuddyId = nil,
		TutorialDone = false,
		FirstCapsuleClaimed = false,
	}
end

-- A friendly leaderboard so kids see their Sparkle Coins, friends, and pops.
local function setupLeaderstats(player: Player, profile: Profile)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Sparkle Coins"
	coins.Value = profile.SparkleCoins
	coins.Parent = stats
	local discovered = Instance.new("IntValue")
	discovered.Name = "Friends"
	discovered.Value = profile.DiscoveredCount
	discovered.Parent = stats
	local pops = Instance.new("IntValue")
	pops.Name = "Happy Pops"
	pops.Value = profile.TotalHappyPops
	pops.Parent = stats
	stats.Parent = player
end

local function refreshLeaderstats(player: Player, profile: Profile)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local coins = stats:FindFirstChild("Sparkle Coins") :: IntValue?
	if coins then coins.Value = profile.SparkleCoins end
	local discovered = stats:FindFirstChild("Friends") :: IntValue?
	if discovered then discovered.Value = profile.DiscoveredCount end
	local pops = stats:FindFirstChild("Happy Pops") :: IntValue?
	if pops then pops.Value = profile.TotalHappyPops end
end

function PlayerDataService.get(player: Player): Profile?
	return profiles[player]
end

-- Build the snapshot the client needs to draw the HUD + Squishy Book.
function PlayerDataService.snapshot(player: Player)
	local p = profiles[player]
	if not p then
		return nil
	end
	return {
		coins = p.SparkleCoins,
		totalSquishes = p.TotalSquishes,
		totalHappyPops = p.TotalHappyPops,
		discovered = p.Discovered,
		discoveredCount = p.DiscoveredCount,
		equippedBuddyId = p.EquippedBuddyId,
		zone = GameConfig.ZoneName,
		tutorial = {
			popped = math.min(p.TotalHappyPops, GameConfig.TutorialPopGoal),
			goal = GameConfig.TutorialPopGoal,
			done = p.TutorialDone,
			firstCapsuleClaimed = p.FirstCapsuleClaimed,
		},
	}
end

function PlayerDataService.sync(player: Player)
	local snap = PlayerDataService.snapshot(player)
	if snap then
		stateSyncEvent:FireClient(player, snap)
	end
end

function PlayerDataService.addCoins(player: Player, amount: number)
	local p = profiles[player]
	if not p then return end
	p.SparkleCoins += amount
	refreshLeaderstats(player, p)
end

-- Returns true if the player could afford it (and were charged).
function PlayerDataService.spendCoins(player: Player, amount: number): boolean
	local p = profiles[player]
	if not p or p.SparkleCoins < amount then
		return false
	end
	p.SparkleCoins -= amount
	refreshLeaderstats(player, p)
	return true
end

function PlayerDataService.getCoins(player: Player): number
	local p = profiles[player]
	return p and p.SparkleCoins or 0
end

function PlayerDataService.incSquish(player: Player)
	local p = profiles[player]
	if not p then return end
	p.TotalSquishes += 1
end

function PlayerDataService.incHappyPop(player: Player)
	local p = profiles[player]
	if not p then return end
	p.TotalHappyPops += 1
	refreshLeaderstats(player, p)
end

-- Returns true if this friend was NEWLY discovered.
function PlayerDataService.discoverCard(player: Player, defId: string): boolean
	local p = profiles[player]
	if not p or p.Discovered[defId] then
		return false
	end
	p.Discovered[defId] = true
	p.DiscoveredCount += 1
	refreshLeaderstats(player, p)
	return true
end

function PlayerDataService.hasDiscovered(player: Player, defId: string): boolean
	local p = profiles[player]
	return (p ~= nil) and (p.Discovered[defId] == true)
end

function PlayerDataService.setBuddy(player: Player, defId: string)
	local p = profiles[player]
	if not p then return end
	p.EquippedBuddyId = defId
end

function PlayerDataService.setTutorialDone(player: Player)
	local p = profiles[player]
	if not p then return end
	p.TutorialDone = true
end

function PlayerDataService.isFirstCapsuleClaimed(player: Player): boolean
	local p = profiles[player]
	return (p ~= nil) and (p.FirstCapsuleClaimed == true)
end

function PlayerDataService.markFirstCapsuleClaimed(player: Player)
	local p = profiles[player]
	if not p then return end
	p.FirstCapsuleClaimed = true
end

function PlayerDataService.init()
	stateSyncEvent = Remotes.get(Remotes.StateSync)

	local function onAdded(player: Player)
		local profile = newProfile()
		profiles[player] = profile
		setupLeaderstats(player, profile)
	end

	Players.PlayerAdded:Connect(onAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
	end)
end

return PlayerDataService
