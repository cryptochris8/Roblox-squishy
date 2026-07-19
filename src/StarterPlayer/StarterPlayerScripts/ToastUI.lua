-- ToastUI
-- A soft message banner that slides down from the top for friendly notes like
-- "Welcome to Pudding Hills!" or "Friendship Bonus!".
--
-- Messages QUEUE instead of overwriting each other (the old banner ate the
-- previous message whenever two things happened at once — a kid's quest-done
-- note could vanish under a surge announcement). One banner shows at a time;
-- waiting messages drain in priority order: celebration > social > info.
-- Repeats of a message that is already showing or waiting coalesce silently.

local TweenService = game:GetService("TweenService")
local UiTheme = require(script.Parent.UiTheme)

local ToastUI = {}

-- kind -> priority (lower shows first). Untagged calls are "info".
local PRIORITY = {
	celebration = 1,
	social = 2,
	info = 3,
}

local SHOW_SECONDS = 3.6      -- banner hold when nothing is waiting
local SHOW_SECONDS_BUSY = 2.4 -- shorter hold while a backlog drains
local MAX_WAITING = 6         -- drop the least-important overflow beyond this

local frame, label
local queue = {} -- array of { text, prio }
local showing = false
local currentText = nil

function ToastUI.mount(playerGui)
	local screen = Instance.new("ScreenGui")
	screen.Name = "Toast"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.DisplayOrder = 50
	screen.Parent = playerGui

	frame = UiTheme.panel({
		Name = "ToastFrame",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -80),
		Size = UDim2.fromOffset(560, 64),
		BackgroundColor3 = UiTheme.Colors.AccentDeep,
		radius = 20,
	})
	frame.Visible = false
	frame.Parent = screen
	UiTheme.stroke(Color3.fromRGB(255, 255, 255), 2, frame)

	label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -28, 1, 0)
	label.Position = UDim2.fromOffset(14, 0)
	label.Font = UiTheme.HeaderFont
	label.TextSize = 19
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextWrapped = true
	label.Text = ""
	label.Parent = frame
end

-- Pop the most important waiting message (stable within a priority: first-in
-- shows first, so same-kind messages keep their arrival order).
local function popNext()
	local bestIndex = nil
	for i, item in ipairs(queue) do
		if bestIndex == nil or item.prio < queue[bestIndex].prio then
			bestIndex = i
		end
	end
	if bestIndex then
		return table.remove(queue, bestIndex)
	end
	return nil
end

local function presentNext()
	local item = popNext()
	if not item or not frame then
		showing = false
		currentText = nil
		return
	end
	showing = true
	currentText = item.text
	label.Text = item.text
	frame.Visible = true
	frame.Position = UDim2.new(0.5, 0, 0, -80)
	TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 18),
	}):Play()

	local hold = (#queue > 0) and SHOW_SECONDS_BUSY or SHOW_SECONDS
	task.delay(hold, function()
		if not frame then
			showing = false
			return
		end
		local out = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 0, -80),
		})
		out.Completed:Connect(function()
			if frame then
				frame.Visible = false
			end
			currentText = nil
			presentNext()
		end)
		out:Play()
	end)
end

-- kind is optional: "celebration" | "social" | "info" (default). Existing
-- one-argument callers keep working unchanged.
function ToastUI.show(text, kind)
	if not frame or type(text) ~= "string" or text == "" then
		return
	end
	-- coalesce: the same message showing or already waiting never stacks
	if text == currentText then
		return
	end
	for _, item in ipairs(queue) do
		if item.text == text then
			return
		end
	end
	table.insert(queue, { text = text, prio = PRIORITY[kind] or PRIORITY.info })
	-- keep the backlog small: shed the least important, newest-first
	while #queue > MAX_WAITING do
		local worstIndex = 1
		for i, item in ipairs(queue) do
			if item.prio >= queue[worstIndex].prio then
				worstIndex = i
			end
		end
		table.remove(queue, worstIndex)
	end
	if not showing then
		presentNext()
	end
end

return ToastUI
