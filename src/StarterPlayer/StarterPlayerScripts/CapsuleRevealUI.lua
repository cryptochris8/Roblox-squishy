-- CapsuleRevealUI
-- The gentle "Discover a Friend" moment: a Sparkle Capsule wobbles, sparkles,
-- and reveals a card. Warm and celebratory, never gambling-flavored. Duplicates
-- are framed as a happy "Friendship Bonus" and shine the friend up a variant tier
-- (Sparkly -> Rainbow).

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiTheme = require(script.Parent.UiTheme)
local VariantConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("VariantConfig"))

local CapsuleRevealUI = {}

-- `layer` holds the full-screen dim; `stage` holds the capsule/card and is
-- wrapped in an auto-fit scale so the big reveal fits phone screens.
local screen, layer, stage
local busy = false

-- Safety net: even if a click is somehow swallowed, the reveal closes itself.
local AUTO_CLOSE_SECONDS = 12

local function isRealImage(id)
	return type(id) == "string" and id ~= "" and not string.find(id, "REPLACE_ME")
end

local function cardArt(parent, result)
	local art = Instance.new("Frame")
	art.Position = UDim2.fromOffset(20, 18)
	art.Size = UDim2.fromOffset(260, 200)
	art.BackgroundColor3 = UiTheme.rarityColor(result.rarity)
	art.BorderSizePixel = 0
	art.Parent = parent
	UiTheme.corner(16, art)
	UiTheme.gradient(Color3.fromRGB(255, 255, 255), UiTheme.rarityColor(result.rarity), 90, art)
	if isRealImage(result.imageAssetId) then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.ScaleType = Enum.ScaleType.Fit
		img.Image = result.imageAssetId
		img.Parent = art
	else
		local nameLbl = Instance.new("TextLabel")
		nameLbl.BackgroundTransparency = 1
		nameLbl.Size = UDim2.fromScale(1, 1)
		nameLbl.Font = UiTheme.HeaderFont
		nameLbl.TextSize = 24
		nameLbl.TextWrapped = true
		nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLbl.TextStrokeColor3 = UiTheme.Colors.Shade
		nameLbl.TextStrokeTransparency = 0.55
		nameLbl.Text = result.displayName
		nameLbl.Parent = art
	end
	return art
end

-- A little "✨ Sparkly" / "🌈 Rainbow" ribbon for variant reveals.
local function variantBadge(parent, icon, name, color, position)
	local vb = Instance.new("TextLabel")
	vb.AnchorPoint = Vector2.new(1, 0)
	vb.Position = position
	vb.Size = UDim2.fromOffset(118, 28)
	vb.BackgroundColor3 = color
	vb.BorderSizePixel = 0
	vb.Font = UiTheme.HeaderFont
	vb.TextSize = 15
	vb.TextColor3 = Color3.fromRGB(255, 255, 255)
	vb.Text = icon .. " " .. name
	vb.ZIndex = 4
	vb.Parent = parent
	UiTheme.corner(14, vb)
	UiTheme.stroke(Color3.fromRGB(255, 255, 255), 2, vb)
	return vb
end

