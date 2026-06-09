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

-- 3) Initialize player data + the systems that need remotes ready.
PlayerDataService.init()
CapsuleService.init()
CollectionService.init()
TutorialService.init()
BuddyService.init()
SparkleBitService.init()

-- 4) Build the cozy Pudding Hills world, then spawn the sleepy friends on it.
local world = WorldService.build()
SquishService.init(world.pads)
QuestService.init(world)

-- 5) Wire the world up.
-- A Happy Pop nudges the tutorial along.
SquishService.onHappyPop = function(player, def)
	TutorialService.notePop(player, def)
	QuestService.notePop(player, def)
end

-- Equipping/unequipping a buddy spawns or removes the floating companion.
CollectionService.onBuddyChanged = function(player, defId)
	BuddyService.setBuddy(player, defId)
end

-- The Sparkle Capsule machine opens a capsule for whoever uses it.
world.capsulePrompt.Triggered:Connect(function(player)
	CapsuleService.tryOpen(player)
end)

-- Soft Dumpling gives the Lost Shard clue when talked to.
world.guidePrompt.Triggered:Connect(function(player)
	QuestService.giveClue(player)
end)

-- 6) When a client says it's ready, send its state + a warm welcome.
local requestState = Remotes.get(Remotes.RequestInitialState)
requestState.OnServerEvent:Connect(function(player)
	PlayerDataService.sync(player)
	TutorialService.welcome(player)
	QuestService.checkReveal(player)
end)

print("[Squishy Smash] Server ready — welcome to Pudding Hills!")
