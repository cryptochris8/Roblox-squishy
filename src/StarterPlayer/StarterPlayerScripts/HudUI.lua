-- HudUI
-- The always-on screen furniture: Sparkle Coins, friends-discovered count, the
-- current cozy quest, and a big round "Squishy Book" button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UiTheme = require(script.Parent.UiTheme)
local SparkleBitConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SparkleBitConfig"))

local HudUI = {}

local coinLabel, friendsLabel, bitsLabel, questFrame, questLabel
local dailyBtn, dailyPulse

local function coinPill(parent)
	local pill = UiTheme.panel({
		Name = "CoinPill",
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(176, 48),
		radius = 24,
	})
	pill.Parent = parent
	UiTheme.stroke(UiTheme.Colors.CoinDeep, 2, pill)

	local coin = Instance.new("Frame")
	coin.Size = UDim2.fromOffset(34, 34)
	coin.Position = UDim2.fromOffset(8, 7)
	coin.BackgroundColor3 = UiTheme.Colors.Coin
	coin.BorderSizePixel = 0
	coin.Parent = pill
	UiTheme.corner(17, coin)
	UiTheme.stroke(UiTheme.Colors.CoinDeep, 2, coin)
	-- a little shine
	local shine = Instance.new("Frame")
	shine.Size = UDim2.fromOffset(10, 10)
	shine.Position = UDim2.fromOffset(7, 6)
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.3
	shine.BorderSizePixel = 0
	shine.Parent = coin
	UiTheme.corner(5, shine)

	coinLabel = Instance.new("TextLabel")
	coinLabel.BackgroundTransparency = 1
	coinLabel.Position = UDim2.fromOffset(50, 0)
	coinLabel.Size = UDim2.new(1, -58, 1, 0)
	coinLabel.Font = UiTheme.HeaderFont
	coinLabel.TextSize = 22
	coinLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinLabel.TextColor3 = UiTheme.Colors.Ink
	coinLabel.Text = "0"
	coinLabel.Parent = pill
end

local function friendsPill(parent)
	local pill = UiTheme.panel({
		Name = "FriendsPill",
		Position = UDim2.fromOffset(16, 72),
		Size = UDim2.fromOffset(176, 40),
		radius = 20,
	})
	pill.Parent = parent
	UiTheme.stroke(UiTheme.Colors.Accent, 2, pill)

	friendsLabel = Instance.new("TextLabel")
	friendsLabel.BackgroundTransparency = 1
	friendsLabel.Size = UDim2.new(1, -20, 1, 0)
	friendsLabel.Position = UDim2.fromOffset(14, 0)
	friendsLabel.Font = UiTheme.HeaderFont
	friendsLabel.TextSize = 18
	friendsLabel.TextXAlignment = Enum.TextXAlignment.Left
	friendsLabel.TextColor3 = UiTheme.Colors.AccentDeep
	friendsLabel.Text = "Friends 0/48"
	friendsLabel.Parent = pill
end

local function bitsPill(parent)
	local pill = UiTheme.panel({
		Name = "BitsPill",
		Position = UDim2.fromOffset(16, 120),
		Size = UDim2.fromOffset(176, 40),
		radius = 20,
	})
	pill.Parent = parent
	UiTheme.stroke(UiTheme.Colors.Coin, 2, pill)

	bitsLabel = Instance.new("TextLabel")
	bitsLabel.BackgroundTransparency = 1
	bitsLabel.Size = UDim2.new(1, -20, 1, 0)
	bitsLabel.Position = UDim2.fromOffset(14, 0)
	bitsLabel.Font = UiTheme.HeaderFont
	bitsLabel.TextSize = 18
	bitsLabel.TextXAlignment = Enum.TextXAlignment.Left
	bitsLabel.TextColor3 = UiTheme.Colors.CoinDeep
	bitsLabel.Text = "✨ Bits 0/" .. SparkleBitConfig.count()
	bitsLabel.Parent = pill
end

local function questBanner(parent)
	questFrame = UiTheme.panel({
		Name = "QuestBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(480, 44),
		BackgroundColor3 = UiTheme.Colors.Accent,
		radius = 22,
	})
	questFrame.Visible = false
	questFrame.Parent = parent
	UiTheme.stroke(Color3.fromRGB(255, 255, 255), 2, questFrame)

	questLabel = Instance.new("TextLabel")
	questLabel.BackgroundTransparency = 1
	questLabel.Size = UDim2.fromScale(1, 1)
	questLabel.Font = UiTheme.HeaderFont
	questLabel.TextSize = 19
	questLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	questLabel.Text = ""
	questLabel.Parent = questFrame
