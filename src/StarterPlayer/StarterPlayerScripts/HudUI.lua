-- HudUI
-- The always-on screen furniture: Sparkle Coins, friends-discovered count, the
-- current cozy quest, and the action buttons (Squishy Book, Daily Gift, Daily
-- Quests, Magic Words, Storybook).
--
-- Two layouts, one truth:
--  • Desktop / tablet — the roomy original: pill column top-left, big labeled
--    buttons bottom-left + bottom-right.
--  • Compact (phones) — slim pills, and the actions become a row of round
--    icon buttons pinned TOP-RIGHT, because Roblox's thumbstick owns the
--    bottom-left of a phone and the jump button owns the bottom-right.
-- The HUD rebuilds itself if the layout answer flips (rotation/test override).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UiTheme = require(script.Parent.UiTheme)
local SparkleBitConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SparkleBitConfig"))
local ZoneConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ZoneConfig"))
local SquishyData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SquishyData"))

local HudUI = {}

local screen -- the live ScreenGui (rebuilt on layout flips)
local mountedGui, callbacks
local lastState
local compactNow = false

local coinLabel, friendsLabel, bitsLabel, questFrame, questLabel
local dailyBtn, dailyPulse, dailyBaseSize
local coinPillScale -- UIScale on the coin pill, for the earn "bounce"
local prevCoins -- last coin total shown (nil until the first sync)
local countUpToken = 0 -- cancels an in-flight count-up when a newer one starts

local function coinPill(parent, C)
	local pill = UiTheme.panel({
		Name = "CoinPill",
		Position = C and UDim2.fromOffset(10, 8) or UDim2.fromOffset(16, 16),
		Size = C and UDim2.fromOffset(130, 34) or UDim2.fromOffset(176, 48),
		radius = C and 17 or 24,
	})
	pill.Parent = parent
	UiTheme.stroke(UiTheme.Colors.CoinDeep, 2, pill)
	coinPillScale = Instance.new("UIScale")
	coinPillScale.Name = "EarnBounce"
	coinPillScale.Parent = pill

	local d = C and 24 or 34
	local coin = Instance.new("Frame")
	coin.Size = UDim2.fromOffset(d, d)
	coin.Position = C and UDim2.fromOffset(5, 5) or UDim2.fromOffset(8, 7)
	coin.BackgroundColor3 = UiTheme.Colors.Coin
	coin.BorderSizePixel = 0
	coin.Parent = pill
	UiTheme.corner(d // 2, coin)
	UiTheme.stroke(UiTheme.Colors.CoinDeep, 2, coin)
	-- a little shine
	local shine = Instance.new("Frame")
	shine.Size = C and UDim2.fromOffset(7, 7) or UDim2.fromOffset(10, 10)
	shine.Position = C and UDim2.fromOffset(5, 4) or UDim2.fromOffset(7, 6)
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.3
	shine.BorderSizePixel = 0
	shine.Parent = coin
	UiTheme.corner(4, shine)

	coinLabel = Instance.new("TextLabel")
	coinLabel.BackgroundTransparency = 1
	coinLabel.Position = C and UDim2.fromOffset(36, 0) or UDim2.fromOffset(50, 0)
	coinLabel.Size = UDim2.new(1, C and -42 or -58, 1, 0)
	coinLabel.Font = UiTheme.HeaderFont
	coinLabel.TextSize = C and 17 or 22
	coinLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinLabel.TextColor3 = UiTheme.Colors.Ink
	coinLabel.Text = "0"
	coinLabel.Parent = pill
end

local function statPill(parent, C, name, y, yC, strokeColor)
	local pill = UiTheme.panel({
		Name = name,
		Position = C and UDim2.fromOffset(10, yC) or UDim2.fromOffset(16, y),
		Size = C and UDim2.fromOffset(130, 28) or UDim2.fromOffset(176, 40),
		radius = C and 14 or 20,
	})
	pill.Parent = parent
	UiTheme.stroke(strokeColor, 2, pill)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -20, 1, 0)
	label.Position = UDim2.fromOffset(C and 10 or 14, 0)
	label.Font = UiTheme.HeaderFont
	label.TextSize = C and 13 or 18
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = pill
	return label
end

