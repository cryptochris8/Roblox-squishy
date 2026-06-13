-- UiTheme
-- Shared colors, fonts, and tiny builder helpers so every Squishy Smash screen
-- has the same soft, rounded, candy-storybook look. Also owns the mobile
-- answers: "is this a phone-sized screen?" and "shrink this panel to fit".

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local UiTheme = {}

UiTheme.HeaderFont = Enum.Font.FredokaOne
UiTheme.BodyFont = Enum.Font.GothamMedium

UiTheme.Colors = {
	Cream = Color3.fromRGB(255, 247, 240),
	Panel = Color3.fromRGB(255, 255, 255),
	Ink = Color3.fromRGB(96, 74, 96),
	SoftInk = Color3.fromRGB(150, 130, 150),
	Accent = Color3.fromRGB(255, 138, 180),
	AccentDeep = Color3.fromRGB(225, 90, 150),
	Coin = Color3.fromRGB(255, 201, 84),
	CoinDeep = Color3.fromRGB(240, 160, 40),
	Locked = Color3.fromRGB(214, 208, 220),
	Shade = Color3.fromRGB(60, 50, 70),
}

UiTheme.Rarity = {
	common = Color3.fromRGB(150, 190, 235),
	rare = Color3.fromRGB(130, 150, 245),
	epic = Color3.fromRGB(190, 120, 240),
	legendary = Color3.fromRGB(255, 200, 70),
	mythic = Color3.fromRGB(255, 170, 90),
	family = Color3.fromRGB(255, 140, 175), -- a loving heart-rose, fancier than all
}

UiTheme.PackColor = {
	["Pudding Hills"] = Color3.fromRGB(255, 196, 212),
	["Goo Coast"] = Color3.fromRGB(176, 220, 255),
	["Moonlit Hollow"] = Color3.fromRGB(206, 186, 255),
}

function UiTheme.rarityColor(rarity: string): Color3
	return UiTheme.Rarity[rarity] or UiTheme.Rarity.common
end

function UiTheme.rarityLabel(rarity: string): string
	return (rarity:sub(1, 1):upper() .. rarity:sub(2))
end

function UiTheme.corner(radius: number, parent: Instance): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

function UiTheme.stroke(color: Color3, thickness: number, parent: Instance): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function UiTheme.gradient(c1: Color3, c2: Color3, rotation: number, parent: Instance): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rotation
	g.Parent = parent
	return g
end

-- PHONE-sized screen? (Touch + a short viewport — tablets keep the roomy
-- desktop layout.) The LocalPlayer attribute ForceCompactHud overrides the
-- answer for Studio testing.
function UiTheme.isCompact(): boolean
	local lp = Players.LocalPlayer
	local forced = lp and lp:GetAttribute("ForceCompactHud")
	if forced ~= nil then
		return forced == true
	end
	local cam = workspace.CurrentCamera
	local v = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	local shortSide = math.min(v.X, v.Y)
	return (UserInputService.TouchEnabled and shortSide < 600) or shortSide < 460
end

-- Tells layout code the compact answer may have flipped (rotation, window
-- resize, or the test override).
function UiTheme.onLayoutMaybeChanged(callback: () -> ())
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(callback)
	end
	local lp = Players.LocalPlayer
	if lp then
		lp:GetAttributeChangedSignal("ForceCompactHud"):Connect(callback)
	end
end

-- Keeps a fixed-size, centered panel on screen: a UIScale that shrinks it
-- (never grows it) whenever the screen is smaller than the design size, so
-- every desktop-designed panel fits a phone untouched.
function UiTheme.autoFit(panel: GuiObject, designW: number, designH: number): UIScale
	local scaleObj = Instance.new("UIScale")
	scaleObj.Name = "AutoFit"
	scaleObj.Parent = panel
	local function apply()
		local screen = panel:FindFirstAncestorWhichIsA("ScreenGui")
		local size = screen and screen.AbsoluteSize or Vector2.new(1920, 1080)
		scaleObj.Scale = math.min(1, (size.X - 24) / designW, (size.Y - 24) / designH)
	end
	-- the gui may not be parented/laid out yet when mount() calls this
	task.defer(function()
		apply()
		local screen = panel:FindFirstAncestorWhichIsA("ScreenGui")
		if screen then
			screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
		end
	end)
	return scaleObj
end

-- A soft rounded panel. props may include a numeric `radius` (skipped from the
-- property loop). Any key starting with "_" is ignored as a property.
function UiTheme.panel(props): Frame
	props = props or {}
	local f = Instance.new("Frame")
	f.BackgroundColor3 = UiTheme.Colors.Panel
	f.BorderSizePixel = 0
	for key, value in pairs(props) do
		if key ~= "radius" and key:sub(1, 1) ~= "_" then
			(f :: any)[key] = value
		end
	end
	UiTheme.corner(props.radius or 16, f)
	return f
end

return UiTheme
