-- BoutiqueUI
-- The Sparkle Boutique shop panel: hats, sparkle trails, and balloons for your
-- buddy, bought with earned Sparkle Coins. Kid-clear states on every card —
-- price, "tap to wear", or "Wearing ✓" — and one gentle confirm before a buy.
-- The server validates everything; this is just the storefront.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiTheme = require(script.Parent.UiTheme)
local CosmeticsConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CosmeticsConfig"))

local BoutiqueUI = {}

local GOLD = Color3.fromRGB(255, 201, 84)
local GOLD_DEEP = Color3.fromRGB(240, 160, 40)

local overlay, panel, coinsLabel, itemsHolder
local confirmBox, confirmLabel, confirmYes
local pendingBuyId = nil
local onBuyCb, onEquipCb

-- what the server last told us
local coins = 0
local owned: { [string]: boolean } = {}
local equipped: { [string]: string } = {}

local function card(parent, item, x, y, w)
	local isOwned = owned[item.id] == true
	local isWorn = equipped[item.type] == item.id

	local c = Instance.new("TextButton")
	c.Name = item.id
	c.Position = UDim2.fromOffset(x, y)
	c.Size = UDim2.fromOffset(w, 104)
	c.BackgroundColor3 = isWorn and GOLD or UiTheme.Colors.Panel
	c.BorderSizePixel = 0
	c.Text = ""
	c.AutoButtonColor = true
	c.Parent = parent
	UiTheme.corner(14, c)
	UiTheme.stroke(isWorn and GOLD_DEEP or (isOwned and UiTheme.Colors.Accent or Color3.fromRGB(235, 222, 230)), 2, c)

	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.new(1, 0, 0, 38)
	icon.Position = UDim2.fromOffset(0, 6)
	icon.Font = UiTheme.HeaderFont
	icon.TextSize = 30
	icon.Text = item.icon
	icon.Parent = c

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, -8, 0, 18)
	name.Position = UDim2.fromOffset(4, 44)
	name.Font = UiTheme.HeaderFont
	name.TextSize = 13
	name.TextColor3 = UiTheme.Colors.Ink
	name.TextWrapped = true
	name.Text = item.name
	name.Parent = c

	local state = Instance.new("TextLabel")
	state.BackgroundTransparency = 1
	state.Size = UDim2.new(1, -8, 0, 26)
	state.Position = UDim2.fromOffset(4, 66)
	state.Font = UiTheme.HeaderFont
	state.TextSize = 14
	state.TextWrapped = true
	state.Parent = c
	if isWorn then
		state.Text = "Wearing ✓"
		state.TextColor3 = Color3.fromRGB(255, 255, 255)
	elseif isOwned then
		state.Text = "Tap to wear"
		state.TextColor3 = UiTheme.Colors.AccentDeep
	else
		state.Text = "🪙 " .. item.price
		state.TextColor3 = (coins >= item.price) and GOLD_DEEP or UiTheme.Colors.SoftInk
	end

	c.Activated:Connect(function()
		if isWorn then
			if onEquipCb then onEquipCb(item.type, nil) end -- take it off
		elseif isOwned then
			if onEquipCb then onEquipCb(item.type, item.id) end
		else
			-- gentle confirm before spending
			pendingBuyId = item.id
			confirmLabel.Text = item.icon .. "  Buy the " .. item.name .. " for " .. item.price .. " Sparkle Coins?"
			confirmYes.Text = "Buy  🪙 " .. item.price
			confirmBox.Visible = true
		end
	end)
end

