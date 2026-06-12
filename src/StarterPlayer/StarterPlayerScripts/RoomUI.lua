-- RoomUI
-- The Squishy Room furniture picker: opens when you walk to a decorating spot
-- in your room. Shows everything that fits that spot - owned items place
-- instantly, new ones get a gentle price confirm, and "Take it away" clears the
-- spot. The server validates and persists everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiTheme = require(script.Parent.UiTheme)
local RoomConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RoomConfig"))

local RoomUI = {}

local GOLD_DEEP = Color3.fromRGB(240, 160, 40)

local overlay, panel, title, itemsHolder
local confirmBox, confirmLabel, confirmYes
local currentSlotId, currentKind, pendingItemId
local onPlaceCb

-- last-known profile slices (from StateSync)
local owned: { [string]: boolean } = {}
local placed: { [string]: string } = {}
local coins = 0

local function card(parent, y, item)
	local isOwned = item == nil or owned[item.id] == true
	local isHere = item ~= nil and placed[currentSlotId or ""] == item.id

	local c = Instance.new("TextButton")
	c.Position = UDim2.fromOffset(0, y)
	c.Size = UDim2.new(1, -8, 0, 56)
	c.BackgroundColor3 = isHere and Color3.fromRGB(255, 201, 84) or UiTheme.Colors.Panel
	c.BorderSizePixel = 0
	c.Text = ""
	c.AutoButtonColor = true
	c.Parent = parent
	UiTheme.corner(14, c)
	UiTheme.stroke(isHere and GOLD_DEEP or UiTheme.Colors.Accent, 2, c)

	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(52, 56)
	icon.Font = UiTheme.HeaderFont
	icon.TextSize = 28
	icon.Text = item and item.icon or "🫧"
	icon.Parent = c

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(56, 0)
	name.Size = UDim2.new(1, -160, 1, 0)
	name.Font = UiTheme.HeaderFont
	name.TextSize = 18
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = UiTheme.Colors.Ink
	name.Text = item and item.name or "Take it away"
	name.Parent = c

	local state = Instance.new("TextLabel")
	state.BackgroundTransparency = 1
	state.AnchorPoint = Vector2.new(1, 0)
	state.Position = UDim2.new(1, -14, 0, 0)
	state.Size = UDim2.fromOffset(110, 56)
	state.Font = UiTheme.HeaderFont
	state.TextSize = 16
	state.TextXAlignment = Enum.TextXAlignment.Right
	state.Parent = c
	if item == nil then
		state.Text = ""
	elseif isHere then
		state.Text = "Here ✓"
		state.TextColor3 = Color3.fromRGB(255, 255, 255)
	elseif isOwned then
		state.Text = "Owned"
		state.TextColor3 = UiTheme.Colors.AccentDeep
	else
		state.Text = item.price .. " coins"
		state.TextColor3 = (coins >= item.price) and GOLD_DEEP or UiTheme.Colors.SoftInk
	end

	c.Activated:Connect(function()
		if item == nil then
			if onPlaceCb then onPlaceCb(currentSlotId, nil) end
			RoomUI.hide()
		elseif isOwned or isHere then
			if onPlaceCb then onPlaceCb(currentSlotId, item.id) end
			RoomUI.hide()
		else
			pendingItemId = item.id
			confirmLabel.Text = item.icon .. "  Get the " .. item.name .. " for " .. item.price .. " Sparkle Coins?"
			confirmYes.Text = "Get it!  " .. item.price
			confirmBox.Visible = true
		end
	end)
	return 60
end

local function render()
	itemsHolder:ClearAllChildren()
	local y = 0
	-- the "clear this spot" row first if something's here
	if placed[currentSlotId or ""] then
		y += card(itemsHolder, y, nil)
	end
	for _, item in ipairs(RoomConfig.ofKind(currentKind or "")) do
		y += card(itemsHolder, y, item)
	end
	itemsHolder.CanvasSize = UDim2.fromOffset(0, y)
end

