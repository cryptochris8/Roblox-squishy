--!strict
-- RoundService (SERVER)
-- Runs the game's heartbeat: Intermission -> Active round -> Round over -> repeat.
-- The server owns the clock. Every second it tells all clients the current
-- state and how much time is left, so every player's UI stays in sync.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local RoundService = {}

-- Public, readable state. Other server code (like Main) checks RoundService.isActive().
RoundService.State = "Waiting" -- "Waiting" | "Intermission" | "Active" | "RoundOver"
RoundService.TimeLeft = 0
RoundService.RoundNumber = 0

-- Filled in by RoundService.start().
local roundUpdateEvent: RemoteEvent

-- Tell every client the current round state.
local function broadcast()
	roundUpdateEvent:FireAllClients(
		RoundService.State,
		RoundService.TimeLeft,
		RoundService.RoundNumber
	)
end

-- Count down a timer one second at a time, broadcasting every tick.
local function countdown(seconds: number)
	RoundService.TimeLeft = seconds
	broadcast()
	while RoundService.TimeLeft > 0 do
		task.wait(1)
		RoundService.TimeLeft -= 1
		broadcast()
	end
end

-- True only while a round is actually being played.
function RoundService.isActive(): boolean
	return RoundService.State == "Active"
end

-- The slice of ScoreService that RoundService actually needs. Declaring it keeps
-- --!strict happy and documents the dependency without a hard require.
type ScoreServiceLike = {
	resetAll: () -> (),
}

-- Start the never-ending round loop. Pass in ScoreService so we can reset
-- scores at the start of each round.
function RoundService.start(scoreService: ScoreServiceLike)
	roundUpdateEvent = Remotes.get(Remotes.RoundUpdate)

	task.spawn(function()
		while true do
			-- 1) Intermission (breather between rounds)
			RoundService.State = "Intermission"
			countdown(GameConfig.IntermissionDuration)

			-- 2) Active round
			RoundService.RoundNumber += 1
			scoreService.resetAll()
			RoundService.State = "Active"
			countdown(GameConfig.RoundDuration)

			-- 3) Round over (show results briefly)
			RoundService.State = "RoundOver"
			RoundService.TimeLeft = 0
			broadcast()
			task.wait(GameConfig.EndScreenDuration)
		end
	end)
end

return RoundService