function CapsuleRevealUI.play(result, onClose)
	if not layer or busy then
		return
	end
	busy = true
	layer:ClearAllChildren()
	stage:ClearAllChildren()

	local variantLevel = result.variantLevel or 0
	local variantUpgraded = result.variantUpgraded == true
	local variantName = VariantConfig.nameFor(variantLevel)
	local variantColor = VariantConfig.colorFor(variantLevel)
	local variantIcon = VariantConfig.iconFor(variantLevel)

	-- One safe way to close this reveal (tap "Yay!", tap outside, press Esc, an
	-- error, or the watchdog). Guarded so it only ever runs once per reveal.
	local closed = false
	-- The reveal can only be dismissed once the card + "Yay!" are actually shown, so
	-- the very tap/click/keypress that opened the capsule can't instantly close it.
	-- The watchdog and the error handler pass force=true so they can always clean up.
	local canDismiss = false
	local escConn: RBXScriptConnection? = nil
	local function dismiss(force: boolean?)
		if closed or (not force and not canDismiss) then
			return
		end
		closed = true
		busy = false
		if escConn then
			escConn:Disconnect()
			escConn = nil
		end
		if layer then
			layer:ClearAllChildren()
		end
		if stage then
			stage:ClearAllChildren()
		end
		if onClose then
			onClose()
		end
	end

	-- Watchdog: guarantees the reveal can never get permanently stuck on screen.
	task.delay(AUTO_CLOSE_SECONDS, function()
		dismiss(true)
	end)

	-- Keyboard fallback: Esc closes the reveal too.
	escConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.Escape and not gameProcessed then
			dismiss()
		end
	end)

	-- dim background (tap it to close). High ZIndex so it always sits on top of
	-- any other HUD and reliably receives the click.
	local dim = Instance.new("TextButton")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = UiTheme.Colors.Shade
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Text = ""
	dim.ZIndex = 1
	dim.AutoButtonColor = false
	dim.Active = true
	dim.Parent = layer
	dim.Activated:Connect(function() dismiss() end)
	dim.MouseButton1Click:Connect(function() dismiss() end)
	TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()

	-- the capsule
	local capsule = Instance.new("Frame")
	capsule.AnchorPoint = Vector2.new(0.5, 0.5)
	capsule.Position = UDim2.fromScale(0.5, 0.5)
	capsule.Size = UDim2.fromOffset(150, 150)
	capsule.BackgroundColor3 = UiTheme.rarityColor(result.rarity)
	capsule.BorderSizePixel = 0
	capsule.Parent = stage
	UiTheme.corner(75, capsule)
	UiTheme.stroke(Color3.fromRGB(255, 255, 255), 4, capsule)
	UiTheme.gradient(Color3.fromRGB(255, 255, 255), UiTheme.rarityColor(result.rarity), 90, capsule)

	-- wobble, then reveal the card. Wrapped so any hiccup can't strand the reveal.
	task.spawn(function()
		local ok, err = pcall(function()
			for i = 1, 3 do
				if closed then return end
				TweenService:Create(capsule, TweenInfo.new(0.12, Enum.EasingStyle.Sine), { Rotation = 12 }):Play()
				task.wait(0.12)
				TweenService:Create(capsule, TweenInfo.new(0.12, Enum.EasingStyle.Sine), { Rotation = -12 }):Play()
				task.wait(0.12)
			end
			if closed then return end
			TweenService:Create(capsule, TweenInfo.new(0.1), { Rotation = 0 }):Play()
			task.wait(0.12)

			-- pop the capsule away, bring the card in
			if closed then return end
			TweenService:Create(capsule, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = UDim2.fromOffset(0, 0),
			}):Play()
			task.wait(0.18)
			if closed then return end
			capsule:Destroy()

			if isRealImage(result.imageAssetId) then
				-- The full uploaded card render IS the reveal (it already has the
				-- name, rarity, stats, and number), so show it big with a headline.
				local bigHeadline = Instance.new("TextLabel")
				bigHeadline.AnchorPoint = Vector2.new(0.5, 0.5)
				bigHeadline.Position = UDim2.new(0.5, 0, 0.5, -250)
				bigHeadline.Size = UDim2.fromOffset(540, 40)
				bigHeadline.BackgroundTransparency = 1
				bigHeadline.Font = UiTheme.HeaderFont
				bigHeadline.TextSize = 28
				bigHeadline.TextColor3 = Color3.fromRGB(255, 255, 255)
				bigHeadline.TextStrokeColor3 = UiTheme.Colors.AccentDeep
				bigHeadline.TextStrokeTransparency = 0.15
				if result.giftFrom then
					bigHeadline.Text = "💝 A gift from " .. result.giftFrom .. "!"
				elseif result.isNew then
					bigHeadline.Text = "New Friend Discovered!"
				elseif variantUpgraded then
					bigHeadline.Text = variantIcon .. " " .. variantName .. "!   +" .. (result.bonusCoins or 0) .. " Sparkle Coins"
					bigHeadline.TextStrokeColor3 = variantColor
				elseif (result.bonusCoins or 0) > 0 then
					bigHeadline.Text = "Friendship Bonus!  +" .. result.bonusCoins .. " Sparkle Coins"
				else
					bigHeadline.Text = "Friendship Bonus!"
				end
				bigHeadline.Parent = stage

				local img = Instance.new("ImageLabel")
				img.AnchorPoint = Vector2.new(0.5, 0.5)
				img.Position = UDim2.fromScale(0.5, 0.5)
				img.Size = UDim2.fromOffset(0, 430)
				img.BackgroundTransparency = 1
				img.ScaleType = Enum.ScaleType.Fit
				img.Image = result.imageAssetId
				img.Parent = stage
				TweenService:Create(img, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.fromOffset(322, 430),
				}):Play()
				task.wait(0.32)

				if variantLevel >= 1 then
					variantBadge(stage, variantIcon, variantName, variantColor, UDim2.new(0.5, 150, 0.5, -210))
				end

				local bigYay = Instance.new("TextButton")
				bigYay.AnchorPoint = Vector2.new(0.5, 0.5)
				bigYay.Position = UDim2.new(0.5, 0, 0.5, 252)
				bigYay.Size = UDim2.fromOffset(200, 48)
				bigYay.BackgroundColor3 = UiTheme.Colors.AccentDeep
				bigYay.BorderSizePixel = 0
				bigYay.Font = UiTheme.HeaderFont
				bigYay.TextSize = 22
				bigYay.TextColor3 = Color3.fromRGB(255, 255, 255)
				bigYay.Text = "Yay!"
				bigYay.ZIndex = 5
				bigYay.Active = true
				bigYay.Parent = stage
				UiTheme.corner(24, bigYay)
				bigYay.Activated:Connect(function() dismiss() end)
				bigYay.MouseButton1Click:Connect(function() dismiss() end)
				canDismiss = true
				return
			end

			local card = UiTheme.panel({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(0, 380),
				BackgroundColor3 = UiTheme.Colors.Cream,
				radius = 22,
			})
			card.Parent = stage
			UiTheme.stroke(variantLevel >= 1 and variantColor or UiTheme.rarityColor(result.rarity), 4, card)

			-- flip-in (grow width)
			TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(300, 380),
			}):Play()
			task.wait(0.3)

			cardArt(card, result)
			if variantLevel >= 1 then
				variantBadge(card, variantIcon, variantName, variantColor, UDim2.fromOffset(280, 26))
			end

			local headline = Instance.new("TextLabel")
			headline.BackgroundTransparency = 1
			headline.Position = UDim2.fromOffset(12, 224)
			headline.Size = UDim2.new(1, -24, 0, 30)
			headline.Font = UiTheme.HeaderFont
			headline.TextSize = 24
			headline.TextColor3 = UiTheme.Colors.AccentDeep
			if result.giftFrom then
				headline.Text = "💝 A gift from " .. result.giftFrom .. "!"
			elseif result.isNew then
				headline.Text = "New Friend Discovered!"
			elseif variantUpgraded then
				headline.Text = variantIcon .. " " .. variantName .. "!"
				headline.TextColor3 = variantColor
			else
				headline.Text = "Friendship Bonus!"
			end
			headline.Parent = card

			local sub = Instance.new("TextLabel")
			sub.BackgroundTransparency = 1
			sub.Position = UDim2.fromOffset(12, 256)
			sub.Size = UDim2.new(1, -24, 0, 44)
			sub.Font = UiTheme.BodyFont
			sub.TextSize = 16
			sub.TextWrapped = true
			sub.TextColor3 = UiTheme.Colors.Ink
			if result.isNew then
				sub.Text = result.displayName .. " (" .. (result.cardNumber or "")
					.. ") joined your Squishy Book!"
			elseif variantUpgraded then
				sub.Text = result.displayName .. " is now " .. variantName .. "!  +"
					.. (result.bonusCoins or 0) .. " Sparkle Coins"
			else
				sub.Text = "You already know " .. result.displayName .. "!  +"
					.. (result.bonusCoins or 0) .. " Sparkle Coins"
			end
			sub.Parent = card

			local yay = Instance.new("TextButton")
			yay.AnchorPoint = Vector2.new(0.5, 1)
			yay.Position = UDim2.new(0.5, 0, 1, -16)
			yay.Size = UDim2.fromOffset(200, 48)
			yay.BackgroundColor3 = UiTheme.Colors.AccentDeep
			yay.BorderSizePixel = 0
			yay.Font = UiTheme.HeaderFont
			yay.TextSize = 22
			yay.TextColor3 = Color3.fromRGB(255, 255, 255)
			yay.Text = "Yay!"
			yay.ZIndex = 5
			yay.Active = true
			yay.Parent = card
			UiTheme.corner(24, yay)
			yay.Activated:Connect(function() dismiss() end)
			yay.MouseButton1Click:Connect(function() dismiss() end)
			canDismiss = true
		end)
		if not ok then
			warn("[CapsuleRevealUI] reveal failed: " .. tostring(err))
			dismiss(true)
		end
	end)
end

function CapsuleRevealUI.mount(playerGui)
	screen = Instance.new("ScreenGui")
	screen.Name = "CapsuleReveal"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.DisplayOrder = 60 -- above the HUD (0), Book (20) and Toast (50)
	screen.Parent = playerGui

	layer = Instance.new("Frame")
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.Parent = screen

	-- the reveal itself lives on a stage that shrinks to fit small screens
	-- (the headline sits ~270 above centre and the Yay! ~276 below = ~620 tall)
	stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.Size = UDim2.fromScale(1, 1)
	stage.BackgroundTransparency = 1
	stage.Parent = screen
	UiTheme.autoFit(stage, 560, 620)
end

return CapsuleRevealUI
