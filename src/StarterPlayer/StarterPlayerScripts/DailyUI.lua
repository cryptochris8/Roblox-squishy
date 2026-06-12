-- DailyUI
-- A cozy "Today" panel: your gentle login streak + the 3 rotating daily quests
-- with progress bars. Quests auto-reward on completion (server-side), so this is a
-- read-only tracker. The active set is derived from the day index in StateSync.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyQuestConfig = require(Shared:WaitForChild("DailyQuestConfig"))
local UiTheme = require(script.Parent.UiTheme)

local DailyUI = {}

local root, panel, streakLabel
local questRows = {}
local lastState = nil

local function makeRow(parent, index)
	local frame = UiTheme.panel({
		Name = "Quest" .. index,
		Position = UDim2.fromOffset(20, 100 + (index - 1) * 96),
		Size = UDim2.fromOffset(440, 84),
		BackgroundColor3 = UiTheme.Colors.Panel,
		radius = 16,
	})
	frame.Parent = parent

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(16, 10)
	text.Size = UDim2.fromOffset(330, 26)
	text.Font = UiTheme.HeaderFont
	text.TextSize = 19
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextColor3 = UiTheme.Colors.Ink
	text.Text = ""
	text.Parent = frame

	local reward = Instance.new("TextLabel")
	reward.BackgroundTransparency = 1
	reward.AnchorPoint = Vector2.new(1, 0)
	reward.Position = UDim2.new(1, -16, 0, 10)
	reward.Size = UDim2.fromOffset(90, 26)
	reward.Font = UiTheme.HeaderFont
	reward.TextSize = 18
	reward.TextXAlignment = Enum.TextXAlignment.Right
	reward.TextColor3 = UiTheme.Colors.CoinDeep
	reward.Text = ""
	reward.Parent = frame

	local barBg = Instance.new("Frame")
	barBg.Position = UDim2.fromOffset(16, 48)
	barBg.Size = UDim2.fromOffset(330, 20)
	barBg.BackgroundColor3 = UiTheme.Colors.Shade
	barBg.BackgroundTransparency = 0.7
	barBg.BorderSizePixel = 0
	barBg.Parent = frame
	UiTheme.corner(10, barBg)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = UiTheme.Colors.Accent
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	UiTheme.corner(10, fill)

	local prog = Instance.new("TextLabel")
	prog.BackgroundTransparency = 1
	prog.AnchorPoint = Vector2.new(1, 0.5)
	prog.Position = UDim2.new(1, -14, 0, 58)
	prog.Size = UDim2.fromOffset(90, 24)
	prog.Font = UiTheme.HeaderFont
	prog.TextSize = 16
	prog.TextXAlignment = Enum.TextXAlignment.Right
	prog.TextColor3 = UiTheme.Colors.SoftInk
	prog.Text = ""
	prog.Parent = frame

	return { frame = frame, text = text, reward = reward, fill = fill, prog = prog }
end

function DailyUI.update(state)
	lastState = state
	if not root then
		return
	end
	local daily = state and state.daily
	if not daily then
		return
	end
	streakLabel.Text = "🔥 Day " .. (daily.streak or 0) .. " streak  —  come back tomorrow to keep it going!"
	local active = DailyQuestConfig.forDay(daily.day or 0)
	for i, row in ipairs(questRows) do
		local q = active[i]
		if q then
			row.frame.Visible = true
			local prog = math.min((daily.progress and daily.progress[q.id]) or 0, q.goal)
			local done = daily.claimed and daily.claimed[q.id] == true
			row.text.Text = string.format(q.text, q.goal)
			row.reward.Text = "+" .. q.reward
			row.fill.Size = UDim2.fromScale(q.goal > 0 and (prog / q.goal) or 0, 1)
			row.fill.BackgroundColor3 = done and UiTheme.Colors.Coin or UiTheme.Colors.Accent
			row.prog.Text = done and "✓ Done!" or (prog .. " / " .. q.goal)
			row.prog.TextColor3 = done and UiTheme.Colors.CoinDeep or UiTheme.Colors.SoftInk
		else
			row.frame.Visible = false
		end
	end
end

function DailyUI.show()
	if not root then
		return
	end
	root.Visible = true
	if lastState then
		DailyUI.update(lastState)
	end
	root.BackgroundTransparency = 1
	TweenService:Create(root, TweenInfo.new(0.2), { BackgroundTransparency = 0.15 }):Play()
end

function DailyUI.hide()
	if root then
		root.Visible = false
	end
end

function DailyUI.mount(playerGui)
	local screen = Instance.new("ScreenGui")
	screen.Name = "SquishyDaily"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.DisplayOrder = 25
	screen.Parent = playerGui

	root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = UiTheme.Colors.Shade
	root.BackgroundTransparency = 0.15
	root.BorderSizePixel = 0
	root.Visible = false
	root.Parent = screen

	panel = UiTheme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(480, 420),
		BackgroundColor3 = UiTheme.Colors.Cream,
		radius = 24,
	})
	panel.Parent = root
	UiTheme.stroke(UiTheme.Colors.Accent, 3, panel)
	UiTheme.autoFit(panel, 480, 420)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.fromOffset(320, 36)
	title.Font = UiTheme.HeaderFont
	title.TextSize = 30
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = UiTheme.Colors.AccentDeep
	title.Text = "Today's Quests"
	title.Parent = panel

	streakLabel = Instance.new("TextLabel")
	streakLabel.BackgroundTransparency = 1
	streakLabel.Position = UDim2.fromOffset(24, 56)
	streakLabel.Size = UDim2.fromOffset(432, 26)
	streakLabel.Font = UiTheme.BodyFont
	streakLabel.TextSize = 16
	streakLabel.TextXAlignment = Enum.TextXAlignment.Left
	streakLabel.TextColor3 = UiTheme.Colors.Ink
	streakLabel.Text = "🔥 Day 0 streak"
	streakLabel.Parent = panel

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -16, 0, 16)
	close.Size = UDim2.fromOffset(40, 40)
	close.BackgroundColor3 = UiTheme.Colors.Accent
	close.BorderSizePixel = 0
	close.Font = UiTheme.HeaderFont
	close.TextSize = 24
	close.TextColor3 = Color3.fromRGB(255, 255, 255)
	close.Text = "X"
	close.Parent = panel
	UiTheme.corner(20, close)
	close.Activated:Connect(function()
		DailyUI.hide()
	end)

	for i = 1, DailyQuestConfig.PerDay do
		questRows[i] = makeRow(panel, i)
	end
end

return DailyUI
