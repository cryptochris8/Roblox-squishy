-- HudUI
-- The always-on screen furniture: Sparkle Coins, friends-discovered count, the
-- current cozy quest, and a big round "Squishy Book" button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UiTheme = require(script.Parent.UiTheme)
local SparkleBitConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SparkleBitConfig"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ZoneConfig"))
local SquishyData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SquishyData"))

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

-- The little "magic word" door (storybook promo codes).
local function codesButton(parent, onOpenCodes)
	local btn = Instance.new("TextButton")
	btn.Name = "CodesButton"
	btn.AnchorPoint = Vector2.new(0, 1)
	btn.Position = UDim2.new(0, 18, 1, -132)
	btn.Size = UDim2.fromOffset(214, 40)
	btn.BackgroundColor3 = Color3.fromRGB(190, 160, 235)
	btn.BorderSizePixel = 0
	btn.Font = UiTheme.HeaderFont
	btn.TextSize = 17
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = "🎟️ Magic Words"
	btn.AutoButtonColor = true
	btn.Parent = parent
	UiTheme.corner(20, btn)
	UiTheme.stroke(Color3.fromRGB(255, 255, 255), 2, btn)
	btn.Activated:Connect(function()
		if onOpenCodes then
			onOpenCodes()
		end
	end)
end

local function dailyQuestsButton(parent, onOpenDaily)
	local btn = Instance.new("TextButton")
	btn.Name = "DailyQuestsButton"
	btn.AnchorPoint = Vector2.new(0, 1)
	btn.Position = UDim2.new(0, 18, 1, -78)
	btn.Size = UDim2.fromOffset(214, 46)
	btn.BackgroundColor3 = UiTheme.Colors.AccentDeep
	btn.BorderSizePixel = 0
	btn.Font = UiTheme.HeaderFont
	btn.TextSize = 18
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = "📋 Daily Quests"
	btn.AutoButtonColor = true
	btn.Parent = parent
	UiTheme.corner(22, btn)
	UiTheme.stroke(Color3.fromRGB(255, 255, 255), 2, btn)
	btn.Activated:Connect(function()
		if onOpenDaily then
			onOpenDaily()
		end
	end)
end

-- Owner-only playtest tool: a small "Reset My Progress" button with a confirm step.
local function resetButton(parent, onReset)
	local btn = Instance.new("TextButton")
	btn.Name = "ResetButton"
	btn.AnchorPoint = Vector2.new(0.5, 1)
	btn.Position = UDim2.new(0.5, 0, 1, -16)
	btn.Size = UDim2.fromOffset(184, 32)
	btn.BackgroundColor3 = Color3.fromRGB(150, 120, 140)
	btn.BackgroundTransparency = 0.2
	btn.BorderSizePixel = 0
	btn.Font = UiTheme.BodyFont
	btn.TextSize = 14
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = "🔄 Reset My Progress"
	btn.Parent = parent
	UiTheme.corner(16, btn)

	local overlay = Instance.new("TextButton")
	overlay.Name = "ResetConfirm"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = UiTheme.Colors.Shade
	overlay.BackgroundTransparency = 0.4
	overlay.AutoButtonColor = false
	overlay.Text = ""
	overlay.Visible = false
	overlay.ZIndex = 40
	overlay.Parent = parent

	local box = UiTheme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(400, 196),
		BackgroundColor3 = UiTheme.Colors.Cream,
		radius = 20,
	})
	box.Active = true -- consume clicks so tapping the box doesn't count as "outside"
	box.ZIndex = 41
	box.Parent = overlay
	UiTheme.stroke(UiTheme.Colors.AccentDeep, 3, box)

	local msg = Instance.new("TextLabel")
	msg.BackgroundTransparency = 1
	msg.Position = UDim2.fromOffset(22, 24)
	msg.Size = UDim2.fromOffset(356, 84)
	msg.Font = UiTheme.HeaderFont
	msg.TextSize = 20
	msg.TextWrapped = true
	msg.TextColor3 = UiTheme.Colors.Ink
	msg.Text = "Reset ALL your progress and start over from the very beginning?"
	msg.ZIndex = 42
	msg.Parent = box

	local function actionBtn(text, x, color)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(x, 0, 1, -18)
		b.Size = UDim2.fromOffset(162, 46)
		b.BackgroundColor3 = color
		b.BorderSizePixel = 0
		b.Font = UiTheme.HeaderFont
		b.TextSize = 19
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Text = text
		b.ZIndex = 42
		b.Parent = box
		UiTheme.corner(22, b)
		return b
	end
	local cancel = actionBtn("Cancel", 0.29, UiTheme.Colors.Accent)
	local confirm = actionBtn("Reset", 0.71, Color3.fromRGB(214, 122, 150))

	btn.Activated:Connect(function() overlay.Visible = true end)
	cancel.Activated:Connect(function() overlay.Visible = false end)
	overlay.Activated:Connect(function() overlay.Visible = false end) -- tap outside = cancel
	confirm.Activated:Connect(function()
		overlay.Visible = false
		if onReset then
			onReset()
		end
	end)