local function questBanner(parent, C)
	questFrame = UiTheme.panel({
		Name = "QuestBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = C and UDim2.new(0.5, 0, 0, 6) or UDim2.new(0.5, 0, 0, 16),
		Size = C and UDim2.new(1, -380, 0, 32) or UDim2.fromOffset(480, 44),
		BackgroundColor3 = UiTheme.Colors.Accent,
		radius = C and 16 or 22,
	})
	questFrame.Visible = false
	questFrame.Parent = parent
	UiTheme.stroke(Color3.fromRGB(255, 255, 255), 2, questFrame)
	if C then
		-- a phone banner can't be wider than the gap between the pill column
		-- and the icon row, but never thinner than a readable ribbon
		local sizeCap = Instance.new("UISizeConstraint")
		sizeCap.MinSize = Vector2.new(230, 32)
		sizeCap.MaxSize = Vector2.new(440, 32)
		sizeCap.Parent = questFrame
	end

	questLabel = Instance.new("TextLabel")
	questLabel.BackgroundTransparency = 1
	questLabel.Size = UDim2.new(1, -16, 1, 0)
	questLabel.Position = UDim2.fromOffset(8, 0)
	questLabel.Font = UiTheme.HeaderFont
	questLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	questLabel.Text = ""
	if C then
		questLabel.TextScaled = true
		local cap = Instance.new("UITextSizeConstraint")
		cap.MinTextSize = 9
		cap.MaxTextSize = 15
		cap.Parent = questLabel
	else
		questLabel.TextSize = 19
	end
	questLabel.Parent = questFrame
end

-- One desktop action button (the original big labeled kind, bottom-left).
local function bigButton(parent, name, text, yFromBottom, h, textSize, bg, fg, onTap)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.AnchorPoint = Vector2.new(0, 1)
	btn.Position = UDim2.new(0, 18, 1, -yFromBottom)
	btn.Size = UDim2.fromOffset(214, h)
	btn.BackgroundColor3 = bg
	btn.BorderSizePixel = 0
	btn.Font = UiTheme.HeaderFont
	btn.TextSize = textSize
	btn.TextColor3 = fg
	btn.Text = text
	btn.AutoButtonColor = true
	btn.Parent = parent
	UiTheme.corner(h // 2 - 2, btn)
	UiTheme.stroke(Color3.fromRGB(255, 255, 255), 2, btn)
	btn.Activated:Connect(function()
		if onTap then
			onTap()
		end
	end)
	return btn
end

-- One compact action button (a round emoji icon). Phones stack these in a single
-- column down the RIGHT EDGE — bigger + clearly spaced, clear of the center quest
-- banner and the jump button.
local function iconButton(parent, name, emoji, yFromTop, bg, onTap)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.AnchorPoint = Vector2.new(1, 0)
	btn.Position = UDim2.new(1, -12, 0, yFromTop)
	btn.Size = UDim2.fromOffset(48, 48)
	btn.BackgroundColor3 = bg
	btn.BorderSizePixel = 0
	btn.Font = UiTheme.HeaderFont
	btn.TextSize = 24
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = emoji
	btn.AutoButtonColor = true
	btn.Parent = parent
	UiTheme.corner(16, btn)
	UiTheme.stroke(Color3.fromRGB(255, 255, 255), 2, btn)
	btn.Activated:Connect(function()
		if onTap then
			onTap()
		end
	end)
	return btn
end

-- Owner-only playtest tool: "Reset My Progress" with a confirm step. The
-- trigger button moves per layout; the confirm overlay is shared.
local function resetTrigger(parent, C, onReset)
	local btn = Instance.new("TextButton")
	btn.Name = "ResetButton"
	if C then
		btn.AnchorPoint = Vector2.new(0.5, 0)
		btn.Position = UDim2.new(0.5, 0, 0, 42)
		btn.Size = UDim2.fromOffset(34, 24)
		btn.TextSize = 12
		btn.Text = "🔄"
	else
		btn.AnchorPoint = Vector2.new(0.5, 1)
		btn.Position = UDim2.new(0.5, 0, 1, -16)
		btn.Size = UDim2.fromOffset(184, 32)
		btn.TextSize = 14
		btn.Text = "🔄 Reset My Progress"
	end
	btn.BackgroundColor3 = Color3.fromRGB(150, 120, 140)
	btn.BackgroundTransparency = 0.2
	btn.BorderSizePixel = 0
	btn.Font = UiTheme.BodyFont
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Parent = parent
	UiTheme.corner(C and 10 or 16, btn)

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
	UiTheme.autoFit(box, 400, 196)

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
local function ownerDemoButtons(parent, C, onOwnerDebug)
	local function demoBtn(text, pos, size, textSize, action)
		local btn = Instance.new("TextButton")
		btn.Name = "Demo" .. action
		btn.AnchorPoint = C and Vector2.new(0.5, 0) or Vector2.new(0.5, 1)
		btn.Position = pos
		btn.Size = size
		btn.BackgroundColor3 = Color3.fromRGB(150, 120, 140)
		btn.BackgroundTransparency = 0.2
		btn.BorderSizePixel = 0
		btn.Font = UiTheme.BodyFont
		btn.TextSize = textSize
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Text = text
		btn.Parent = parent
		UiTheme.corner(C and 10 or 16, btn)
		btn.Activated:Connect(function()
			if onOwnerDebug then
				onOwnerDebug(action)
			end
		end)
	end
	if C then
		demoBtn("🌟", UDim2.new(0.5, -40, 0, 42), UDim2.fromOffset(34, 24), 12, "startEvent")
		demoBtn("✨", UDim2.new(0.5, 40, 0, 42), UDim2.fromOffset(34, 24), 12, "startSurge")
	else
		demoBtn("🌟 Event", UDim2.new(0.5, -150, 1, -16), UDim2.fromOffset(92, 32), 14, "startEvent")
		demoBtn("✨ Surge", UDim2.new(0.5, 150, 1, -16), UDim2.fromOffset(92, 32), 14, "startSurge")
	end
end

-- Count the coin number UP to its new value (a satisfying little tally) and
-- bounce the pill. A newer earn cancels an older tally so they never fight.
local function animateCoins(from, to)
	countUpToken += 1
	local token = countUpToken
	local label = coinLabel
	local start = os.clock()
	local dur = 0.4
	task.spawn(function()
		while token == countUpToken and label and label.Parent do
			local k = math.min(1, (os.clock() - start) / dur)
			local eased = 1 - (1 - k) * (1 - k)
			label.Text = tostring(math.floor(from + (to - from) * eased + 0.5))
			if k >= 1 then
				break
			end
			task.wait()
		end
		if token == countUpToken and label and label.Parent then
			label.Text = tostring(to)
		end
	end)
end

local function bounceCoinPill()
	local scale = coinPillScale
	if not scale then
		return
	end
	scale.Scale = 1
	local up = TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.15 })
	up.Completed:Connect(function()
		if scale and scale.Parent then
			TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 1 }):Play()
		end
	end)
	up:Play()
