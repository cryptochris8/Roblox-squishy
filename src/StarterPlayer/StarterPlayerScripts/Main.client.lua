--!strict
-- Main (CLIENT ENTRY POINT)
-- This is a LocalScript (note the ".client" in the file name), so it runs on
-- each player's own device. Its job is INPUT: when you click/tap, work out WHERE
-- you aimed in the 3D world and ask the server to throw there. The server then
-- decides if it hit a target and scores. Display lives in Hud.client.lua.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local localPlayer = Players.LocalPlayer
print("[QB1 Client] Started for " .. localPlayer.Name)

-- Grab the throw RemoteEvent (waits until the server has made it).
local throwRequest = Remotes.get(Remotes.ThrowRequest)

-- Work out the 3D point under a screen position (mouse cursor or finger): shoot a
-- ray from the camera through that pixel and return whatever it hits. If it hits
-- nothing (open sky), return a point far down that ray.
local function aimPointFromScreen(screenX: number, screenY: number): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	-- ScreenPointToRay (not ViewportPointToRay): click positions from
	-- UserInputService include the top-bar GUI inset, and ScreenPointToRay uses
	-- that same coordinate space, so the aim lines up exactly with the cursor.
	local ray = camera:ScreenPointToRay(screenX, screenY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = localPlayer.Character
	params.FilterDescendantsInstances = character and { character } or {} -- ignore ourself

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if result then
		return result.Position
	end
	return ray.Origin + ray.Direction * 300
end

-- Left-click or tap = throw toward where you aimed.
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return -- the click was used by the UI / chat, ignore it
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		local aimPoint = aimPointFromScreen(input.Position.X, input.Position.Y)
		if aimPoint then
			throwRequest:FireServer(aimPoint)
		end
	end
end)
