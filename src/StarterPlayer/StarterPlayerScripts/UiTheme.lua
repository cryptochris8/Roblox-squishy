-- UiTheme
-- Shared colors, fonts, and tiny builder helpers so every Squishy Smash screen
-- has the same soft, rounded, candy-storybook look.

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