end

-- Builds the whole HUD for the current layout. Destroys any previous build.
local function build()
	if screen then
		screen:Destroy()
	end
	local C = UiTheme.isCompact()
	compactNow = C

	screen = Instance.new("ScreenGui")
	screen.Name = "SquishyHUD"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.Parent = mountedGui

	coinPill(screen, C)
	friendsLabel = statPill(screen, C, "FriendsPill", 72, 46, UiTheme.Colors.Accent)
	friendsLabel.TextColor3 = UiTheme.Colors.AccentDeep
	friendsLabel.Text = "Friends 0/48"
	bitsLabel = statPill(screen, C, "BitsPill", 120, 78, UiTheme.Colors.Coin)
	bitsLabel.TextColor3 = UiTheme.Colors.CoinDeep
	bitsLabel.Text = "✨ Bits 0/" .. SparkleBitConfig.count()
	questBanner(screen, C)

	if C then
		-- top-right icon row (right to left), clear of the jump button
		local book = iconButton(screen, "BookButton", "📕", 8, UiTheme.Colors.AccentDeep, callbacks.onOpenBook)
		book.TextSize = 28
		dailyBtn = iconButton(screen, "DailyGiftButton", "🎁", 62, UiTheme.Colors.Coin, callbacks.onClaimDaily)
		dailyBtn.TextColor3 = UiTheme.Colors.Ink
		iconButton(screen, "DailyQuestsButton", "📋", 116, UiTheme.Colors.Accent, callbacks.onOpenDaily)
		iconButton(screen, "CodesButton", "🎟️", 170, Color3.fromRGB(190, 160, 235), callbacks.onOpenCodes)
		iconButton(screen, "StorybookButton", "📖", 224, Color3.fromRGB(240, 160, 40), callbacks.onOpenStorybook)
		dailyBaseSize = UDim2.fromOffset(48, 48)
		dailyPulse = TweenService:Create(dailyBtn, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Size = UDim2.fromOffset(54, 54),
		})
	else
		-- the original roomy buttons
		local book = Instance.new("TextButton")
		book.Name = "BookButton"
		book.AnchorPoint = Vector2.new(1, 1)
		book.Position = UDim2.new(1, -18, 1, -18)
		book.Size = UDim2.fromOffset(168, 56)
		book.BackgroundColor3 = UiTheme.Colors.AccentDeep
		book.BorderSizePixel = 0
		book.Font = UiTheme.HeaderFont
		book.TextSize = 22
		book.TextColor3 = Color3.fromRGB(255, 255, 255)
		book.Text = "Squishy Book"
		book.AutoButtonColor = true
		book.Parent = screen
		UiTheme.corner(24, book)
		UiTheme.stroke(Color3.fromRGB(255, 255, 255), 2, book)
		book.Activated:Connect(function()
			if callbacks.onOpenBook then
				callbacks.onOpenBook()
			end
		end)

		dailyBtn = bigButton(screen, "DailyGiftButton", "🎁 Free Daily Gift!", 18, 52, 20,
			UiTheme.Colors.Coin, UiTheme.Colors.Ink, callbacks.onClaimDaily)
		dailyBaseSize = UDim2.fromOffset(214, 52)
		dailyPulse = TweenService:Create(dailyBtn, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Size = UDim2.fromOffset(226, 56),
		})
		bigButton(screen, "DailyQuestsButton", "📋 Daily Quests", 78, 46, 18,
			UiTheme.Colors.AccentDeep, Color3.fromRGB(255, 255, 255), callbacks.onOpenDaily)
		bigButton(screen, "CodesButton", "🎟️ Magic Words", 132, 40, 17,
			Color3.fromRGB(190, 160, 235), Color3.fromRGB(255, 255, 255), callbacks.onOpenCodes)
		bigButton(screen, "StorybookButton", "📖 Storybook", 180, 40, 17,
			Color3.fromRGB(240, 160, 40), Color3.fromRGB(255, 255, 255), callbacks.onOpenStorybook)
	end

	-- These tools only ever appear for the place owner (you) — never the kids.
	if game.CreatorType == Enum.CreatorType.User and Players.LocalPlayer.UserId == game.CreatorId then
		resetTrigger(screen, C, callbacks.onResetProgress)
		ownerDemoButtons(screen, C, callbacks.onOwnerDebug)
	end

	if lastState then
		HudUI.update(lastState)
	end
