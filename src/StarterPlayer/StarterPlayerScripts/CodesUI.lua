-- CodesUI
-- The "magic word" panel: type a word from The Lost Sparkle storybook, tap the
-- sparkly button, and the server decides what happens (feedback arrives as a
-- friendly toast). Deliberately tiny and kid-simple.

local UiTheme = require(script.Parent.UiTheme)

local CodesUI = {}

local overlay, box, input
local onSubmitCb

function CodesUI.mount(playerGui, onSubmit)
	onSubmitCb = onSubmit

	local screen = Instance.new("ScreenGui")
	screen.Name = "SquishyCodes"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.DisplayOrder = 35
	screen.Parent = playerGui

	overlay = Instance.new("TextButton")
	overlay.Name = "Shade"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = UiTheme.Colors.Shade
	overlay.BackgroundTransparency = 0.45
	overlay.AutoButtonColor = false
	overlay.Text = ""
	overlay.Visible = false
	overlay.Parent = screen
	overlay.Activated:Connect(function()
		CodesUI.hide()
	end)

	box = UiTheme.panel({
		Name = "CodesPanel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(420, 220),
		BackgroundColor3 = UiTheme.Colors.Cream,
		radius = 20,
	})
	box.Active = true
	box.Parent = overlay
	UiTheme.stroke(UiTheme.Colors.AccentDeep, 3, box)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(20, 14)
	title.Size = UDim2.new(1, -40, 0, 30)
	title.Font = UiTheme.HeaderFont
	title.TextSize = 24
	title.TextColor3 = UiTheme.Colors.AccentDeep
	title.Text = "🎟️ Magic Words"
	title.Parent = box

	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(20, 44)
	hint.Size = UDim2.new(1, -40, 0, 20)
	hint.Font = UiTheme.BodyFont
	hint.TextSize = 14
	hint.TextColor3 = UiTheme.Colors.SoftInk
	hint.Text = "Found a magic word in the storybook? Whisper it here!"
	hint.TextWrapped = true
	hint.Parent = box

	input = Instance.new("TextBox")
	input.Name = "CodeInput"
	input.AnchorPoint = Vector2.new(0.5, 0)
	input.Position = UDim2.new(0.5, 0, 0, 76)
	input.Size = UDim2.fromOffset(360, 48)
	input.BackgroundColor3 = UiTheme.Colors.Panel
	input.BorderSizePixel = 0
	input.Font = UiTheme.HeaderFont
	input.TextSize = 22
	input.TextColor3 = UiTheme.Colors.Ink
	input.PlaceholderText = "type it here..."
	input.PlaceholderColor3 = UiTheme.Colors.SoftInk
	input.Text = ""
	input.ClearTextOnFocus = false
	input.Parent = box
	UiTheme.corner(14, input)
	UiTheme.stroke(UiTheme.Colors.Accent, 2, input)

	local go = Instance.new("TextButton")
	go.AnchorPoint = Vector2.new(0.5, 1)
	go.Position = UDim2.new(0.5, 0, 1, -16)
	go.Size = UDim2.fromOffset(220, 50)
	go.BackgroundColor3 = UiTheme.Colors.AccentDeep
	go.BorderSizePixel = 0
	go.Font = UiTheme.HeaderFont
	go.TextSize = 20
	go.TextColor3 = Color3.fromRGB(255, 255, 255)
	go.Text = "✨ Say the Magic Word"
	go.Parent = box
	UiTheme.corner(24, go)
	UiTheme.stroke(Color3.fromRGB(255, 255, 255), 2, go)

	local function submit()
		local text = input.Text
		if onSubmitCb and #text > 0 then
			onSubmitCb(text)
			input.Text = ""
			CodesUI.hide()
		end
	end
	go.Activated:Connect(submit)
	input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
end

function CodesUI.show()
	if overlay then
		overlay.Visible = true
		input:CaptureFocus()
	end
end

function CodesUI.hide()
	if overlay then
		overlay.Visible = false
		input:ReleaseFocus()
	end
end

return CodesUI
