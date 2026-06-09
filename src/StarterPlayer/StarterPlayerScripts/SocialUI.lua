-- SocialUI
-- The shared-world HUD: the server-wide Sparkle Surge meter (top right) and the
-- "Everybody Squish!" event banner (top centre, under the quest banner). Driven
-- by the server's SocialSync messages; the client only draws and counts down.

local TweenService = game:GetService("TweenService")
local UiTheme = require(script.Parent.UiTheme)

local SocialUI = {}

local GOLD = Color3.fromRGB(255, 201, 84)
local GOLD_DEEP = Color3.fromRGB(240, 160, 40)

-- Surge meter widgets
local surgePill, surgeTitle, surgeFill, surgePulse
-- Event banner widgets
local eventFrame, eventLabel

-- What the server last told us (we only count the clocks down locally).
local surge = { meter = 0, goal = 15, active = false, endsAt = 0, multiplier = 2 }
local eventState = { active = false, zone = nil, progress = 0, goal = 0, endsAt = 0 }

local function fmtClock(seconds)
	local s = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Joins the HUD's left pill column (coins / friends / bits / surge) so it never
-- hides behind Roblox's own player list in the top-right corner.
local function buildSurgePill(screen)
	surgePill = UiTheme.panel({
		Name = "SurgePill",
		Position = UDim2.fromOffset(16, 168),
		Size = UDim2.fromOffset(176, 46),
		radius = 20,
	})
	surgePill.Parent = screen
	UiTheme.stroke(GOLD_DEEP, 2, surgePill)

	surgeTitle = Instance.new("TextLabel")
	surgeTitle.BackgroundTransparency = 1
	surgeTitle.Size = UDim2.new(1, -28, 0, 24)
	surgeTitle.Position = UDim2.fromOffset(14, 3)
	surgeTitle.Font = UiTheme.HeaderFont
	surgeTitle.TextSize = 17
	surgeTitle.TextXAlignment = Enum.TextXAlignment.Left
	surgeTitle.TextColor3 = UiTheme.Colors.Ink
	surgeTitle.Text = "✨ Surge"
	surgeTitle.Parent = surgePill

	local barBg = Instance.new("Frame")
	barBg.Name = "BarBg"
	barBg.Size = UDim2.new(1, -28, 0, 9)
	barBg.Position = UDim2.fromOffset(14, 30)
	barBg.BackgroundColor3 = Color3.fromRGB(240, 225, 235)
	barBg.BorderSizePixel = 0
	barBg.Parent = surgePill
	UiTheme.corner(4, barBg)

	surgeFill = Instance.new("Frame")
	surgeFill.Size = UDim2.new(0, 0, 1, 0)
	surgeFill.BackgroundColor3 = GOLD
	surgeFill.BorderSizePixel = 0
	surgeFill.Parent = barBg
	UiTheme.corner(4, surgeFill)

	surgePulse = TweenService:Create(surgePill, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		BackgroundColor3 = Color3.fromRGB(255, 232, 170),
	})
end

local function buildEventBanner(screen)
	eventFrame = UiTheme.panel({
		Name = "EventBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 66),
		Size = UDim2.fromOffset(540, 40),
		BackgroundColor3 = GOLD,
		radius = 20,
	})
	eventFrame.Visible = false
	eventFrame.Parent = screen
	UiTheme.stroke(Color3.fromRGB(255, 255, 255), 2, eventFrame)

	eventLabel = Instance.new("TextLabel")
	eventLabel.BackgroundTransparency = 1
	eventLabel.Size = UDim2.fromScale(1, 1)
	eventLabel.Font = UiTheme.HeaderFont
	eventLabel.TextSize = 18
	eventLabel.TextColor3 = UiTheme.Colors.Ink
	eventLabel.Text = ""
	eventLabel.Parent = eventFrame
end

-- Repaint from the latest state (called on server sync AND by the countdown).
local function repaint()
	if not surgePill then
		return
	end
	if surge.active and os.clock() < surge.endsAt then
		surgeTitle.Text = "✨ x" .. surge.multiplier .. " COINS! " .. fmtClock(surge.endsAt - os.clock())
		surgeTitle.TextColor3 = GOLD_DEEP
		surgeFill.Size = UDim2.new(1, 0, 1, 0)
		if surgePulse.PlaybackState ~= Enum.PlaybackState.Playing then
			surgePulse:Play()
		end
	else
		surgeTitle.Text = "✨ Surge  " .. surge.meter .. "/" .. surge.goal
		surgeTitle.TextColor3 = UiTheme.Colors.Ink
		surgeFill.Size = UDim2.new(math.clamp(surge.goal > 0 and surge.meter / surge.goal or 0, 0, 1), 0, 1, 0)
		if surgePulse.PlaybackState == Enum.PlaybackState.Playing then
			surgePulse:Cancel()
			surgePill.BackgroundColor3 = UiTheme.Colors.Panel
		end
	end

	if eventState.active and os.clock() < eventState.endsAt then
		eventFrame.Visible = true
		eventLabel.Text = "🌟 Everybody Squish at " .. tostring(eventState.zone) .. "!  "
			.. eventState.progress .. " / " .. eventState.goal
			.. "  —  " .. fmtClock(eventState.endsAt - os.clock())
	else
		eventFrame.Visible = false
	end
end

function SocialUI.mount(playerGui)
	local screen = Instance.new("ScreenGui")
	screen.Name = "SquishySocial"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.Parent = playerGui

	buildSurgePill(screen)
	buildEventBanner(screen)

	-- A gentle local countdown so the clocks tick between server messages.
	task.spawn(function()
		while screen.Parent do
			repaint()
			task.wait(0.25)
		end
	end)
end

-- state carries a `surge` slice, an `event` slice, or both.
function SocialUI.update(state)
	if type(state) ~= "table" then
		return
	end
	if type(state.surge) == "table" then
		surge.meter = tonumber(state.surge.meter) or 0
		surge.goal = math.max(1, tonumber(state.surge.goal) or 1)
		surge.multiplier = tonumber(state.surge.multiplier) or 2
		surge.active = state.surge.active == true
		surge.endsAt = os.clock() + (tonumber(state.surge.remaining) or 0)
	end
	if type(state.event) == "table" then
		eventState.active = state.event.active == true
		eventState.zone = state.event.zone
		eventState.progress = tonumber(state.event.progress) or 0
		eventState.goal = tonumber(state.event.goal) or 0
		eventState.endsAt = os.clock() + (tonumber(state.event.remaining) or 0)
	end
	repaint()
end

return SocialUI
