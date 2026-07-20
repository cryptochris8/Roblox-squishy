-- PhotoMode (CLIENT)
-- One tap: the HUD melts away and a slow, kid-gentle cinematic orbit circles your
-- character so anyone can grab a lovely storybook screenshot. One tap out. Pure
-- client cosmetics — the world keeps running underneath. (Ported from Gnarly
-- Nutmeg's PhotoMode and re-themed to the candy-storybook look.)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ContextActionService = game:GetService("ContextActionService")

local UiTheme = require(script.Parent:WaitForChild("UiTheme"))

local PhotoMode = {}

local player = Players.LocalPlayer
local active = false
local orbitConn = nil
local hiddenGuis = {}
local exitGui = nil
local entryButton = nil

local function setHudHidden(hidden: boolean)
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	if hidden then
		hiddenGuis = {}
		for _, g in ipairs(pg:GetChildren()) do
			if g:IsA("ScreenGui") and g.Enabled and g ~= exitGui then
				hiddenGuis[#hiddenGuis + 1] = g
				g.Enabled = false
			end
		end
	else
		for _, g in ipairs(hiddenGuis) do
			if g.Parent then
				g.Enabled = true
			end
		end
		hiddenGuis = {}
	end
end

local function buildExitButton()
	if exitGui then
		return
	end
	local pg = player:WaitForChild("PlayerGui")
	exitGui = Instance.new("ScreenGui")
	exitGui.Name = "SquishyPhoto"
	exitGui.ResetOnSpawn = false
	exitGui.Enabled = false
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Position = UDim2.new(0.5, 0, 1, -24)
	b.Size = UDim2.fromOffset(210, 48)
	b.BackgroundColor3 = UiTheme.Colors.Panel
	b.Font = UiTheme.HeaderFont
	b.TextSize = 18
	b.TextColor3 = UiTheme.Colors.Ink
	b.Text = "📸 All done — tap to close"
	b.AutoButtonColor = true
	UiTheme.corner(18, b)
	UiTheme.stroke(UiTheme.Colors.Accent, 3, b)
	b.MouseButton1Click:Connect(function()
		PhotoMode.toggle()
	end)
	b.Parent = exitGui
	exitGui.Parent = pg
end

local function stopOrbit()
	if orbitConn then
		orbitConn:Disconnect()
		orbitConn = nil
	end
	local cam = Workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
	end
end

local function startOrbit()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	cam.CameraType = Enum.CameraType.Scriptable
	local angle = 0
	orbitConn = RunService.RenderStepped:Connect(function(dt)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		angle += dt * 0.35 -- one lap ~18s: slow enough to line up any shot
		local focus = root.Position + Vector3.new(0, 1.6, 0)
		local pos = focus + Vector3.new(math.sin(angle) * 12, 3.2, math.cos(angle) * 12)
		cam.CFrame = CFrame.lookAt(pos, focus)
	end)
end

function PhotoMode.isActive(): boolean
	return active
end

function PhotoMode.toggle()
	buildExitButton()
	active = not active
	if active then
		setHudHidden(true)
		exitGui.Enabled = true
		startOrbit()
	else
		stopOrbit()
		exitGui.Enabled = false
		setHudHidden(false)
	end
end

-- anything (a finale celebration, a respawn) can force photo mode closed
function PhotoMode.exit()
	if active then
		PhotoMode.toggle()
	end
end

-- Sits just BELOW the HUD's top-right button row so it never overlaps; follows
-- the compact/desktop flip.
local function positionEntry()
	if entryButton then
		if UiTheme.isCompact() then
			-- phones: the HUD actions are a right-edge column now, so tuck 📸 on the
			-- LEFT below the stat pills, clear of the joystick
			entryButton.AnchorPoint = Vector2.new(0, 0)
			entryButton.Position = UDim2.new(0, 12, 0, 150)
		else
			entryButton.AnchorPoint = Vector2.new(1, 0)
			entryButton.Position = UDim2.new(1, -14, 0, 156)
		end
	end
end

-- the always-there way in: a small storybook 📸 button, plus the P key
function PhotoMode.init()
	local pg = player:WaitForChild("PlayerGui")
	local entry = Instance.new("ScreenGui")
	entry.Name = "SquishyPhotoEntry"
	entry.ResetOnSpawn = false
	local b = Instance.new("TextButton")
	b.Name = "PhotoButton"
	b.AnchorPoint = Vector2.new(1, 0)
	b.Size = UDim2.fromOffset(46, 46)
	b.BackgroundColor3 = UiTheme.Colors.Panel
	b.Font = UiTheme.HeaderFont
	b.TextSize = 22
	b.TextColor3 = UiTheme.Colors.Ink
	b.Text = "📸"
	b.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0) -- a circle
	corner.Parent = b
	UiTheme.stroke(UiTheme.Colors.Accent, 3, b)
	b.MouseButton1Click:Connect(function()
		PhotoMode.toggle()
	end)
	b.Parent = entry
	entryButton = b
	positionEntry()
	entry.Parent = pg
	UiTheme.onLayoutMaybeChanged(positionEntry)

	ContextActionService:BindAction("SquishyPhoto", function(_, state)
		if state == Enum.UserInputState.Begin then
			PhotoMode.toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.P)
end

return PhotoMode
