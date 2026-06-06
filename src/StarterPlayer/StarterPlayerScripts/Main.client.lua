--!strict
-- Main (CLIENT ENTRY POINT)
-- This is a LocalScript (note the ".client" in the file name), so it runs on
-- each player's own device. Its job is INPUT: turn a click/tap into a throw
-- request for the server. The on-screen display lives in Hud.client.lua, and
-- the server stays in charge of whether a throw actually scores.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local localPlayer = Players.LocalPlayer
print("[QB1 Client] Started for " .. localPlayer.Name)

-- Grab the throw RemoteEvent (waits until the server has made it).
local throwRequest = Remotes.get(Remotes.ThrowRequest)

-- Left-click (or tap on mobile) asks the server for a point. This stands in for
-- "throwing a ball" until we build the real mechanic with targets.
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