local function render()
	if not itemsHolder then
		return
	end
	itemsHolder:ClearAllChildren()
	coinsLabel.Text = "🪙 " .. coins

	local y = 0
	for _, cosmeticType in ipairs(CosmeticsConfig.Types) do
		local header = Instance.new("TextLabel")
		header.BackgroundTransparency = 1
		header.Position = UDim2.fromOffset(4, y)
		header.Size = UDim2.new(1, -8, 0, 26)
		header.Font = UiTheme.HeaderFont
		header.TextSize = 18
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.TextColor3 = UiTheme.Colors.AccentDeep
		header.Text = CosmeticsConfig.TypeLabel[cosmeticType] or cosmeticType
		header.Parent = itemsHolder
		y += 30

		local items = CosmeticsConfig.ofType(cosmeticType)
		local perRow = 6
		local gap = 8
		local w = math.floor((620 - gap * (perRow - 1)) / perRow)
		for i, item in ipairs(items) do
			local col = (i - 1) % perRow
			local row = math.floor((i - 1) / perRow)
			card(itemsHolder, item, col * (w + gap), y + row * 112, w)
		end
		y += (math.ceil(#items / perRow)) * 112 + 8
	end
	itemsHolder.CanvasSize = UDim2.fromOffset(0, y)
end

function BoutiqueUI.mount(playerGui, onBuy, onEquip)
	onBuyCb, onEquipCb = onBuy, onEquip

	local screen = Instance.new("ScreenGui")
	screen.Name = "SquishyBoutique"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.DisplayOrder = 30
	screen.Parent = playerGui

	overlay = Instance.new("TextButton")
	overlay.Name = "Shade"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = UiTheme.Colors.Shade
	overlay.BackgroundTransparency = 0.45
	overlay.AutoButtonColor = false
	overlay.Text = ""
	overlay.Visible = false
	overlay.Parent = screen
	overlay.Activated:Connect(function()
		BoutiqueUI.hide()
	end)

	panel = UiTheme.panel({
		Name = "BoutiquePanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(680, 520),
		BackgroundColor3 = UiTheme.Colors.Cream,
		radius = 22,
	})
	panel.Active = true -- clicks on the panel shouldn't close it
	panel.Parent = overlay
	UiTheme.stroke(UiTheme.Colors.AccentDeep, 3, panel)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.fromOffset(360, 34)
	title.Font = UiTheme.HeaderFont
	title.TextSize = 26
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = UiTheme.Colors.AccentDeep
	title.Text = "✨ Sparkle Boutique"
	title.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(24, 46)
	hint.Size = UDim2.fromOffset(480, 18)
	hint.Font = UiTheme.BodyFont
	hint.TextSize = 13
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = UiTheme.Colors.SoftInk
	hint.Text = "Cute things for your buddy — earned with Sparkle Coins!"
	hint.Parent = panel

	coinsLabel = Instance.new("TextLabel")
	coinsLabel.BackgroundColor3 = UiTheme.Colors.Panel
	coinsLabel.BorderSizePixel = 0
	coinsLabel.AnchorPoint = Vector2.new(1, 0)
	coinsLabel.Position = UDim2.new(1, -64, 0, 16)
	coinsLabel.Size = UDim2.fromOffset(120, 34)
	coinsLabel.Font = UiTheme.HeaderFont
	coinsLabel.TextSize = 18
	coinsLabel.TextColor3 = GOLD_DEEP
	coinsLabel.Text = "🪙 0"
	coinsLabel.Parent = panel
	UiTheme.corner(17, coinsLabel)
	UiTheme.stroke(GOLD_DEEP, 2, coinsLabel)

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -16, 0, 16)
	close.Size = UDim2.fromOffset(34, 34)
	close.BackgroundColor3 = UiTheme.Colors.Accent
	close.BorderSizePixel = 0
	close.Font = UiTheme.HeaderFont
	close.TextSize = 18
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.Text = "✕"
	close.Parent = panel
	UiTheme.corner(17, close)
	close.Activated:Connect(function()
		BoutiqueUI.hide()
	end)

	itemsHolder = Instance.new("ScrollingFrame")
	itemsHolder.Name = "Items"
	itemsHolder.Position = UDim2.fromOffset(24, 72)
	itemsHolder.Size = UDim2.new(1, -48, 1, -96)
	itemsHolder.BackgroundTransparency = 1
	itemsHolder.BorderSizePixel = 0
	itemsHolder.ScrollBarThickness = 6
	itemsHolder.ScrollBarImageColor3 = UiTheme.Colors.Accent
	itemsHolder.CanvasSize = UDim2.fromOffset(0, 0)
	itemsHolder.Parent = panel

	-- the gentle buy-confirm box
	confirmBox = UiTheme.panel({
		Name = "ConfirmBox",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 170),
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
	confirmLabel.Position = UDim2.fromOffset(18, 16)
	confirmLabel.Size = UDim2.new(1, -36, 0, 74)
	confirmLabel.Font = UiTheme.HeaderFont
	confirmLabel.TextSize = 18
	confirmLabel.TextWrapped = true
	confirmLabel.TextColor3 = UiTheme.Colors.Ink
	confirmLabel.ZIndex = 41
	confirmLabel.Text = ""
	confirmLabel.Parent = confirmBox

	local function confirmBtn(text, x, color)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(x, 0, 1, -14)
		b.Size = UDim2.fromOffset(150, 44)
		b.BackgroundColor3 = color
		b.BorderSizePixel = 0
		b.Font = UiTheme.HeaderFont
		b.TextSize = 17
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Text = text
		b.ZIndex = 41
		b.Parent = confirmBox
		UiTheme.corner(20, b)
		return b
	end
	local confirmNo = confirmBtn("Not now", 0.28, UiTheme.Colors.Accent)
	confirmYes = confirmBtn("Buy", 0.72, GOLD_DEEP)
	confirmNo.Activated:Connect(function()
		pendingBuyId = nil
		confirmBox.Visible = false
	end)
	confirmYes.Activated:Connect(function()
		if pendingBuyId and onBuyCb then
			onBuyCb(pendingBuyId)
		end
		pendingBuyId = nil
		confirmBox.Visible = false
	end)
end

function BoutiqueUI.show()
	if overlay then
		render()
		overlay.Visible = true
	end
end

function BoutiqueUI.hide()
	if overlay then
		overlay.Visible = false
		confirmBox.Visible = false
		pendingBuyId = nil
	end
end

-- Called on every StateSync; re-renders if the shop is open so a purchase's
-- new "Wearing ✓" state appears the moment the server confirms it.
function BoutiqueUI.update(state)
	if type(state) ~= "table" then
		return
	end
	coins = tonumber(state.coins) or coins
	if type(state.cosmetics) == "table" then
		owned = state.cosmetics.owned or owned
		equipped = state.cosmetics.equipped or equipped
	end
	if overlay and overlay.Visible then
		render()
	end
end

return BoutiqueUI
