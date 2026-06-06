--!strict
-- ScoreService (SERVER)
-- The server is the only place scores are stored and changed. The client just
-- gets TOLD what its score is. This is what "server-authoritative" means and it
-- is how you stop cheaters from setting their own score.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local ScoreService = {}

-- scores[player] = number. The real data lives here, on the server only.
local scores: { [Player]: number } = {}

-- Filled in by ScoreService.init().
local scoreUpdateEvent: RemoteEvent

-- Give a player a fresh score of 0 and tell their client.
local function setupPlayer(player: Player)
	scores[player] = 0
	scoreUpdateEvent:FireClient(player, 0)
end

-- Call this once at server startup.
function ScoreService.init()
	scoreUpdateEvent = Remotes.get(Remotes.ScoreUpdate)

	-- Handle players who join later...
	Players.PlayerAdded:Connect(setupPlayer)

	-- ...and any players who are ALREADY here (important in Studio solo testing).
	for _, player in ipairs(Players:GetPlayers()) do
		setupPlayer(player)
	end

	-- Clean up when a player leaves so the table does not grow forever.
	Players.PlayerRemoving:Connect(function(player: Player)
		scores[player] = nil
	end)
end

-- Add points to a player and push the new total to their client.
function ScoreService.addScore(player: Player, amount: number)
	if scores[player] == nil then
		return -- unknown / left player, ignore safely
	end
	scores[player] += amount
	scoreUpdateEvent:FireClient(player, scores[player])
end

-- Read a player's current score (server-side helper).
-- Not called yet -- it's here for the upcoming leaderboard / end-of-round screen.
function ScoreService.getScore(player: Player): number
	return scores[player] or 0
end

-- Reset everyone to 0 (called at the start of each round).
function ScoreService.resetAll()
	for player in pairs(scores) do
		scores[player] = 0
		scoreUpdateEvent:FireClient(player, 0)
	end
end

return ScoreService
