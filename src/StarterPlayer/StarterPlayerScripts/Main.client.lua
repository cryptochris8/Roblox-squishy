--!strict
-- Main (CLIENT ENTRY POINT) -- aiming + throw power
-- Runs on each player's device. HOLD the mouse button (or finger) to charge a
-- power bar, RELEASE to throw a football toward where you're aiming. The client
-- only sends the aim DIRECTION and the power (0..1); the server simulates the
-- arc and decides what gets hit. Score/timer display lives in Hud.client.lua.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local localPlayer = Players.LocalPlayer
print("[QB1 Client] Started for " .. localPlayer.Name)

local throwRequest = Remotes.get(Remotes.ThrowRequest)

-- ---------------------------------------------------------------------------
-- A power bar at the bottom of the screen, shown only while charging a throw.
-- ---------------------------------------------------------------------------
local playerGui = localPlayer:WaitForChild("PlayerGui")

local powerGui = Instance.new("ScreenGui")
powerGui.Name = "QB1PowerBar"
powerGui.ResetOnSpawn = false
powerGui.Parent = playerGui

local powerBack = Instance.new("Frame")
powerBack.Name = "PowerBack"
powerBack.AnchorPoint = Vector2.new(0.5, 1)
powerBack.Position = UDim2.new(0.5, 0, 1, -44)
powerBack.Size = UDim2.fromOffset(240, 16)
powerBack.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
powerBack.BackgroundTransparency = 0.25
powerBack.BorderSizePixel = 0
powerBack.Visible = false
powerBack.Parent = powerGui

local backCorner = Instance.new("UICorner")
backCorner.CornerRadius = UDim.new(1, 0)
backCorner.Parent = powerBack

local powerFill = Instance.new("Frame")
powerFill.Name = "PowerFill"
powerFill.AnchorPoint = Vector2.new(0, 0.5)
powerFill.Position = UDim2.new(0, 2, 0.5, 0)
powerFill.Size = UDim2.new(0, 0, 1, -4)
powerFill.BackgroundColor3 = Color3.fromRGB(90, 230, 110)
powerFill.BorderSizePixel = 0
powerFill.Parent = powerBack

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = powerFill

-- ---------------------------------------------------------------------------
-- Charging state
-- ---------------------------------------------------------------------------
local charging = false
local chargeStart = 0

-- 0..1, how full the charge is right now (purely time based).
local function chargeFraction(): number
	return math.clamp((os.clock() - chargeStart) / GameConfig.MaxChargeTime, 0, 1)
end

-- The power we actually send. A quick tap still has MinPowerFrac so it isn't a dud.
local function throwPower(): number
	return GameConfig.MinPowerFrac + chargeFraction() * (1 - GameConfig.MinPowerFrac)
end

-- Aim direction = the camera ray through the cursor/finger (already a unit vector).
-- ScreenPointToRay matches the coordinate space of UserInputService positions.
local function aimDirection(screenX: number, screenY: number): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	return camera:ScreenPointToRay(screenX, screenY).Direction
end

local function isThrowInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

-- Press = start charging.
UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed or not isThrowInput(input) then
		return -- click was used by UI, or it's not a throw input
	end
	charging = true
	chargeStart = os.clock()
end)

-- Release = throw with however much we charged.
UserInputService.InputEnded:Connect(function(input: InputObject, _gameProcessed: boolean)
	if not charging or not isThrowInput(input) then
		return
	end
	charging = false
	powerBack.Visible = false

	local pos = input.Position
	local dir = aimDirection(pos.X, pos.Y)
	if dir then
		throwRequest:FireServer(dir, throwPower())
	end
end)

-- Grow the power bar while charging.
RunService.RenderStepped:Connect(function()
	if charging then
		powerBack.Visible = true
		powerFill.Size = UDim2.new(chargeFraction(), -4, 1, -4)
	end
end)
