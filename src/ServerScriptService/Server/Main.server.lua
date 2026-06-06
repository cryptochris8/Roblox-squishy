--!strict
-- Main (SERVER ENTRY POINT)
-- This is a Script (note the ".server" in the file name), so Roblox runs it
-- automatically when the game starts. Its job is to wire everything together
-- in the right order and start the round loop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

-- STEP 1: create the RemoteEvents FIRST, before anything tries to use them.
Remotes.setupServer()

-- STEP 2: load the server services (they live next to this script).
local ScoreService = require(script.Parent.ScoreService)
local RoundService = require(script.Parent.RoundService)

-- STEP 3: start tracking scores.
ScoreService.init()

-- STEP 4: handle throw requests from clients.
-- The client can ASK to throw, but the SERVER decides if it counts. This is the
-- "client requests, server validates" rule. Right now a valid throw during an
-- active round simply scores a point -- the real ball + targets come next.
local throwRequest = Remotes.get(Remotes.ThrowRequest)
throwRequest.OnServerEvent:Connect(function(player: Player)
	if RoundService.isActive() then
		ScoreService.addScore(player, GameConfig.PointsPerHit)
	end
end)

-- STEP 5: start the round heartbeat.
RoundService.start(ScoreService)

print("[QB1 Server] Started. Round loop is running.")
