--!strict
-- Hud (CLIENT)
-- Builds a simple on-screen HUD and keeps it updated from the server's round and
-- score events. It lives in StarterPlayerScripts so it runs ONCE per player and
-- survives respawns. (A script in StarterGui would re-run every time you respawn
-- and stack up duplicate HUDs.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Hide the default Roblox chat so it doesn't cover targets that float up near
-- the top-left of the screen. This is a focused single-screen arcade game; if
-- you want chat back later, just delete this block.
pcall(function()
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
end)

-- ---------------------------------------------------------------------------
-- Build the HUD (one tidy panel, top-center, so it never overlaps Roblox's own
-- menu / chat buttons in the corners).
-- ---------------------------------------------------------------------------

local screen = Instance.new("ScreenGui")
screen.Name = "QB1Hud"
screen.ResetOnSpawn = false -- keep the HUD when the character respawns
screen.IgnoreGuiInset = false -- sit just below Roblox's top bar
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "HudPanel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 12)
panel.Size = UDim2.fromOffset(280, 116)
panel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.Parent = screen

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = panel

-- Small helper so all three stacked labels are made the same way.
local function addLabel(name: string, yOffset: number, height: number, text: string, textSize: number, font: Enum.Font, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, 0, 0, yOffset)
	label.Size = UDim2.new(1, 0, 0, height)
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = color
	label.Text = text
	label.Parent = panel
	return label
end

local stateLabel = addLabel("StateLabel", 10, 24, "STARTING...", 20, Enum.Font.GothamBold, Color3.fromRGB(220, 220, 220))
local timerLabel = addLabel("TimerLabel", 34, 42, "0:00", 36, Enum.Font.GothamBlack, Color3.fromRGB(255, 255, 255))
local scoreLabel = addLabel("ScoreLabel", 80, 28, "Score: 0", 22, Enum.Font.GothamBold, Color3.fromRGB(120, 220, 255))

-- Bottom-center hint.
local hint = Instance.new("TextLabel")
hint.Name = "HintLabel"
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -18)
hint.Size = UDim2.new(0, 360, 0, 24)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.GothamMedium
hint.TextSize = 16
hint.TextColor3 = Color3.fromRGB(235, 235, 235)
hint.TextStrokeTransparency = 0.6
hint.Text = "Hold to charge power, release to throw at a target"
hint.Parent = screen

-- ---------------------------------------------------------------------------
-- Keep the HUD in sync with the server.
-- ---------------------------------------------------------------------------

-- Friendly text + color for each round state the server can send.
local STATE_TEXT: { [string]: string } = {
	Waiting = "STARTING...",
	Intermission = "GET READY",
	Active = "ROUND ACTIVE",
	RoundOver = "ROUND OVER",
}

local STATE_COLOR: { [string]: Color3 } = {
	Waiting = Color3.fromRGB(200, 200, 200),
	Intermission = Color3.fromRGB(255, 200, 60),
	Active = Color3.fromRGB(90, 230, 110),
	RoundOver = Color3.fromRGB(255, 110, 110),
}

-- Turn a number of seconds into "M:SS".
local function formatTime(totalSeconds: number): string
	local s = math.max(0, math.floor(totalSeconds))
	return string.format("%d:%02d", math.floor(s / 60), s % 60)
end

local roundUpdate = Remotes.get(Remotes.RoundUpdate)
local scoreUpdate = Remotes.get(Remotes.ScoreUpdate)

-- Server -> all clients, every second and on every state change.
roundUpdate.OnClientEvent:Connect(function(state: string, timeLeft: number, _roundNumber: number)
	stateLabel.Text = STATE_TEXT[state] or state
	stateLabel.TextColor3 = STATE_COLOR[state] or Color3.fromRGB(255, 255, 255)
	timerLabel.Text = formatTime(timeLeft)
end)

-- Server -> this client, whenever the score changes.
scoreUpdate.OnClientEvent:Connect(function(score: number)
	scoreLabel.Text = "Score: " .. score
end)