end

function HudUI.mount(playerGui, onOpenBook, onClaimDaily, onOpenDaily, onResetProgress, onOwnerDebug, onOpenCodes, onOpenStorybook)
	mountedGui = playerGui
	callbacks = {
		onOpenBook = onOpenBook,
		onClaimDaily = onClaimDaily,
		onOpenDaily = onOpenDaily,
		onResetProgress = onResetProgress,
		onOwnerDebug = onOwnerDebug,
		onOpenCodes = onOpenCodes,
		onOpenStorybook = onOpenStorybook,
	}
	build()

	-- Rotation / resize / the test override can flip the layout answer.
	local pending = false
	UiTheme.onLayoutMaybeChanged(function()
		if pending then
			return
		end
		pending = true
		task.defer(function()
			pending = false
			if UiTheme.isCompact() ~= compactNow then
				build()
			end
		end)
	end)
end

function HudUI.update(state)
	if not coinLabel then
		return
	end
	lastState = state
	local newCoins = state.coins or 0
	if prevCoins ~= nil and newCoins > prevCoins then
		animateCoins(prevCoins, newCoins) -- coins went UP: tally + bounce
		bounceCoinPill()
	else
		coinLabel.Text = tostring(newCoins) -- first sync, or a spend: just show it
	end
	prevCoins = newCoins
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
		if compactNow then
			dailyBtn.Text = ready and "🎁" or "✓"
			dailyBtn.TextSize = ready and 24 or 20
		else
			dailyBtn.Text = ready and "🎁 Free Daily Gift!" or "🎁 Daily Gift  ✓"
		end
		dailyBtn.BackgroundColor3 = ready and UiTheme.Colors.Coin or UiTheme.Colors.Panel
		dailyBtn.TextColor3 = ready and UiTheme.Colors.Ink or UiTheme.Colors.SoftInk
		dailyBtn.AutoButtonColor = ready
		if ready then
			dailyPulse:Play()
		else
			dailyPulse:Cancel()
			dailyBtn.Size = dailyBaseSize
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