end

-- Owner-only playtest tools: trigger the shared-world moments on cue (great for
-- demoing a Surge or an Everybody Squish to the kids without waiting on timers).
local function ownerDemoButtons(parent, onOwnerDebug)
	local function demoBtn(text, xOffset, action)
		local btn = Instance.new("TextButton")
		btn.Name = "Demo" .. action
		btn.AnchorPoint = Vector2.new(0.5, 1)
		btn.Position = UDim2.new(0.5, xOffset, 1, -16)
		btn.Size = UDim2.fromOffset(92, 32)
		btn.BackgroundColor3 = Color3.fromRGB(150, 120, 140)
		btn.BackgroundTransparency = 0.2
		btn.BorderSizePixel = 0
		btn.Font = UiTheme.BodyFont
		btn.TextSize = 14
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Text = text
		btn.Parent = parent
		UiTheme.corner(16, btn)
		btn.Activated:Connect(function()
			if onOwnerDebug then
				onOwnerDebug(action)
			end
		end)
	end
	demoBtn("🌟 Event", -150, "startEvent")
	demoBtn("✨ Surge", 150, "startSurge")
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

function HudUI.mount(playerGui, onOpenBook, onClaimDaily, onOpenDaily, onResetProgress, onOwnerDebug, onOpenCodes)
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
	dailyQuestsButton(screen, onOpenDaily)
	codesButton(screen, onOpenCodes)

	-- These tools only ever appear for the place owner (you) — never the kids.
	if game.CreatorType == Enum.CreatorType.User and Players.LocalPlayer.UserId == game.CreatorId then
		resetButton(screen, onResetProgress)
		ownerDemoButtons(screen, onOwnerDebug)
	end
end

function HudUI.update(state)
	if not coinLabel then
		return
	end
	coinLabel.Text = tostring(state.coins or 0)
	-- count LAUNCH friends only (event friends live in the Book's Events tab,
	-- so this pill can never read 49/48)
	local launchCount = 0
	if type(state.discovered) == "table" then
		for id in pairs(state.discovered) do
			local def = SquishyData.getById(id)
			if def and def.ReleaseType == "launch" then
				launchCount += 1
			end
		end
	end
	friendsLabel.Text = "Friends " .. launchCount .. "/48"

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

	-- Shard quest objective = the first land whose Sparkle shard isn't recovered yet.
	local shards = state.shards
	if shards then
		local target, targetCfg = nil, nil
		for _, zoneName in ipairs(ZoneConfig.Order) do
			local s = shards[zoneName]
			if s and not s.collected then
				target, targetCfg = zoneName, ZoneConfig.get(zoneName)
				break
			end
		end
		if target and targetCfg then
			questFrame.Visible = true
			local s = shards[target]
			local prog = math.min((s and s.progress) or 0, targetCfg.shardWakeGoal)
			if prog >= targetCfg.shardWakeGoal then
				questLabel.Text = "✨ Recover the " .. target .. " Shard!"
			else
				questLabel.Text = target .. " Shard  —  wake " .. prog .. " / " .. targetCfg.shardWakeGoal .. " sleepy friends"
			end
		else
			questFrame.Visible = false -- every shard recovered
		end
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
