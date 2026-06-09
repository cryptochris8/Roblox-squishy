--!strict
-- Main (SERVER ENTRY POINT)
-- Wires Squishy Smash together in the right order and starts Pudding Hills.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- 3) Initialize player data + the systems that need remotes ready.
PlayerDataService.init()
CapsuleService.init()
CollectionService.init()
TutorialService.init()
BuddyService.init()
SparkleBitService.init()
DailyService.init()

-- 4) Build all the lands, then spawn each land's sleepy friends on its pads.
local world = WorldService.build()
QuestService.init()

local zoneGroups = {}
for _, z in ipairs(world.zones) do
	zoneGroups[#zoneGroups + 1] = { zone = z.zone, packId = z.packId, pads = z.pads }
end
SquishService.init(zoneGroups)

-- 5) Wire the world up.
-- A Happy Pop nudges the tutorial + the land's shard quest along.
SquishService.onHappyPop = function(player, def)
	TutorialService.notePop(player, def)
	QuestService.notePop(player, def)
	DailyService.noteEvent(player, "pop")
end

-- Equipping/unequipping a buddy spawns or removes the floating companion.
CollectionService.onBuddyChanged = function(player, defId)
	BuddyService.setBuddy(player, defId)
end

-- Daily-quest tracking: a capsule open (and any new discovery), and Sparkle Bits.
CapsuleService.onOpened = function(player, isNew)
	DailyService.noteEvent(player, "capsule")
	if isNew then
		DailyService.noteEvent(player, "discover")
	end
end
SparkleBitService.onCollected = function(player)
	DailyService.noteEvent(player, "bit")
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
end

-- 6) When a client says it's ready, send its state + a warm welcome.
local requestState = Remotes.get(Remotes.RequestInitialState)
requestState.OnServerEvent:Connect(function(player)
	DailyService.onJoin(player)
	PlayerDataService.sync(player)
	TutorialService.welcome(player)
	QuestService.checkReveal(player)
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
