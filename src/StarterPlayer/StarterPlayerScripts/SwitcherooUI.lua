-- SwitcherooUI (CLIENT)
-- The Switcheroo Station panel (doc 15 §6): pick a SPARE friend, read the calm
-- confirm ("[Name] stays in your Collection Book — a spare is going
-- traveling!"), press "All aboard! ✨". The traveler's arrival plays through
-- the full capsule reveal ceremony (SwitcherooResult routes to
-- CapsuleRevealUI), so this panel only owns the choosing.
--
-- Law notes baked in: preset pickers only (no free text), no timers, no
-- countdowns, the panel sits open as long as the kid likes, the cap message
-- promises tomorrow, and the empty state is an invitation — never a nag.

local UiTheme = require(script.Parent.UiTheme)

local SwitcherooUI = {}

local screen
local overlay = nil
local onDeposit = nil -- fn(defId), wired by ClientController

local WHITE = Color3.fromRGB(255, 255, 255)

local function isRealImage(id)
	return type(id) == "string" and id ~= "" and not string.find(id, "REPLACE_ME")
end

function SwitcherooUI.close()
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
end

-- The calm confirm page for one spare.
local function showConfirm(panel, info, spare)
	-- A TextButton, not a Frame: ZIndex only wins RENDERING — a non-Active
	-- Frame lets taps fall through to the picker tiles beneath (review catch).
	local confirm = Instance.new("TextButton")
	confirm.Name = "Confirm"
	confirm.Size = UDim2.fromScale(1, 1)
	confirm.BackgroundColor3 = UiTheme.Colors.Cream
	confirm.BorderSizePixel = 0
	confirm.Text = ""
	confirm.AutoButtonColor = false
	confirm.Active = true
	confirm.ZIndex = 25
	confirm.Parent = panel
	UiTheme.corner(24, confirm)

	local art = Instance.new("ImageLabel")
	art.AnchorPoint = Vector2.new(0.5, 0)
	art.Position = UDim2.new(0.5, 0, 0, 16)
	art.Size = UDim2.fromOffset(216, 288)
	art.BackgroundTransparency = 1
	art.ScaleType = Enum.ScaleType.Fit
	art.ZIndex = 26
	art.Parent = confirm
	if isRealImage(spare.imageAssetId) then
		art.Image = spare.imageAssetId
	else
		art.Image = ""
		local ph = Instance.new("TextLabel")
		ph.BackgroundColor3 = UiTheme.rarityColor(spare.rarity)
		ph.Size = UDim2.fromScale(1, 1)
		ph.Font = UiTheme.HeaderFont
		ph.TextSize = 24
		ph.TextWrapped = true
		ph.TextColor3 = WHITE
		ph.Text = spare.displayName
		ph.ZIndex = 26
		ph.Parent = art
		UiTheme.corner(16, ph)
	end

	local copy = Instance.new("TextLabel")
	copy.AnchorPoint = Vector2.new(0.5, 0)
	copy.Position = UDim2.new(0.5, 0, 0, 312)
	copy.Size = UDim2.new(1, -48, 0, 84)
	copy.BackgroundTransparency = 1
	copy.Font = UiTheme.BodyFont
	copy.TextSize = 17
	copy.TextWrapped = true
	copy.TextColor3 = UiTheme.Colors.Ink
	copy.Text = "Send this spare " .. spare.displayName .. " to find a new best friend?\n\n"
		.. spare.displayName .. " stays in your Squishy Book — a spare is going traveling!"
	copy.ZIndex = 26
	copy.Parent = confirm

	local aboard = Instance.new("TextButton")
	aboard.AnchorPoint = Vector2.new(0.5, 1)
	aboard.Position = UDim2.new(0.5, 0, 1, -64)
	aboard.Size = UDim2.fromOffset(230, 50)
	aboard.BackgroundColor3 = UiTheme.Colors.AccentDeep
	aboard.BorderSizePixel = 0
	aboard.Font = UiTheme.HeaderFont
	aboard.TextSize = 21
	aboard.TextColor3 = WHITE
	aboard.Text = "All aboard! ✨"
	aboard.ZIndex = 26
	aboard.Active = true
	aboard.Parent = confirm
	UiTheme.corner(25, aboard)
	aboard.Activated:Connect(function()
		if onDeposit then
			onDeposit(spare.defId)
		end
		SwitcherooUI.close() -- the traveler arrives as a full reveal ceremony
	end)

	local notYet = Instance.new("TextButton")
	notYet.AnchorPoint = Vector2.new(0.5, 1)
	notYet.Position = UDim2.new(0.5, 0, 1, -18)
	notYet.Size = UDim2.fromOffset(160, 36)
	notYet.BackgroundColor3 = UiTheme.Colors.Panel
	notYet.BorderSizePixel = 0
	notYet.Font = UiTheme.BodyFont
	notYet.TextSize = 16
	notYet.TextColor3 = UiTheme.Colors.SoftInk
	notYet.Text = "Not yet"
	notYet.ZIndex = 26
	notYet.Active = true
	notYet.Parent = confirm
	UiTheme.corner(18, notYet)
	notYet.Activated:Connect(function()
		confirm:Destroy()
	end)
end

function SwitcherooUI.open(info)
	if not screen or type(info) ~= "table" then
		return
	end
	SwitcherooUI.close()

	overlay = Instance.new("TextButton")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = UiTheme.Colors.Shade
	overlay.BackgroundTransparency = 0.45
	overlay.BorderSizePixel = 0
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.Active = true
	overlay.ZIndex = 20
	overlay.Parent = screen
	overlay.Activated:Connect(SwitcherooUI.close)

	local panel = UiTheme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(470, 520),
		BackgroundColor3 = UiTheme.Colors.Cream,
		radius = 24,
	})
	panel.ZIndex = 21
	panel.Parent = overlay
	UiTheme.stroke(Color3.fromRGB(235, 90, 100), 3, panel)
	UiTheme.autoFit(panel, 470, 520)
	-- taps inside the panel must not fall through to the close-overlay
	local sink = Instance.new("TextButton")
	sink.Size = UDim2.fromScale(1, 1)
	sink.BackgroundTransparency = 1
	sink.Text = ""
	sink.AutoButtonColor = false
	sink.Active = true
	sink.ZIndex = 21
	sink.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 14)
	title.Size = UDim2.new(1, -40, 0, 32)
	title.Font = UiTheme.HeaderFont
	title.TextSize = 24
	title.TextColor3 = Color3.fromRGB(235, 90, 100)
	title.Text = "🚂 The Switcheroo Station"
	title.ZIndex = 22
	title.Parent = panel

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(20, 46)
	sub.Size = UDim2.new(1, -40, 0, 40)
	sub.Font = UiTheme.BodyFont
	sub.TextSize = 15
	sub.TextWrapped = true
	sub.TextColor3 = UiTheme.Colors.Ink
	sub.Text = "Send a spare friend on an Express adventure — and welcome the traveler who steps off for you!"
	sub.ZIndex = 22
	sub.Parent = panel

	local left = tonumber(info.adventuresLeft) or 0
	local pill = Instance.new("TextLabel")
	pill.AnchorPoint = Vector2.new(1, 0)
	pill.Position = UDim2.new(1, -20, 0, 16)
	pill.Size = UDim2.fromOffset(150, 26)
	pill.BackgroundColor3 = UiTheme.Colors.Accent
	pill.BorderSizePixel = 0
	pill.Font = UiTheme.HeaderFont
	pill.TextSize = 14
	pill.TextColor3 = WHITE
	pill.Text = left == 1 and "1 adventure left today" or (left .. " adventures left today")
	pill.ZIndex = 23
	pill.Parent = panel
	UiTheme.corner(13, pill)

	local spares = info.spares or {}

	-- Cap reached / no spares: a warm message instead of the grid.
	local message = nil
	if left < 1 then
		message = "🚂 The Express is resting its wheels — more adventures tomorrow!"
	elseif #spares == 0 then
		message = "No spare friends yet! Extra friends from Sparkle Capsules become spares — they'd love an adventure. 💖"
	end
	if message then
		local msg = Instance.new("TextLabel")
		msg.AnchorPoint = Vector2.new(0.5, 0.5)
		msg.Position = UDim2.fromScale(0.5, 0.55)
		msg.Size = UDim2.new(1, -80, 0, 120)
		msg.BackgroundTransparency = 1
		msg.Font = UiTheme.BodyFont
		msg.TextSize = 18
		msg.TextWrapped = true
		msg.TextColor3 = UiTheme.Colors.Ink
		msg.Text = message
		msg.ZIndex = 22
		msg.Parent = panel
		return
	end

	-- The spare picker grid.
	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(20, 96)
	scroll.Size = UDim2.new(1, -40, 1, -116)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.ZIndex = 22
	scroll.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(132, 176)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	for i, spare in ipairs(spares) do
		local tile = Instance.new("TextButton")
		tile.Name = spare.defId
		tile.LayoutOrder = i
		tile.BackgroundColor3 = UiTheme.Colors.Panel
		tile.BorderSizePixel = 0
		tile.AutoButtonColor = true
		tile.Text = ""
		tile.ZIndex = 22
		tile.Parent = scroll
		UiTheme.corner(14, tile)
		UiTheme.stroke(UiTheme.rarityColor(spare.rarity), 3, tile)

		local art = Instance.new("ImageLabel")
		art.Position = UDim2.fromOffset(8, 8)
		art.Size = UDim2.new(1, -16, 0, 120)
		art.BackgroundColor3 = UiTheme.rarityColor(spare.rarity)
		art.BorderSizePixel = 0
		art.ScaleType = Enum.ScaleType.Fit
		art.ZIndex = 22
		art.Parent = tile
		UiTheme.corner(10, art)
		if isRealImage(spare.imageAssetId) then
			art.Image = spare.imageAssetId
			art.BackgroundColor3 = UiTheme.Colors.Cream
		end

		local nameLbl = Instance.new("TextLabel")
		nameLbl.BackgroundTransparency = 1
		nameLbl.Position = UDim2.fromOffset(6, 130)
		nameLbl.Size = UDim2.new(1, -12, 0, 22)
		nameLbl.Font = UiTheme.HeaderFont
		nameLbl.TextSize = 13
		nameLbl.TextWrapped = true
		nameLbl.TextColor3 = UiTheme.Colors.Ink
		nameLbl.Text = spare.displayName
		nameLbl.ZIndex = 23
		nameLbl.Parent = tile

		local count = Instance.new("TextLabel")
		count.BackgroundTransparency = 1
		count.Position = UDim2.fromOffset(6, 152)
		count.Size = UDim2.new(1, -12, 0, 16)
		count.Font = UiTheme.BodyFont
		count.TextSize = 12
		count.TextColor3 = UiTheme.Colors.CoinDeep
		count.Text = spare.spares == 1 and "1 spare" or (spare.spares .. " spares")
		count.ZIndex = 23
		count.Parent = tile

		tile.Activated:Connect(function()
			showConfirm(panel, info, spare)
		end)
	end
end

function SwitcherooUI.mount(playerGui, depositFn)
	onDeposit = depositFn
	screen = Instance.new("ScreenGui")
	screen.Name = "SwitcherooStation"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 30
	screen.Parent = playerGui
end

return SwitcherooUI
