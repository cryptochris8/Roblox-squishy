--!strict
-- Main (SERVER ENTRY POINT)
-- This is a Script (note the ".server" in the file name), so Roblox runs it
-- automatically when the game starts. Its job is to wire everything together
-- in the right order and start the round loop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

-- STEP 1: create the RemoteEvents FIRST, before anything tries to use them.
Remotes.setupServer()

-- STEP 2: load the server services (they live next to this script).
local ScoreService = require(script.Parent.ScoreService)
local RoundService = require(script.Parent.RoundService)
local TargetService = require(script.Parent.TargetService)
local ThrowService = require(script.Parent.ThrowService)

-- STEP 3: start tracking scores, create the target folder, and wire up throwing.
ScoreService.init()
TargetService.init()
ThrowService.init({ score = ScoreService, targets = TargetService })

-- STEP 4: handle throw requests from clients.
-- The client ASKS to throw, sending the aim DIRECTION and a POWER (0..1); the
-- SERVER decides what happens. We validate before doing anything:
--   1. a round is actually active,
--   2. the aim is a real Vector3 and the power a real number -- never trust the
--      client, so we normalize the direction and clamp the power ourselves, and
--   3. the player is off cooldown (the client controls how OFTEN it fires, so
--      the server -- not the mouse -- sets the pace).
-- ThrowService then simulates the whole arc on the server and detects the hit,
-- so a hit can't be faked.
local throwRequest = Remotes.get(Remotes.ThrowRequest)
local lastThrow: { [Player]: number } = {}

throwRequest.OnServerEvent:Connect(function(player: Player, aimDir: any, power: any)
	if not RoundService.isActive() then
		return
	end
	if typeof(aimDir) ~= "Vector3" then
		return -- malformed / spoofed aim, ignore
	end
	-- Reject non-finite aim too: a NaN/inf Vector3 sneaks past a plain magnitude
	-- check because EVERY comparison with NaN is false. (`mag ~= mag` is the
	-- standard NaN test; `math.huge` is infinity.)
	local mag = aimDir.Magnitude
	if mag ~= mag or mag == math.huge or mag < 0.001 then
		return
	end
	if typeof(power) ~= "number" or power ~= power then
		return -- malformed / spoofed power (incl. NaN), ignore
	end

	local now = os.clock()
	if now - (lastThrow[player] or 0) < GameConfig.ThrowCooldown then
		return -- too soon since the last throw; ignore (anti-spam)
	end
	lastThrow[player] = now

	ThrowService.throwBall(player, aimDir, math.clamp(power, 0, 1))
end)

-- Forget a player's cooldown when they leave so the table never grows forever.
Players.PlayerRemoving:Connect(function(player: Player)
	lastThrow[player] = nil
end)

-- STEP 5: start the round heartbeat. Targets appear when a round goes Active
-- and are cleared when it ends.
RoundService.start(ScoreService, {
	onActiveStart = function()
		TargetService.spawnTargets()
	end,
	onRoundEnd = function()
		TargetService.clearTargets()
	end,
})

print("[QB1 Server] Started. Round loop is running.")
