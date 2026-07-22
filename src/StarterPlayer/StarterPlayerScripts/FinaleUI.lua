-- FinaleUI
-- The storybook ending: a warm celebration when all three Sparkle shards are
-- recovered and the Sparkle is restored to the Squishy world.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiTheme = require(script.Parent.UiTheme)
local SoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundConfig"))

local FinaleUI = {}

local layer

function FinaleUI.mount(playerGui)
	local screen = Instance.new("ScreenGui")
	screen.Name = "SparkleFinale"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.DisplayOrder = 70 -- above everything else
	screen.Parent = playerGui

	layer = Instance.new("Frame")
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundColor3 = UiTheme.Colors.Shade
	layer.BackgroundTransparency = 1
	layer.Visible = false
	layer.Parent = screen
end

function FinaleUI.play(info)
	if not layer then
		return
	end
	info = info or {}
	layer:ClearAllChildren()
	layer.Visible = true
	layer.BackgroundTransparency = 1
	TweenService:Create(layer, TweenInfo.new(0.4), { BackgroundTransparency = 0.25 }):Play()

	if SoundConfig.FinaleRestore and SoundConfig.FinaleRestore ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = SoundConfig.FinaleRestore
		s.Volume = 0.7
		s.Parent = layer
		s:Play()
		Debris:AddItem(s, 6)
	end

	local panel = UiTheme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(0, 448),
		BackgroundColor3 = UiTheme.Colors.Cream,
		radius = 28,
	})
	panel.Parent = layer
	UiTheme.stroke(UiTheme.Colors.Coin, 4, panel)
	UiTheme.gradient(Color3.fromRGB(255, 246, 222), Color3.fromRGB(255, 220, 242), 120, panel)
	UiTheme.autoFit(panel, 580, 448)
	TweenService:Create(panel, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(580, 448),
	}):Play()

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 28)
	title.Size = UDim2.new(1, -40, 0, 50)
	title.Font = UiTheme.HeaderFont
	title.TextSize = 34
	title.TextColor3 = UiTheme.Colors.AccentDeep
	title.Text = "✨ The Sparkle Shines Again! ✨"
	title.TextScaled = false
	title.Parent = panel

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(36, 96)
	body.Size = UDim2.new(1, -72, 0, 150)
	body.Font = UiTheme.BodyFont
	body.TextSize = 21
	body.TextWrapped = true
	body.TextColor3 = UiTheme.Colors.Ink
	body.Text = "You found all three Sparkle shards and restored the Sparkle to the Squishy world! Pudding Hills, Goo Coast, and Moonlit Hollow are bright again. Thank you, friend. 💜"
	body.Parent = panel

	if (info.reward or 0) > 0 then
		local reward = Instance.new("TextLabel")
		reward.BackgroundTransparency = 1
		reward.Position = UDim2.fromOffset(20, 250)
		reward.Size = UDim2.new(1, -40, 0, 34)
		reward.Font = UiTheme.HeaderFont
		reward.TextSize = 24
		reward.TextColor3 = UiTheme.Colors.CoinDeep
		reward.Text = "🎉 +" .. info.reward .. " Sparkle Coins!"
		reward.Parent = panel
	end

	-- Game → book, at the highest-intent moment. Gentle, non-clickable, and
	-- "ask a grown-up" framed (kids never get sent off-platform themselves).
	local bookCard = Instance.new("TextLabel")
	bookCard.BackgroundColor3 = UiTheme.Colors.Panel
	bookCard.BackgroundTransparency = 0.15
	bookCard.Position = UDim2.fromOffset(36, 296)
	bookCard.Size = UDim2.new(1, -72, 0, 66)
	bookCard.Font = UiTheme.BodyFont
	bookCard.TextSize = 17
	bookCard.TextWrapped = true
	bookCard.TextColor3 = UiTheme.Colors.Ink
	bookCard.Text = "📖 You found the whole story! Read The Lost Sparkle with a grown-up — ask them to visit squishysmash.com"
	bookCard.Parent = panel
	UiTheme.corner(16, bookCard)

	local yay = Instance.new("TextButton")
	yay.AnchorPoint = Vector2.new(0.5, 1)
	yay.Position = UDim2.new(0.5, 0, 1, -22)
	yay.Size = UDim2.fromOffset(220, 52)
	yay.BackgroundColor3 = UiTheme.Colors.AccentDeep
	yay.BorderSizePixel = 0
	yay.Font = UiTheme.HeaderFont
	yay.TextSize = 24
	yay.TextColor3 = Color3.fromRGB(255, 255, 255)
	yay.Text = "Yay! 🌟"
	yay.Parent = panel
	UiTheme.corner(26, yay)
	yay.Activated:Connect(function()
		FinaleUI.hide()
	end)
end

function FinaleUI.hide()
	if layer then
		layer.Visible = false
		layer:ClearAllChildren()
	end
end

return FinaleUI
