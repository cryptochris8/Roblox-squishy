--!strict
-- Main (SERVER ENTRY POINT)
-- Wires Squishy Smash together in the right order and starts Pudding Hills.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

-- 1) Create the RemoteEvents first, before anything tries to use them.
Remotes.setupServer()

-- 2) Load the services (they live next to this script).
local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldService = require(script.Parent.WorldService)
local SquishService = require(script.Parent.SquishService)
local CapsuleService = require(script.Parent.CapsuleService)
local CollectionService = require(script.Parent.CollectionService)
local TutorialService = require(script.Parent.TutorialService)
local BuddyService = require(script.Parent.BuddyService)
local QuestService = require(script.Parent.QuestService)
local SparkleBitService = require(script.Parent.SparkleBitService)
local DailyService = require(script.Parent.DailyService)
local TravelService = require(script.Parent.TravelService)
local FinaleService = require(script.Parent.FinaleService)
local SurgeService = require(script.Parent.SurgeService)
local GroupEventService = require(script.Parent.GroupEventService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local BoutiqueService = require(script.Parent.BoutiqueService)

-- 3) Initialize player data + the systems that need remotes ready.
PlayerDataService.init()
CapsuleService.init()
CollectionService.init()
TutorialService.init()
BuddyService.init()
SparkleBitService.init()
DailyService.init()
TravelService.init()
FinaleService.init()
SurgeService.init()
GroupEventService.init()
LeaderboardService.init()
BoutiqueService.init()

-- 4) Build all the lands, then spawn each land's sleepy friends on its pads.
local world = WorldService.build()
QuestService.init()

local zoneGroups = {}
for _, z in ipairs(world.zones) do
	zoneGroups[#zoneGroups + 1] = { zone = z.zone, packId = z.packId, pads = z.pads }
end
SquishService.init(zoneGroups)

-- 5) Wire the world up.
-- A friendly note to everyone EXCEPT the player it's about (they get their own).
local toastEvent = Remotes.get(Remotes.Toast)
local function shoutToOthers(player: Player, message: string)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			toastEvent:FireClient(other, message)
		end
	end
end

-- A Happy Pop nudges the tutorial + the land's shard quest along, and feeds the
-- server-wide Sparkle Surge meter.
SquishService.onHappyPop = function(player, def)
	TutorialService.notePop(player, def)
	QuestService.notePop(player, def)
	DailyService.noteEvent(player, "pop")
	SurgeService.notePop(player, def)
end

-- During a Sparkle Surge, every coin award doubles.
SquishService.coinMultiplier = SurgeService.coinMultiplier

-- Golden friends belong to the "Everybody Squish!" event.
SquishService.onGoldenPop = function(player, def, model)
	GroupEventService.noteGoldenPop(player, def, model)
end

-- Equipping/unequipping a buddy spawns or removes the floating companion.
CollectionService.onBuddyChanged = function(player, defId)
	BuddyService.setBuddy(player, defId)
end

-- Boutique purchases/outfit changes re-dress the buddy on the spot.
BoutiqueService.onCosmeticsChanged = function(player)
	local profile = PlayerDataService.get(player)
	if profile and profile.EquippedBuddyId then
		BuddyService.setBuddy(player, profile.EquippedBuddyId)
	end
end

-- Daily-quest tracking: a capsule open (and any new discovery), and Sparkle Bits.
-- A NEW discovery is also a show-off moment for the rest of the server.
CapsuleService.onOpened = function(player, isNew, def)
	DailyService.noteEvent(player, "capsule")
	if isNew then
		DailyService.noteEvent(player, "discover")
		if def then
			shoutToOthers(player, "🎉 " .. player.DisplayName .. " discovered " .. def.DisplayName .. "!")
		end
	elseif def then
		-- A duplicate may have shined up the friend they have equipped — respawn
		-- the buddy so its ✨/🌈 badge and aura update right away.
		local profile = PlayerDataService.get(player)
		if profile and profile.EquippedBuddyId == def.Id then
			BuddyService.setBuddy(player, def.Id)
		end
	end
end
SparkleBitService.onCollected = function(player)
	DailyService.noteEvent(player, "bit")
end

-- Recovering a land's shard is server news too.
QuestService.onShardRecovered = function(player, zoneName)
	shoutToOthers(player, "✨ " .. player.DisplayName .. " recovered the " .. zoneName .. " Sparkle Shard!")
end

-- Recovering all three Sparkle shards restores the Sparkle (the finale).
QuestService.onAllShardsRecovered = function(player)
	FinaleService.celebrate(player)
end

-- Each land's Sparkle Capsule (draws from that land's pack) + guide (gives that
-- land's shard clue).
for _, z in ipairs(world.zones) do
	if z.capsulePrompt then
		z.capsulePrompt.Triggered:Connect(function(player)
			CapsuleService.tryOpen(player, z.capsuleKey)
		end)
	end
	if z.guidePrompt then
		z.guidePrompt.Triggered:Connect(function(player)
			QuestService.giveClue(player, z.zone)
		end)
	end
	for _, tp in ipairs(z.travelPads or {}) do
		tp.prompt.Triggered:Connect(function(player)
			TravelService.travel(player, tp.destZone)
		end)
	end
end

-- 6) When a client says it's ready, send its state + a warm welcome.
local requestState = Remotes.get(Remotes.RequestInitialState)
requestState.OnServerEvent:Connect(function(player)
	DailyService.onJoin(player)
	PlayerDataService.sync(player)
	TutorialService.welcome(player)
	QuestService.checkReveal(player)
	SurgeService.syncTo(player)
	GroupEventService.syncTo(player)
end)

-- Owner-only playtest triggers, so you can demo the shared-world moments to the
-- kids on cue instead of waiting for the timers. Same double-gate as Reset.
local ownerDebug = Remotes.get(Remotes.OwnerDebug)
ownerDebug.OnServerEvent:Connect(function(player, action)
	if game.CreatorType ~= Enum.CreatorType.User or player.UserId ~= game.CreatorId then
		return
	end
	if action == "startEvent" then
		GroupEventService.startNow()
	elseif action == "startSurge" then
		SurgeService.startNow()
	end
end)

-- Owner-only "Reset My Progress" playtest tool. Double-gated to the place owner so
-- the kids can NEVER wipe their own progress; resets the profile (the fresh save
-- lands on the rejoin kick) and sends them back for a clean first-time run.
local resetProgress = Remotes.get(Remotes.ResetProgress)
resetProgress.OnServerEvent:Connect(function(player)
	if game.CreatorType ~= Enum.CreatorType.User or player.UserId ~= game.CreatorId then
		return
	end
	PlayerDataService.resetProfile(player)
	task.wait(0.15)
	player:Kick("✨ Progress reset — rejoin to start fresh from the beginning!")
end)

print("[Squishy Smash] Server ready — welcome to Pudding Hills!")
