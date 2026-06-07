-- CapsuleRevealUI
-- The gentle "Discover a Friend" moment: a Sparkle Capsule wobbles, sparkles,
-- and reveals a card. Warm and celebratory, never gambling-flavored. Duplicates
-- are framed as a happy "Friendship Bonus".

local TweenService = game:GetService("TweenService")
local UiTheme = require(script.Parent.UiTheme)

local CapsuleRevealUI = {}

local screen, layer
local busy = false

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

function CapsuleRevealUI.play(result, onClose)
	if not layer or busy then
		return
	end
	busy = true
	layer:ClearAllChildren()

	-- One safe way to close this reveal (tap "Yay!", tap outside, error, or a
	-- watchdog). Guarded so it only ever runs once per reveal.
	local closed = false
	local function dismiss()
		if closed then
			return
		end
		closed = true
		busy = false
		if layer then
			layer:ClearAllChildren()
		end
		if onClose then
			onClose()
		end
	end
	-- dim background (tap it to close)
	local dim = Instance.new("TextButton")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = UiTheme.Colors.Shade
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Parent = layer
	dim.Activated:Connect(dismiss)
	TweenService:Create(dim, TweenInfo.new(0.25), { BackgroundTransparency = 0.45 }):Play()

	-- the capsule
	local capsule = Instance.new("Frame")
	capsule.AnchorPoint = Vector2.new(0.5, 0.5)
	capsule.Position = UDim2.fromScale(0.5, 0.5)
	capsule.Size = UDim2.fromOffset(150, 150)
	capsule.BackgroundColor3 = UiTheme.rarityColor(result.rarity)
	capsule.BorderSizePixel = 0
	capsule.Parent = layer
	UiTheme.corner(75, capsule)
	UiTheme.stroke(Color3.fromRGB(255, 255, 255), 4, capsule)
	UiTheme.gradient(Color3.fromRGB(255, 255, 255), UiTheme.rarityColor(result.rarity), 90, capsule)

	-- wobble, then reveal the card. Wrapped so any hiccup can't strand the reveal.
	task.spawn(function()
		local ok, err = pcall(function()
			for i = 1, 3 do
				TweenService:Create(capsule, TweenInfo.new(0.12, Enum.EasingStyle.Sine), { Rotation = 12 }):Play()
				task.wait(0.12)
				TweenService:Create(capsule, TweenInfo.new(0.12, Enum.EasingStyle.Sine), { Rotation = -12 }):Play()
				task.wait(0.12)
			end
			TweenService:Create(capsule, TweenInfo.new(0.1), { Rotation = 0 }):Play()
			task.wait(0.12)

			-- pop the capsule away, bring the card in
			TweenService:Create(capsule, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = UDim2.fromOffset(0, 0),
			}):Play()
			task.wait(0.18)
			capsule:Destroy()

			local card = UiTheme.panel({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(0, 380),
				BackgroundColor3 = UiTheme.Colors.Cream,
				radius = 22,
			})
			card.Parent = layer
			UiTheme.stroke(UiTheme.rarityColor(result.rarity), 4, card)

			-- flip-in (grow width)
			TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(300, 380),
			}):Play()
			task.wait(0.3)

			cardArt(card, result)

			local headline = Instance.new("TextLabel")
			headline.BackgroundTransparency = 1
			headline.Position = UDim2.fromOffset(12, 224)
			headline.Size = UDim2.new(1, -24, 0, 30)
			headline.Font = UiTheme.HeaderFont
			headline.TextSize = 24
			headline.TextColor3 = UiTheme.Colors.AccentDeep
			headline.Text = result.isNew and "New Friend Discovered!" or "Friendship Bonus!"
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
			yay.Parent = card
			UiTheme.corner(24, yay)
			yay.Activated:Connect(dismiss)
		end)
		if not ok then
			warn("[CapsuleRevealUI] reveal failed: " .. tostring(err))
			dismiss()
		end
	end)
end

function CapsuleRevealUI.mount(playerGui)
	screen = Instance.new("ScreenGui")
	screen.Name = "CapsuleReveal"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.DisplayOrder = 40
	screen.Parent = playerGui

	layer = Instance.new("Frame")
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.Parent = screen
end

return CapsuleRevealUI
