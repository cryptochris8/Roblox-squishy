-- FirstDayUI (CLIENT)
-- The "My First Day" checklist panel (right side) + the ✨ world marker that
-- floats over the current step's target, + a gentle highlight if a brand-new
-- player hasn't squished anything for a while. Driven by the StateSync
-- firstDay slice; hides itself forever once every step is paid.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FirstDayConfig = require(Shared:WaitForChild("FirstDayConfig"))
local UiTheme = require(script.Parent.UiTheme)

local FirstDayUI = {}

local localPlayer = Players.LocalPlayer
local panel
local rows = {}
local paid: { [string]: boolean } = {}
local started = os.clock()
local everSquished = false
local marker: BillboardGui? = nil
local highlight: Highlight? = nil
local bookPulse: Tween? = nil
local bookPulseBtn: TextButton? = nil

local function allDone(): boolean
	for _, step in ipairs(FirstDayConfig.Steps) do
		if not paid[step.id] then
			return false
		end
	end
	return true
end

local function currentStep()
	for _, step in ipairs(FirstDayConfig.Steps) do
		if not paid[step.id] then
			return step
		end
	end
	return nil
end

local function buildPanel(playerGui)
	local screen = Instance.new("ScreenGui")
	screen.Name = "SquishyFirstDay"
	screen.ResetOnSpawn = false
	screen.Parent = playerGui

	panel = UiTheme.panel({
		Name = "FirstDayPanel",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(232, 36 + #FirstDayConfig.Steps * 34 + 10),
		radius = 18,
	})
	panel.Visible = false
	panel.Parent = screen
	UiTheme.stroke(UiTheme.Colors.Coin, 2, panel)
	if UiTheme.isCompact() then
		-- phones: shrink + nudge up so it stays clear of the jump button and
		-- the top-right icon row
		panel.Position = UDim2.new(1, -8, 0.5, -36)
		local sc = Instance.new("UIScale")
		sc.Scale = 0.72
		sc.Parent = panel
	end

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -24, 0, 26)
	title.Font = UiTheme.HeaderFont
	title.TextSize = 19
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = UiTheme.Colors.CoinDeep
	title.Text = "⭐ My First Day"
	title.Parent = panel

	for i, step in ipairs(FirstDayConfig.Steps) do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(10, 36 + (i - 1) * 34)
		row.Size = UDim2.new(1, -20, 0, 30)
		row.Parent = panel

		local check = Instance.new("TextLabel")
		check.Name = "Check"
		check.BackgroundTransparency = 1
		check.Size = UDim2.fromOffset(26, 30)
		check.Font = UiTheme.HeaderFont
		check.TextSize = 18
		check.Text = step.icon
		check.Parent = row

		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromOffset(30, 0)
		text.Size = UDim2.new(1, -66, 1, 0)
		text.Font = UiTheme.BodyFont
		text.TextSize = 13
		text.TextWrapped = true
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextColor3 = UiTheme.Colors.Ink
		text.Text = step.text
		text.Parent = row

		local reward = Instance.new("TextLabel")
		reward.Name = "Reward"
		reward.BackgroundTransparency = 1
		reward.AnchorPoint = Vector2.new(1, 0)
		reward.Position = UDim2.new(1, 0, 0, 0)
		reward.Size = UDim2.fromOffset(36, 30)
		reward.Font = UiTheme.HeaderFont
		reward.TextSize = 13
		reward.TextColor3 = UiTheme.Colors.CoinDeep
		reward.Text = step.reward > 0 and ("+" .. step.reward) or "+100"
		reward.Parent = row

		rows[step.id] = row
	end
end

