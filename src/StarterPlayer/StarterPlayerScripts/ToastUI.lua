-- ToastUI
-- A soft message banner that slides down from the top for friendly notes like
-- "Welcome to Pudding Hills!" or "Friendship Bonus!".

local TweenService = game:GetService("TweenService")
local UiTheme = require(script.Parent.UiTheme)

local ToastUI = {}

local frame, label
local token = 0

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

function ToastUI.show(text)
	if not frame then
		return
	end
	token += 1
	local myToken = token
	label.Text = text
	frame.Visible = true
	frame.Position = UDim2.new(0.5, 0, 0, -80)
	TweenService:Create(frame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 18),
	}):Play()

	task.delay(3.6, function()
		if myToken == token and frame then
			local out = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0, -80),
			})
			out.Completed:Connect(function()
				if myToken == token and frame then
					frame.Visible = false
				end
			end)
			out:Play()
		end
	end)
end

return ToastUI
