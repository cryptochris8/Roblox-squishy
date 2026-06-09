--!strict
-- GroupEventService (SERVER)
-- "Everybody Squish!" — every few minutes, GOLDEN sleepy friends appear at the
-- land where the most players are. Everyone's golden Happy Pops count toward ONE
-- shared goal (scaled by how many friends are online); reach it before the golden
-- friends nap again and EVERY friend online gets a Sparkle Coin gift. The co-op
-- heart of the shared world — solo-completable, better together.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local SocialConfig = require(Shared:WaitForChild("SocialConfig"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)
local SquishService = require(script.Parent.SquishService)

local GroupEventService = {}

local socialSyncEvent: RemoteEvent
local toastEvent: RemoteEvent
local rng = Random.new()

local active = false
local eventZone: string? = nil
local progress = 0
local eventGoal = 0
local endsAt = 0
local eventToken = 0 -- bumps every start/stop so a stale timeout can't end a new event
local goldenModels: { Model } = {}

function GroupEventService.snapshot()
	return {
		active = active,
		zone = eventZone,
		progress = progress,
		goal = eventGoal,
		remaining = math.max(0, endsAt - os.clock()),
	}
end

local function broadcast()
	socialSyncEvent:FireAllClients({ event = GroupEventService.snapshot() })
end

function GroupEventService.syncTo(player: Player)
	socialSyncEvent:FireClient(player, { event = GroupEventService.snapshot() })
end

-- The land where the most players are right now (ties go to the earlier land in
-- the story order; no characters anywhere defaults to Pudding Hills). Lands sit
-- along the X axis, so "nearest center" is a simple distance check.
local function busiestZone(): string
	local counts: { [string]: number } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local pos = char and char.PrimaryPart and char.PrimaryPart.Position
		if pos then
			local bestName, bestDist = nil, math.huge
			for _, zone in ipairs(ZoneConfig.ordered()) do
				local d = (pos - zone.center).Magnitude
				if d < bestDist then
					bestName, bestDist = zone.name, d
				end
			end
			if bestName then
				counts[bestName] = (counts[bestName] or 0) + 1
			end
		end
	end
	local winner, winnerCount = "Pudding Hills", -1
	for _, name in ipairs(ZoneConfig.Order) do
		if (counts[name] or 0) > winnerCount then
			winner, winnerCount = name, counts[name] or 0
		end
	end
	return winner
end

local function cleanupGoldenFriends()
	for _, model in ipairs(goldenModels) do
		-- A friend mid-Happy-Pop cleans itself up after its celebration plays out;
		-- destroying it now would cut the pop FX short.
		if model.Parent and model:GetAttribute("Popped") ~= true then
			model:Destroy()
		end
	end
	goldenModels = {}
end

local function endEvent(succeeded: boolean)
	if not active then
		return
	end
	active = false
	eventToken += 1
	cleanupGoldenFriends()

	if succeeded then
		for _, player in ipairs(Players:GetPlayers()) do
			PlayerDataService.addCoins(player, SocialConfig.EventRewardCoins)
			PlayerDataService.sync(player)
		end
		toastEvent:FireAllClients("🎉 You did it together! Everyone gets +" .. SocialConfig.EventRewardCoins .. " Sparkle Coins! 🎉")
	else
		toastEvent:FireAllClients("💤 The golden friends drifted back to sleep... they'll visit again soon!")
	end
	broadcast()
end

-- Starts an "Everybody Squish!" right now (the timer's job; also an owner
-- playtest trigger). Quietly does nothing if one is already running.
function GroupEventService.startNow()
	if active then
		return
	end
	local playerCount = #Players:GetPlayers()
	if playerCount == 0 then
		return
	end

	local zoneName = busiestZone()
	local zone = ZoneConfig.get(zoneName)
	if not zone then
		return
	end

	eventZone = zoneName
	eventGoal = math.clamp(playerCount * SocialConfig.EventGoalPerPlayer, SocialConfig.EventGoalMin, SocialConfig.EventGoalMax)
	progress = 0
	endsAt = os.clock() + SocialConfig.EventDurationSeconds
	active = true
	eventToken += 1
	local myToken = eventToken

	-- Scatter the golden friends around the land's heart — a couple more than the
	-- goal needs, so nobody is hunting for the very last one.
	local spawnCount = eventGoal + SocialConfig.EventSpawnExtra
	for _ = 1, spawnCount do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(14, 42)
		local pos = zone.center + Vector3.new(math.cos(angle) * radius, 2, math.sin(angle) * radius)
		local model = SquishService.spawnGolden(zone.packId, CFrame.new(pos))
		goldenModels[#goldenModels + 1] = model
	end

	toastEvent:FireAllClients("🌟 EVERYBODY SQUISH! Golden friends woke up at " .. zoneName .. " — wake " .. eventGoal .. " of them together!")
	broadcast()

	task.delay(SocialConfig.EventDurationSeconds, function()
		if active and eventToken == myToken then
			endEvent(false)
		end
	end)
end

-- Called (via Main) whenever any player Happy Pops a golden friend.
function GroupEventService.noteGoldenPop(_player: Player, _def: any, _model: Model)
	if not active then
		return
	end
	progress += 1
	if progress >= eventGoal then
		endEvent(true)
	else
		broadcast()
	end
end

function GroupEventService.init()
	socialSyncEvent = Remotes.get(Remotes.SocialSync)
	toastEvent = Remotes.get(Remotes.Toast)

	task.spawn(function()
		task.wait(SocialConfig.EventFirstDelaySeconds)
		while true do
			if not active and #Players:GetPlayers() > 0 then
				GroupEventService.startNow()
			end
			task.wait(SocialConfig.EventIntervalSeconds)
		end
	end)
end

return GroupEventService