local function makeMarker(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "FirstDayMarker"
	gui.Size = UDim2.fromOffset(120, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 300
	local lbl = Instance.new("TextLabel")
	lbl.Name = "Arrow"
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = UiTheme.HeaderFont
	lbl.TextSize = 34
	lbl.Text = "✨⬇✨"
	lbl.TextColor3 = Color3.fromRGB(255, 220, 110)
	lbl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.25
	lbl.Parent = gui
	TweenService:Create(lbl, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = UDim2.fromOffset(0, 10),
	}):Play()
	return gui
end

-- The world part the current step's marker should float over (nil = none).
local function markerTarget(step): BasePart?
	if not step or not step.marker then
		return nil
	end
	if step.marker == "sleepy" then
		local char = localPlayer.Character
		local here = char and char.PrimaryPart and char.PrimaryPart.Position
		if not here then
			return nil
		end
		local squishies = Workspace:FindFirstChild("Squishies")
		if not squishies then
			return nil
		end
		local best, bestD
		for _, m in ipairs(squishies:GetChildren()) do
			local body = m:FindFirstChild("Body")
			if body and body:IsA("BasePart") and m:GetAttribute("Popped") ~= true then
				local d = (body.Position - here).Magnitude
				if not bestD or d < bestD then
					best, bestD = body, d
				end
			end
		end
		return best
	end
	local ph = Workspace:FindFirstChild("PuddingHills")
	if not ph then
		return nil
	end
	if step.marker == "capsule" then
		local cap = ph:FindFirstChild("SparkleCapsule")
		return cap and cap:FindFirstChild("Base")
	elseif step.marker == "roomdoor" then
		return ph:FindFirstChild("RoomDoor")
	end
	return nil
end

local function setBookPulse(on: boolean)
	local hud = localPlayer:FindFirstChild("PlayerGui")
	hud = hud and hud:FindFirstChild("SquishyHUD")
	local btn = hud and hud:FindFirstChild("BookButton") :: TextButton?
	if not btn then
		return
	end
	-- the HUD rebuilds itself on layout flips (desktop <-> phone): if our tween
	-- points at a dead button, re-arm against the live one
	if bookPulse and bookPulseBtn ~= btn then
		bookPulse:Cancel()
		bookPulse = nil
	end
	-- remember the button's own resting size (compact and desktop differ)
	if btn:GetAttribute("BaseW") == nil then
		btn:SetAttribute("BaseW", btn.Size.X.Offset)
		btn:SetAttribute("BaseH", btn.Size.Y.Offset)
	end
	local bw = btn:GetAttribute("BaseW") :: number
	local bh = btn:GetAttribute("BaseH") :: number
	if on and not bookPulse then
		bookPulseBtn = btn
		bookPulse = TweenService:Create(btn, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Size = UDim2.fromOffset(bw + 10, bh + 6),
		})
		bookPulse:Play()
	elseif not on and bookPulse then
		bookPulse:Cancel()
		bookPulse = nil
		btn.Size = UDim2.fromOffset(bw, bh)
	end
end

local function refresh()
	if not panel then
		return
	end
	if allDone() then
		panel.Visible = false
		if marker then
			marker.Enabled = false
		end
		if highlight then
			highlight:Destroy()
			highlight = nil
		end
		setBookPulse(false)
		return
	end
	panel.Visible = true
	for _, step in ipairs(FirstDayConfig.Steps) do
		local row = rows[step.id]
		if row then
			local done = paid[step.id] == true
			row.Check.Text = done and "✅" or step.icon
			row.Text.TextColor3 = done and UiTheme.Colors.SoftInk or UiTheme.Colors.Ink
			row.Reward.Visible = not done
		end
	end
	setBookPulse(currentStep() ~= nil and currentStep().id == "buddy")
end

-- Follow the current step's target around (gentle 1s cadence).
local function markerLoop()
	while true do
		task.wait(1)
		if allDone() then
			if marker then
				marker.Enabled = false
			end
			break
		end
		local step = currentStep()
		local target = markerTarget(step)
		if marker == nil then
			marker = makeMarker()
			marker.Parent = Workspace
		end
		if target then
			marker.Adornee = target
			marker.Enabled = true
		else
			marker.Enabled = false
		end
		-- gentle stuck-helper: brand-new player, no squish for 45s -> outline
		-- the marked friend so it visibly calls out
		if step and step.id == "squish1" and not everSquished and os.clock() - started > 45 then
			if target and target.Parent and not highlight then
				highlight = Instance.new("Highlight")
				highlight.FillTransparency = 0.75
				highlight.FillColor = Color3.fromRGB(255, 190, 215)
				highlight.OutlineColor = Color3.fromRGB(255, 140, 180)
			end
			if highlight and target then
				highlight.Parent = target.Parent
			end
		elseif highlight then
			highlight:Destroy()
			highlight = nil
		end
	end
end

function FirstDayUI.mount(playerGui)
	buildPanel(playerGui)
	task.spawn(markerLoop)
end

function FirstDayUI.update(state)
	if type(state) ~= "table" then
		return
	end
	if type(state.firstDay) == "table" then
		paid = state.firstDay
	end
	if (state.totalSquishes or 0) > 0 then
		everSquished = true
	end
	refresh()
end

return FirstDayUI
