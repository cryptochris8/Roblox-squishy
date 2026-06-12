-- GiftUI
-- The gift picker: opens when you tap 🎁 on another player. Two kind things to
-- give — Sparkle Coins (preset amounts only, no typing) or SHARE a friend
-- you've discovered (they get the discovery and the card reveal; you keep
-- yours). One gentle picture-confirm before anything is sent; the server
-- validates everything. Also plays the cozy "a gift arrived!" moment for coin
-- gifts, and hides the 🎁 prompt on your OWN character so it never sits in
-- your face or eats your E key.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiTheme = require(script.Parent.UiTheme)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GiftConfig = require(Shared:WaitForChild("GiftConfig"))
local SquishyData = require(Shared:WaitForChild("SquishyData"))

local GiftUI = {}

local localPlayer = Players.LocalPlayer

local overlay, panel, titleLabel, leftPill, coinsNote, friendsHolder, friendsEmpty
local confirmBox, confirmText, confirmArt, confirmYes
local receivedLayer
local onSendCb

-- who the panel is aimed at right now
local target = nil -- { userId, name, theyKnow, remaining }
local pendingGift = nil -- { kind, value, confirmVerb }

-- what the server last told us about US
local coins = 0
local discovered = {}

local function isRealImage(id)
	return type(id) == "string" and id ~= "" and not string.find(id, "REPLACE_ME")
end

-- ── the friend mini-cards ───────────────────────────────────────────────────
local function friendCard(parent, def, x, y, w, h, theyKnow)
	local c = Instance.new("TextButton")
	c.Name = def.Id
	c.Position = UDim2.fromOffset(x, y)
	c.Size = UDim2.fromOffset(w, h)
	c.BackgroundColor3 = UiTheme.rarityColor(def.Rarity)
	c.BorderSizePixel = 0
	c.Text = ""
	c.AutoButtonColor = not theyKnow
	c.Parent = parent
	UiTheme.corner(10, c)
	UiTheme.stroke(theyKnow and UiTheme.Colors.Locked or UiTheme.Colors.Accent, 2, c)

	if isRealImage(def.ImageAssetId) then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.ScaleType = Enum.ScaleType.Fit
		img.Image = def.ImageAssetId
		img.ImageTransparency = theyKnow and 0.55 or 0
		img.Parent = c
	else
		local nameLbl = Instance.new("TextLabel")
		nameLbl.BackgroundTransparency = 1
		nameLbl.Size = UDim2.new(1, -6, 1, -6)
		nameLbl.Position = UDim2.fromOffset(3, 3)
		nameLbl.Font = UiTheme.HeaderFont
		nameLbl.TextSize = 13
		nameLbl.TextWrapped = true
		nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLbl.TextTransparency = theyKnow and 0.45 or 0
		nameLbl.Text = def.DisplayName
		nameLbl.Parent = c
	end

	if theyKnow then
		local knows = Instance.new("TextLabel")
		knows.AnchorPoint = Vector2.new(0.5, 1)
		knows.Position = UDim2.new(0.5, 0, 1, -6)
		knows.Size = UDim2.new(1, -10, 0, 20)
		knows.BackgroundColor3 = UiTheme.Colors.Locked
		knows.BorderSizePixel = 0
		knows.Font = UiTheme.HeaderFont
		knows.TextSize = 11
		knows.TextColor3 = UiTheme.Colors.Ink
		knows.Text = "They know ✓"
		knows.Parent = c
		UiTheme.corner(10, knows)
	else
		c.Activated:Connect(function()
			pendingGift = { kind = "friend", value = def.Id, confirmVerb = "Share 💝" }
			confirmText.Text = "Share " .. def.DisplayName .. " with " .. target.name .. "?\nYou keep yours, too!"
			confirmYes.Text = "Share 💝"
			confirmArt.Visible = isRealImage(def.ImageAssetId)
			if confirmArt.Visible then
				confirmArt.Image = def.ImageAssetId
			end
			confirmBox.Visible = true
		end)
	end
end

