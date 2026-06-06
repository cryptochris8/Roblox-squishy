--!strict
-- Main (CLIENT ENTRY POINT)
-- This is a LocalScript (note the ".client" in the file name), so it runs on
-- each player's own device. For this first prototype it just listens to the
-- server and prints what's happening to the Output window. Real on-screen UI
-- is the next build step.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local localPlayer = Players.LocalPlayer
print("[QB1 Client] Started for " .. localPlayer.Name)

-- Grab the RemoteEvents (waits until the server has made them).
local roundUpdate = Remotes.get(Remotes.RoundUpdate)
local scoreUpdate = Remotes.get(Remotes.ScoreUpdate)
local throwRequest = Remotes.get(Remotes.ThrowRequest)

-- The server tells us the round state every second.
roundUpdate.OnClientEvent:Connect(function(state: string, timeLeft: number, roundNumber: number)
	print(string.format("[QB1 Round] #%d | %s | %ds left", roundNumber, state, timeLeft))
end)

-- The server tells us our score whenever it changes.
scoreUpdate.OnClientEvent:Connect(function(score: number)
	print("[QB1 Score] Your score is now " .. score)
end)

-- Temporary input: left-click (or tap on mobile) asks the server for a point.
-- This stands in for "throwing a ball" until we build the real mechanic.
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return -- the click was used by the UI / chat, ignore it
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		throwRequest:FireServer()
	end
end)