end

local function dailyButton(parent, onClaimDaily)
	local btn = Instance.new("TextButton")
	btn.Name = "DailyGiftButton"
	btn.AnchorPoint = Vector2.new(0, 1)
	btn.Position = UDim2.new(0, 18, 1, -18)
	btn.Size = UDim2.fromOffset(214, 52)
	btn.BackgroundColor3 = UiTheme.Colors.Coin
	btn.BorderSizePixel = 0
	btn.Font = UiTheme.HeaderFont
	btn.TextSize = 20
	btn.TextColor3 = UiTheme.Colors.Ink
	btn.Text = "🎁 Free Daily Gift!"
	btn.AutoButtonColor = true
	btn.Parent = parent
	UiTheme.corner(24, btn)
	UiTheme.stroke(UiTheme.Colors.CoinDeep, 2, btn)
	dailyBtn = btn
	dailyPulse = TweenService:Create(btn, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Size = UDim2.fromOffset(226, 56),
	})
	btn.Activated:Connect(function()
		if onClaimDaily then
			onClaimDaily()
		end
	end)
end

local function bookButton(parent, onOpenBook)
	local btn = Instance.new("TextButton")
	btn.Name = "BookButton"
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.Position = UDim2.new(1, -18, 1, -18)
	btn.Size = UDim2.fromOffset(168, 56)
	btn.BackgroundColor3 = UiTheme.Colors.AccentDeep
	btn.BorderSizePixel = 0
	btn.Font = UiTheme.HeaderFont
	btn.TextSize = 22
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = "Squishy Book"
	btn.AutoButtonColor = true
	btn.Parent = parent
	UiTheme.corner(24, btn)
	UiTheme.stroke(Color3.fromRGB(255, 255, 255), 2, btn)
	btn.Activated:Connect(function()
		if onOpenBook then
			onOpenBook()
		end
	end)
end

function HudUI.mount(playerGui, onOpenBook, onClaimDaily)
	local screen = Instance.new("ScreenGui")
	screen.Name = "SquishyHUD"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.Parent = playerGui

	coinPill(screen)
	friendsPill(screen)
	bitsPill(screen)
	questBanner(screen)
	bookButton(screen, onOpenBook)
	dailyButton(screen, onClaimDaily)
end

function HudUI.update(state)
	if not coinLabel then
		return
	end
	coinLabel.Text = tostring(state.coins or 0)
	friendsLabel.Text = "Friends " .. (state.discoveredCount or 0) .. "/48"

	if bitsLabel then
		local found = 0
		if type(state.sparkleBits) == "table" then
			for _ in pairs(state.sparkleBits) do
				found += 1
			end
		end
		bitsLabel.Text = "✨ Bits " .. found .. "/" .. SparkleBitConfig.count()
	end

	if dailyBtn then
		local ready = state.dailyCapsuleReady == true
		dailyBtn.Text = ready and "🎁 Free Daily Gift!" or "🎁 Daily Gift  ✓"
		dailyBtn.BackgroundColor3 = ready and UiTheme.Colors.Coin or UiTheme.Colors.Panel
		dailyBtn.TextColor3 = ready and UiTheme.Colors.Ink or UiTheme.Colors.SoftInk
		dailyBtn.AutoButtonColor = ready
		if ready then
			dailyPulse:Play()
		else
			dailyPulse:Cancel()
			dailyBtn.Size = UDim2.fromOffset(214, 52)
		end
	end

	-- The Lost Shard quest is the main objective; it subsumes the tutorial (waking
	-- friends serves both). Falls back to the tutorial only if no quest data yet.
	local quest = state.quest
	if quest and not quest.shardCollected then
		questFrame.Visible = true
		if quest.shardRevealed then
			questLabel.Text = "✨ Recover the Lost Shard at the orchard!"
		else
			questLabel.Text = "Find the Lost Shard  —  wake " .. (quest.shardProgress or 0) .. " / " .. (quest.shardGoal or 8) .. " sleepy friends"
		end
	elseif quest then
		questFrame.Visible = false
	else
		local tutorial = state.tutorial
		if tutorial and not tutorial.done then
			questFrame.Visible = true
			questLabel.Text = "Wake up sleepy friends:  " .. (tutorial.popped or 0) .. " / " .. (tutorial.goal or 3)
		else
			questFrame.Visible = false
		end
	end
end

return HudUI