-- ── rendering ───────────────────────────────────────────────────────────────
local function render()
	if not (panel and target) then
		return
	end
	titleLabel.Text = "🎁 A gift for " .. target.name .. "!"
	leftPill.Text = "💝 " .. target.remaining .. (target.remaining == 1 and " gift left" or " gifts left")
	coinsNote.Text = "(you have " .. coins .. " coins)"

	-- coin preset buttons reflect what the sender can afford right now
	for _, btn in ipairs(panel:FindFirstChild("CoinRow"):GetChildren()) do
		if btn:IsA("TextButton") then
			local amount = tonumber(btn.Name)
			local canAfford = amount and coins >= amount
			btn.BackgroundColor3 = canAfford and UiTheme.Colors.Coin or UiTheme.Colors.Locked
			btn.TextColor3 = canAfford and Color3.fromRGB(120, 86, 20) or UiTheme.Colors.SoftInk
		end
	end

	-- the share-a-friend grid: my discovered friends, album order, events last
	friendsHolder:ClearAllChildren()
	local mine = {}
	for _, def in ipairs(SquishyData.getLaunchRoster()) do
		if discovered[def.Id] then
			mine[#mine + 1] = def
		end
	end
	for _, def in ipairs(SquishyData.getEventRoster()) do
		if discovered[def.Id] then
			mine[#mine + 1] = def
		end
	end
	friendsEmpty.Visible = #mine == 0
	local perRow, gap, w, h = 5, 8, 96, 128
	for i, def in ipairs(mine) do
		local col = (i - 1) % perRow
		local row = math.floor((i - 1) / perRow)
		friendCard(friendsHolder, def, col * (w + gap), row * (h + gap), w, h, target.theyKnow[def.Id] == true)
	end
	friendsHolder.CanvasSize = UDim2.fromOffset(0, math.ceil(#mine / perRow) * (h + gap))
end

-- ── mounting ────────────────────────────────────────────────────────────────
function GiftUI.mount(playerGui, onSend)
	onSendCb = onSend

	local screen = Instance.new("ScreenGui")
	screen.Name = "SquishyGifts"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.DisplayOrder = 34 -- above the Boutique (30), below toasts (50)
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
		GiftUI.hide()
	end)

	panel = UiTheme.panel({
		Name = "GiftPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 470),
		BackgroundColor3 = UiTheme.Colors.Cream,
		radius = 22,
	})
	panel.Active = true
	panel.Parent = overlay
	UiTheme.stroke(UiTheme.Colors.AccentDeep, 3, panel)
	UiTheme.autoFit(panel, 560, 470)

	titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(24, 14)
	titleLabel.Size = UDim2.fromOffset(330, 34)
	titleLabel.Font = UiTheme.HeaderFont
	titleLabel.TextSize = 24
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.TextColor3 = UiTheme.Colors.AccentDeep
	titleLabel.Text = "🎁 A gift!"
	titleLabel.Parent = panel

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(24, 46)
	hint.Size = UDim2.fromOffset(512, 18)
	hint.Font = UiTheme.BodyFont
	hint.TextSize = 13
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = UiTheme.Colors.SoftInk
	hint.Text = "Gifts are extra nice — and you keep your friends when you share them!"
	hint.Parent = panel

	leftPill = Instance.new("TextLabel")
	leftPill.BackgroundColor3 = UiTheme.Colors.Panel
	leftPill.BorderSizePixel = 0
	leftPill.AnchorPoint = Vector2.new(1, 0)
	leftPill.Position = UDim2.new(1, -64, 0, 16)
	leftPill.Size = UDim2.fromOffset(130, 34)
	leftPill.Font = UiTheme.HeaderFont
	leftPill.TextSize = 15
	leftPill.TextColor3 = UiTheme.Colors.AccentDeep
	leftPill.Text = ""
	leftPill.Parent = panel
	UiTheme.corner(17, leftPill)
	UiTheme.stroke(UiTheme.Colors.Accent, 2, leftPill)

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -16, 0, 16)
	close.Size = UDim2.fromOffset(34, 34)
	close.BackgroundColor3 = UiTheme.Colors.Accent
	close.BorderSizePixel = 0
	close.Font = UiTheme.HeaderFont
	close.TextSize = 18
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.Text = "X"
	close.Parent = panel
	UiTheme.corner(17, close)
	close.Activated:Connect(function()
		GiftUI.hide()
	end)

	local coinsHeader = Instance.new("TextLabel")
	coinsHeader.BackgroundTransparency = 1
	coinsHeader.Position = UDim2.fromOffset(24, 72)
	coinsHeader.Size = UDim2.fromOffset(220, 26)
	coinsHeader.Font = UiTheme.HeaderFont
	coinsHeader.TextSize = 18
	coinsHeader.TextXAlignment = Enum.TextXAlignment.Left
	coinsHeader.TextColor3 = UiTheme.Colors.AccentDeep
	coinsHeader.Text = "⭐ Give Sparkle Coins"
	coinsHeader.Parent = panel

	coinsNote = Instance.new("TextLabel")
	coinsNote.BackgroundTransparency = 1
	coinsNote.Position = UDim2.fromOffset(248, 72)
	coinsNote.Size = UDim2.fromOffset(264, 26)
	coinsNote.Font = UiTheme.BodyFont
	coinsNote.TextSize = 13
	coinsNote.TextXAlignment = Enum.TextXAlignment.Left
	coinsNote.TextColor3 = UiTheme.Colors.SoftInk
	coinsNote.Text = ""
	coinsNote.Parent = panel

	local coinRow = Instance.new("Frame")
	coinRow.Name = "CoinRow"
	coinRow.BackgroundTransparency = 1
	coinRow.Position = UDim2.fromOffset(24, 102)
	coinRow.Size = UDim2.fromOffset(512, 54)
	coinRow.Parent = panel
	for i, amount in ipairs(GiftConfig.CoinPresets) do
		local b = Instance.new("TextButton")
		b.Name = tostring(amount)
		b.Position = UDim2.fromOffset((i - 1) * 130, 0)
		b.Size = UDim2.fromOffset(118, 54)
		b.BackgroundColor3 = UiTheme.Colors.Coin
		b.BorderSizePixel = 0
		b.Font = UiTheme.HeaderFont
		b.TextSize = 20
		b.TextColor3 = Color3.fromRGB(120, 86, 20)
		b.Text = tostring(amount)
		b.Parent = coinRow
		UiTheme.corner(16, b)
		UiTheme.stroke(UiTheme.Colors.CoinDeep, 2, b)
		b.Activated:Connect(function()
			if coins < amount or not target then
				return -- can't give coins you don't have
			end
			pendingGift = { kind = "coins", value = amount, confirmVerb = "Give 💝" }
			confirmText.Text = "Give " .. amount .. " Sparkle Coins\nto " .. target.name .. "?"
			confirmYes.Text = "Give 💝"
			confirmArt.Visible = false
			confirmBox.Visible = true
		end)
	end

	local friendsHeader = Instance.new("TextLabel")
	friendsHeader.BackgroundTransparency = 1
	friendsHeader.Position = UDim2.fromOffset(24, 166)
	friendsHeader.Size = UDim2.fromOffset(220, 26)
	friendsHeader.Font = UiTheme.HeaderFont
	friendsHeader.TextSize = 18
	friendsHeader.TextXAlignment = Enum.TextXAlignment.Left
	friendsHeader.TextColor3 = UiTheme.Colors.AccentDeep
	friendsHeader.Text = "🧸 Share a Friend"
	friendsHeader.Parent = panel

	local friendsNote = Instance.new("TextLabel")
	friendsNote.BackgroundTransparency = 1
	friendsNote.Position = UDim2.fromOffset(248, 166)
	friendsNote.Size = UDim2.fromOffset(264, 26)
	friendsNote.Font = UiTheme.BodyFont
	friendsNote.TextSize = 13
	friendsNote.TextXAlignment = Enum.TextXAlignment.Left
	friendsNote.TextColor3 = UiTheme.Colors.SoftInk
	friendsNote.Text = "(they get the card — you keep yours!)"
	friendsNote.Parent = panel

	friendsHolder = Instance.new("ScrollingFrame")
	friendsHolder.Name = "Friends"
	friendsHolder.Position = UDim2.fromOffset(24, 196)
	friendsHolder.Size = UDim2.new(1, -48, 1, -210)
	friendsHolder.BackgroundTransparency = 1
	friendsHolder.BorderSizePixel = 0
	friendsHolder.ScrollBarThickness = 6
	friendsHolder.ScrollBarImageColor3 = UiTheme.Colors.Accent
	friendsHolder.CanvasSize = UDim2.fromOffset(0, 0)
	friendsHolder.Parent = panel

	friendsEmpty = Instance.new("TextLabel")
	friendsEmpty.BackgroundTransparency = 1
	friendsEmpty.Position = UDim2.fromOffset(24, 196)
	friendsEmpty.Size = UDim2.new(1, -48, 0, 60)
	friendsEmpty.Font = UiTheme.BodyFont
	friendsEmpty.TextSize = 14
	friendsEmpty.TextWrapped = true
	friendsEmpty.TextColor3 = UiTheme.Colors.SoftInk
	friendsEmpty.Text = "Discover friends in Sparkle Capsules and you can share them here!"
	friendsEmpty.Visible = false
	friendsEmpty.Parent = panel

	-- the gentle picture-confirm
	confirmBox = UiTheme.panel({
		Name = "ConfirmBox",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(400, 210),
		BackgroundColor3 = UiTheme.Colors.Panel,
		radius = 18,
	})
	confirmBox.Visible = false
	confirmBox.ZIndex = 40
	confirmBox.Active = true
	confirmBox.Parent = panel
	UiTheme.stroke(UiTheme.Colors.AccentDeep, 3, confirmBox)

	confirmArt = Instance.new("ImageLabel")
	confirmArt.BackgroundTransparency = 1
	confirmArt.Position = UDim2.fromOffset(16, 16)
	confirmArt.Size = UDim2.fromOffset(90, 120)
	confirmArt.ScaleType = Enum.ScaleType.Fit
	confirmArt.ZIndex = 41
	confirmArt.Visible = false
	confirmArt.Parent = confirmBox

	confirmText = Instance.new("TextLabel")
	confirmText.BackgroundTransparency = 1
	confirmText.Position = UDim2.fromOffset(118, 16)
	confirmText.Size = UDim2.fromOffset(266, 120)
	confirmText.Font = UiTheme.HeaderFont
	confirmText.TextSize = 18
	confirmText.TextWrapped = true
	confirmText.TextColor3 = UiTheme.Colors.Ink
	confirmText.ZIndex = 41
	confirmText.Text = ""
	confirmText.Parent = confirmBox

	local function confirmBtn(name, text, x, color)
		local b = Instance.new("TextButton")
		b.Name = name
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(x, 0, 1, -14)
		b.Size = UDim2.fromOffset(160, 44)
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
	local confirmNo = confirmBtn("BtnNotNow", "Not now", 0.27, UiTheme.Colors.Accent)
	confirmYes = confirmBtn("BtnGive", "Give 💝", 0.73, UiTheme.Colors.AccentDeep)
	confirmNo.Activated:Connect(function()
		pendingGift = nil
		confirmBox.Visible = false
	end)
	confirmYes.Activated:Connect(function()
		if pendingGift and target and onSendCb then
			onSendCb(target.userId, pendingGift.kind, pendingGift.value)
		end
		GiftUI.hide() -- the server's toast tells the rest of the story
	end)

	-- where "a gift arrived!" pops (independent of the picker being open)
	receivedLayer = Instance.new("Frame")
	receivedLayer.Size = UDim2.fromScale(1, 1)
	receivedLayer.BackgroundTransparency = 1
	receivedLayer.ZIndex = 60
	receivedLayer.Parent = screen

	-- hide the 🎁 prompt on MY OWN character, locally, every spawn
	local function hideOwnPrompt(character)
		task.spawn(function()
			local root = character:WaitForChild("HumanoidRootPart", 10)
			local prompt = root and root:WaitForChild("GiftPrompt", 10)
			if prompt then
				prompt.Enabled = false -- local-only: everyone else still sees it
			end
		end)
	end
	localPlayer.CharacterAdded:Connect(hideOwnPrompt)
	if localPlayer.Character then
		hideOwnPrompt(localPlayer.Character)
	end
end

-- ── open / close / state ────────────────────────────────────────────────────
function GiftUI.open(info)
	if not (overlay and type(info) == "table") then
		return
	end
	target = {
		userId = info.userId,
		name = tostring(info.name or "your friend"),
		theyKnow = type(info.theyKnow) == "table" and info.theyKnow or {},
		remaining = tonumber(info.remaining) or GiftConfig.DailyGiftLimit,
	}
	render()
	overlay.Visible = true
end

function GiftUI.hide()
	if overlay then
		overlay.Visible = false
		confirmBox.Visible = false
		pendingGift = nil
		target = nil
	end
end

-- Called on every StateSync (coins and discoveries feed the picker).
function GiftUI.update(state)
	if type(state) ~= "table" then
		return
	end
	coins = tonumber(state.coins) or coins
	if type(state.discovered) == "table" then
		discovered = state.discovered
	end
	if overlay and overlay.Visible and target then
		render()
	end
end

-- ── the "a gift arrived!" moment (coin gifts; friend shares play the card reveal) ──
function GiftUI.playReceived(info)
	if not receivedLayer or type(info) ~= "table" or info.kind ~= "coins" then
		return
	end
	receivedLayer:ClearAllChildren()

	local box = UiTheme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.38),
		Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = UiTheme.Colors.Cream,
		radius = 20,
	})
	box.ZIndex = 61
	box.Parent = receivedLayer
	UiTheme.stroke(UiTheme.Colors.AccentDeep, 3, box)

	local emoji = Instance.new("TextLabel")
	emoji.BackgroundTransparency = 1
	emoji.Position = UDim2.fromOffset(14, 0)
	emoji.Size = UDim2.fromOffset(90, 150)
	emoji.Font = UiTheme.HeaderFont
	emoji.TextSize = 58
	emoji.Text = "🎁"
	emoji.ZIndex = 62
	emoji.Parent = box

	local msg = Instance.new("TextLabel")
	msg.BackgroundTransparency = 1
	msg.Position = UDim2.fromOffset(108, 0)
	msg.Size = UDim2.fromOffset(216, 150)
	msg.Font = UiTheme.HeaderFont
	msg.TextSize = 21
	msg.TextWrapped = true
	msg.TextColor3 = UiTheme.Colors.AccentDeep
	msg.Text = "+" .. (tonumber(info.amount) or 0) .. " Sparkle Coins\nfrom " .. tostring(info.fromName or "a friend") .. "! 💝"
	msg.ZIndex = 62
	msg.Parent = box

	-- pop in, wobble the bow, drift away on its own (or on a tap)
	TweenService:Create(box, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(340, 150),
	}):Play()
	task.spawn(function()
		for _ = 1, 2 do
			TweenService:Create(emoji, TweenInfo.new(0.14, Enum.EasingStyle.Sine), { Rotation = 12 }):Play()
			task.wait(0.14)
			TweenService:Create(emoji, TweenInfo.new(0.14, Enum.EasingStyle.Sine), { Rotation = -12 }):Play()
			task.wait(0.14)
		end
		TweenService:Create(emoji, TweenInfo.new(0.1), { Rotation = 0 }):Play()
	end)

	local closed = false
	local function dismiss()
		if closed then
			return
		end
		closed = true
		local out = TweenService:Create(box, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Size = UDim2.fromOffset(0, 0),
		})
		out.Completed:Connect(function()
			box:Destroy()
		end)
		out:Play()
	end
	local tap = Instance.new("TextButton")
	tap.BackgroundTransparency = 1
	tap.Size = UDim2.fromScale(1, 1)
	tap.Text = ""
	tap.ZIndex = 63
	tap.Parent = box
	tap.Activated:Connect(dismiss)
	task.delay(5, dismiss)
end

return GiftUI
