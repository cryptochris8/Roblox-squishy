--!strict
-- LoadingUi (REPLICATED FIRST) — the storybook loading screen. Built entirely
-- in code (no asset dependency: it must render before ANY asset streams), so
-- the very first thing a kid sees on a slow tablet is a warm Squishy page
-- instead of a frozen half-built world. Ported from the Rewind Files' proven
-- loader, re-dressed in Squishy Smash's candy palette + Fredoka (the brand
-- font from the book — built into Roblox, zero uploads).

local TweenService = game:GetService("TweenService")

local LoadingUi = {}

-- The book/app palette, hardcoded on purpose: UiTheme lives in
-- StarterPlayerScripts, which does not exist yet at ReplicatedFirst time.
local BACKDROP = Color3.fromRGB(255, 231, 240) -- soft pink page
local CARD = Color3.fromRGB(255, 250, 243) -- cream
local ACCENT = Color3.fromRGB(255, 130, 170) -- squishy pink
local ACCENT_DEEP = Color3.fromRGB(214, 84, 128)
local INK = Color3.fromRGB(94, 70, 92)
local SOFT_INK = Color3.fromRGB(150, 120, 140)
local GOLD = Color3.fromRGB(255, 200, 90)

-- Kid-readable, true, and gentle. Proven-rendering glyphs only.
local TIPS: { string } = {
	"Boop a sleepy friend three times to wake them up!",
	"Every Happy Pop earns you Sparkle Coins ✨",
	"Your first Sparkle Capsule each day is FREE 🎟️",
	"Hidden Sparkle Bits sparkle near landmarks — new ones every day!",
	"Open your Squishy Book 📖 to equip a buddy 🧸 — it follows you!",
	"Follow the caramel paths — sleepy friends nap far and wide!",
	"See the 🎁 on a friend? You can give them a gift 💝",
	"Glowing story pages let you read The Lost Sparkle right here 📖",
	"A new friend visits the Sparkle Tent every week ⭐",
	"Recover each land's Sparkle Shard to open the next land 🌈",
}

export type Screen = {
	gui: ScreenGui,
	setProgress: (fraction: number, label: string?) -> (),
	setSubtitle: (text: string) -> (),
	finish: () -> (),
}

function LoadingUi.build(): Screen
	local gui = Instance.new("ScreenGui")
	gui.Name = "SquishyLoadingScreen"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100 -- above everything
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = BACKDROP
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	-- the open storybook page, centered
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.52, 0.42)
	card.BackgroundColor3 = CARD
	card.BorderSizePixel = 0
	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 18)
	cardCorner.Parent = card
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = ACCENT
	cardStroke.Thickness = 3
	cardStroke.Parent = card
	local cardSize = Instance.new("UISizeConstraint")
	cardSize.MinSize = Vector2.new(360, 240)
	cardSize.MaxSize = Vector2.new(760, 460)
	cardSize.Parent = card
	card.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromScale(0.06, 0.08)
	title.Size = UDim2.fromScale(0.88, 0.22)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = ACCENT_DEEP
	title.Text = "Squishy Smash"
	title.Parent = card

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Position = UDim2.fromScale(0.06, 0.3)
	subtitle.Size = UDim2.fromScale(0.88, 0.12)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.FredokaOne
	subtitle.TextScaled = true
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextColor3 = GOLD
	subtitle.Text = "✨ The Lost Sparkle ✨"
	subtitle.Parent = card

	local tip = Instance.new("TextLabel")
	tip.Name = "Tip"
	tip.Position = UDim2.fromScale(0.06, 0.48)
	tip.Size = UDim2.fromScale(0.88, 0.24)
	tip.BackgroundTransparency = 1
	tip.Font = Enum.Font.GothamMedium
	tip.TextScaled = true
	tip.TextWrapped = true
	tip.TextXAlignment = Enum.TextXAlignment.Left
	tip.TextYAlignment = Enum.TextYAlignment.Top
	tip.TextColor3 = INK
	tip.Text = TIPS[math.random(1, #TIPS)]
	tip.Parent = card

	-- progress: a filling sparkle bar along the page's bottom
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.fromScale(0.5, 0.92)
	track.Size = UDim2.fromScale(0.88, 0.06)
	track.BackgroundColor3 = Color3.fromRGB(245, 225, 232)
	track.BorderSizePixel = 0
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track
	track.Parent = card

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = ACCENT
	fill.BorderSizePixel = 0
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	fill.Parent = track

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(0.5, 1)
	status.Position = UDim2.fromScale(0.5, 1.32)
	status.Size = UDim2.fromScale(1, 0.6)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.TextScaled = true
	status.TextColor3 = SOFT_INK
	status.Text = ""
	status.Parent = track

	-- tips rotate while we wait (a still screen reads as a frozen game)
	task.spawn(function()
		while gui.Parent ~= nil do
			task.wait(4)
			if gui.Parent == nil then
				break
			end
			local nextTip = TIPS[math.random(1, #TIPS)]
			TweenService:Create(tip, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
			task.wait(0.35)
			tip.Text = nextTip
			TweenService:Create(tip, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
		end
	end)

	local function setProgress(fraction: number, label: string?)
		local clamped = math.clamp(fraction, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {
			Size = UDim2.fromScale(clamped, 1),
		}):Play()
		if label ~= nil then
			status.Text = label
		end
	end

	local function setSubtitle(text: string)
		subtitle.Text = text
	end

	local function finish()
		setProgress(1, "Ready!")
		task.wait(0.35)
		-- Never a hard cut: fade the whole page away so the world greets gently.
		local fade = TweenInfo.new(0.7, Enum.EasingStyle.Sine)
		TweenService:Create(backdrop, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(card, fade, { BackgroundTransparency = 1 }):Play()
		cardStroke.Enabled = false
		for _, label in ipairs({ title, subtitle, tip, status }) do
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		end
		TweenService:Create(track, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(fill, fade, { BackgroundTransparency = 1 }):Play()
		task.wait(0.8)
		gui:Destroy()
	end

	return { gui = gui, setProgress = setProgress, setSubtitle = setSubtitle, finish = finish }
end

return LoadingUi