function RoomUI.mount(playerGui, onPlace)
	onPlaceCb = onPlace

	local screen = Instance.new("ScreenGui")
	screen.Name = "SquishyRoom"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 32
	screen.Parent = playerGui

	overlay = Instance.new("TextButton")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = UiTheme.Colors.Shade
	overlay.BackgroundTransparency = 0.45
	overlay.AutoButtonColor = false
	overlay.Text = ""
	overlay.Visible = false
	overlay.Parent = screen
	overlay.Activated:Connect(function()
		RoomUI.hide()
	end)

	panel = UiTheme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 430),
		BackgroundColor3 = UiTheme.Colors.Cream,
		radius = 20,
	})
	panel.Active = true
	panel.Parent = overlay
	UiTheme.stroke(UiTheme.Colors.AccentDeep, 3, panel)

	title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 14)
	title.Size = UDim2.new(1, -60, 0, 30)
	title.Font = UiTheme.HeaderFont
	title.TextSize = 22
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = UiTheme.Colors.AccentDeep
	title.Text = "🏠 Decorate"
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -14, 0, 14)
	close.Size = UDim2.fromOffset(32, 32)
	close.BackgroundColor3 = UiTheme.Colors.Accent
	close.BorderSizePixel = 0
	close.Font = UiTheme.HeaderFont
	close.TextSize = 17
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.Text = "X"
	close.Parent = panel
	UiTheme.corner(16, close)
	close.Activated:Connect(function()
		RoomUI.hide()
	end)

	itemsHolder = Instance.new("ScrollingFrame")
	itemsHolder.Position = UDim2.fromOffset(16, 54)
	itemsHolder.Size = UDim2.new(1, -32, 1, -70)
	itemsHolder.BackgroundTransparency = 1
	itemsHolder.BorderSizePixel = 0
	itemsHolder.ScrollBarThickness = 6
	itemsHolder.ScrollBarImageColor3 = UiTheme.Colors.Accent
	itemsHolder.Parent = panel

	confirmBox = UiTheme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 160),
		BackgroundColor3 = UiTheme.Colors.Panel,
		radius = 18,
	})
	confirmBox.Visible = false
	confirmBox.ZIndex = 40
	confirmBox.Active = true
	confirmBox.Parent = panel
	UiTheme.stroke(GOLD_DEEP, 3, confirmBox)

	confirmLabel = Instance.new("TextLabel")
	confirmLabel.BackgroundTransparency = 1
	confirmLabel.Position = UDim2.fromOffset(16, 14)
	confirmLabel.Size = UDim2.new(1, -32, 0, 68)
	confirmLabel.Font = UiTheme.HeaderFont
	confirmLabel.TextSize = 17
	confirmLabel.TextWrapped = true
	confirmLabel.TextColor3 = UiTheme.Colors.Ink
	confirmLabel.ZIndex = 41
	confirmLabel.Parent = confirmBox

	local function btn(text, x, color)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(x, 0, 1, -12)
		b.Size = UDim2.fromOffset(150, 42)
		b.BackgroundColor3 = color
		b.BorderSizePixel = 0
		b.Font = UiTheme.HeaderFont
		b.TextSize = 16
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Text = text
		b.ZIndex = 41
		b.Parent = confirmBox
		UiTheme.corner(18, b)
		return b
	end
	local no = btn("Not now", 0.27, UiTheme.Colors.Accent)
	confirmYes = btn("Get it!", 0.73, GOLD_DEEP)
	no.Activated:Connect(function()
		pendingItemId = nil
		confirmBox.Visible = false
	end)
	confirmYes.Activated:Connect(function()
		if pendingItemId and onPlaceCb then
			onPlaceCb(currentSlotId, pendingItemId)
		end
		pendingItemId = nil
		confirmBox.Visible = false
		RoomUI.hide()
	end)
end

-- Server says: this slot wants decorating.
function RoomUI.open(info)
	if type(info) ~= "table" or type(info.slotId) ~= "string" then
		return
	end
	currentSlotId = info.slotId
	currentKind = info.kind
	title.Text = "🏠 Choose " .. RoomConfig.kindLabel(info.kind or "")
	render()
	overlay.Visible = true
end

function RoomUI.hide()
	if overlay then
		overlay.Visible = false
		confirmBox.Visible = false
		pendingItemId = nil
	end
end

-- StateSync slice: keep owned/placed/coins fresh (re-render if open).
function RoomUI.update(state)
	if type(state) ~= "table" then
		return
	end
	coins = tonumber(state.coins) or coins
	if type(state.room) == "table" then
		owned = state.room.owned or owned
		placed = state.room.placed or placed
	end
	if overlay and overlay.Visible and currentSlotId then
		render()
	end
end

return RoomUI
