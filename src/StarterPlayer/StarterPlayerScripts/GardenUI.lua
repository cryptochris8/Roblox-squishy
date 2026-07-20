-- GardenUI (CLIENT)
-- The Sparkle Garden panel: your three beds. An empty bed offers the seed picker
-- (a gentle confirm before spending); a growing bed shows a progress bar that only
-- ever fills UP (never a countdown); a bloomed bed shows a Harvest button. Reads
-- state.garden from every StateSync (growth is computed server-side, so the size
-- shown is authoritative). Seed names/prices/colours come from the shared
-- GardenConfig, so the panel and the server always agree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))
local UiTheme = require(script.Parent.UiTheme)

local GardenUI = {}

local screen, overlay, panel, coinsLabel, waterHint
local rows = {} -- bedId → { frame, status, bar, fill, harvest, seedBtns }
local confirmBox, confirmLabel, confirmYes
local onPlantCb, onHarvestCb
local pending = nil -- { bedId, seedId }
local lastState = nil

local BED_IDS = GardenConfig.BedIds

local function close()
	if overlay then
		overlay.Visible = false
	end
	if confirmBox then
		confirmBox.Visible = false
	end
end

-- Render one bed row from its view ({seedId, grownPct, stage, ready} or nil = empty).
local function paintRow(bedId, bedView, coins)
	local row = rows[bedId]
	if not row then
		return
	end
	if not bedView then
		-- EMPTY: show the seed picker
		row.status.Text = "Bed " .. bedId .. " — empty, plant a seed!"
		row.status.TextColor3 = UiTheme.Colors.SoftInk
		row.bar.Visible = false
		row.harvest.Visible = false
		for _, btn in ipairs(row.seedBtns) do
			btn.holder.Visible = true
			local seed = btn.seed
			local affordable = coins >= seed.price
			btn.price.Text = seed.price .. " coins"
			btn.holder.BackgroundColor3 = affordable and UiTheme.Colors.Panel or UiTheme.Colors.Shade
			btn.holder.AutoButtonColor = affordable
		end
		return
	end
	for _, btn in ipairs(row.seedBtns) do
		btn.holder.Visible = false
	end
	local seed = GardenConfig.getSeed(bedView.seedId)
	local name = seed and seed.name or "Plant"
	local icon = seed and seed.icon or "🌱"
	if bedView.ready then
		row.status.Text = icon .. " " .. name .. " — ready! ✨"
		row.status.TextColor3 = UiTheme.Colors.AccentDeep
		row.bar.Visible = false
		row.harvest.Visible = true
		row.harvest.Text = "✨ Harvest +" .. (seed and seed.harvestCoins or 0)
	else
		local pct = math.floor((bedView.grownPct or 0) * 100 + 0.5)
		row.status.Text = icon .. " " .. name .. " — growing! (" .. pct .. "%)"
		row.status.TextColor3 = UiTheme.Colors.Ink
		row.bar.Visible = true
		row.harvest.Visible = false
		row.fill.Size = UDim2.fromScale(math.clamp(bedView.grownPct or 0, 0, 1), 1)
		if seed then
			row.fill.BackgroundColor3 = seed.color
		end
	end
end

function GardenUI.update(state)
	lastState = state
	if not overlay or not overlay.Visible then
		return
	end
	local coins = (state and state.coins) or 0
	coinsLabel.Text = coins .. " coins"
	local garden = state and state.garden
	local beds = (garden and garden.beds) or {}
	for _, bedId in ipairs(BED_IDS) do
		paintRow(bedId, beds[bedId], coins)
	end
	if waterHint then
		local left = math.max(0, ((garden and garden.waterMax) or 5) - ((garden and garden.waterGiven) or 0))
		waterHint.Text = "💧 Water a friend's garden for a growth boost! (" .. left .. " left today)"
	end
end

function GardenUI.open()
	if not overlay then
		return
	end
	overlay.Visible = true
	if confirmBox then
		confirmBox.Visible = false
	end
	if lastState then
		GardenUI.update(lastState)
	end
end

local function askPlant(bedId, seed)
	pending = { bedId = bedId, seedId = seed.id }
	confirmLabel.Text = seed.icon .. "  Plant a " .. seed.name .. " for " .. seed.price .. " coins?"
	confirmYes.Text = "Plant  " .. seed.price
	confirmBox.Visible = true
end

local function makeRow(index, bedId)
	local frame = UiTheme.panel({
		Name = "Bed" .. bedId,
		Position = UDim2.fromOffset(20, 92 + (index - 1) * 112),
		Size = UDim2.fromOffset(520, 100),
		BackgroundColor3 = UiTheme.Colors.Cream,
		radius = 16,
	})
	frame.Parent = panel

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromOffset(16, 8)
	status.Size = UDim2.fromOffset(488, 26)
	status.Font = UiTheme.HeaderFont
	status.TextSize = 20
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextColor3 = UiTheme.Colors.Ink
	status.Text = "Bed " .. bedId
	status.Parent = frame

	-- growing: a progress bar (fills up; never a countdown)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(16, 52)
	bar.Size = UDim2.fromOffset(488, 22)
	bar.BackgroundColor3 = UiTheme.Colors.Shade
	bar.BackgroundTransparency = 0.6
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = frame
	UiTheme.corner(11, bar)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = UiTheme.Colors.Accent
	fill.BorderSizePixel = 0
	fill.Parent = bar
	UiTheme.corner(11, fill)

	-- ready: a harvest button
	local harvest = Instance.new("TextButton")
	harvest.Name = "Harvest"
	harvest.AnchorPoint = Vector2.new(1, 0)
	harvest.Position = UDim2.new(1, -16, 0, 46)
	harvest.Size = UDim2.fromOffset(200, 40)
	harvest.BackgroundColor3 = UiTheme.Colors.Accent
	harvest.Font = UiTheme.HeaderFont
	harvest.TextSize = 20
	harvest.TextColor3 = Color3.fromRGB(255, 255, 255)
	harvest.Text = "✨ Harvest"
	harvest.Visible = false
	harvest.Parent = frame
	UiTheme.corner(14, harvest)
	harvest.Activated:Connect(function()
		if onHarvestCb then
			onHarvestCb(bedId)
		end
	end)

	-- empty: three seed buttons across the row
	local seedBtns = {}
	for i, seed in ipairs(GardenConfig.Seeds) do
		local w = 160
		local holder = Instance.new("TextButton")
		holder.Name = "Seed_" .. seed.id
		holder.Position = UDim2.fromOffset(16 + (i - 1) * (w + 6), 44)
		holder.Size = UDim2.fromOffset(w, 46)
		holder.BackgroundColor3 = UiTheme.Colors.Panel
		holder.AutoButtonColor = true
		holder.Text = ""
		holder.Parent = frame
		UiTheme.corner(12, holder)

		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromOffset(10, 4)
		title.Size = UDim2.fromOffset(w - 16, 22)
		title.Font = UiTheme.HeaderFont
		title.TextSize = 15
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextColor3 = UiTheme.Colors.Ink
		title.Text = seed.icon .. " " .. seed.name
		title.Parent = holder

		local price = Instance.new("TextLabel")
		price.BackgroundTransparency = 1
		price.Position = UDim2.fromOffset(10, 24)
		price.Size = UDim2.fromOffset(w - 16, 18)
		price.Font = UiTheme.BodyFont
		price.TextSize = 14
		price.TextXAlignment = Enum.TextXAlignment.Left
		price.TextColor3 = UiTheme.Colors.CoinDeep
		price.Text = seed.price .. " coins"
		price.Parent = holder

		holder.Activated:Connect(function()
			local coins = (lastState and lastState.coins) or 0
			if coins < seed.price then
				return -- not enough; the button reads dimmed
			end
			askPlant(bedId, seed)
		end)
		seedBtns[#seedBtns + 1] = { holder = holder, price = price, seed = seed }
	end

	rows[bedId] = { frame = frame, status = status, bar = bar, fill = fill, harvest = harvest, seedBtns = seedBtns }
end

function GardenUI.mount(playerGui, onPlant, onHarvest)
	onPlantCb, onHarvestCb = onPlant, onHarvest

	screen = Instance.new("ScreenGui")
	screen.Name = "SquishyGarden"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 33
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
	overlay.Activated:Connect(close)

	panel = UiTheme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 470),
		BackgroundColor3 = UiTheme.Colors.Cream,
		radius = 24,
	})
	panel.Active = true
	panel.Parent = overlay
	UiTheme.stroke(UiTheme.Colors.Accent, 3, panel)
	UiTheme.autoFit(panel, 560, 470)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(24, 14)
	title.Size = UDim2.fromOffset(360, 34)
	title.Font = UiTheme.HeaderFont
	title.TextSize = 28
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = UiTheme.Colors.AccentDeep
	title.Text = "🌱 Your Sparkle Garden"
	title.Parent = panel

	coinsLabel = Instance.new("TextLabel")
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.AnchorPoint = Vector2.new(1, 0)
	coinsLabel.Position = UDim2.new(1, -70, 0, 20)
	coinsLabel.Size = UDim2.fromOffset(150, 26)
	coinsLabel.Font = UiTheme.HeaderFont
	coinsLabel.TextSize = 20
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinsLabel.TextColor3 = UiTheme.Colors.CoinDeep
	coinsLabel.Text = "0 coins"
	coinsLabel.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.AnchorPoint = Vector2.new(1, 0)
	closeBtn.Position = UDim2.new(1, -16, 0, 16)
	closeBtn.Size = UDim2.fromOffset(40, 40)
	closeBtn.BackgroundColor3 = UiTheme.Colors.Accent
	closeBtn.Font = UiTheme.HeaderFont
	closeBtn.TextSize = 24
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "X"
	closeBtn.Parent = panel
	UiTheme.corner(20, closeBtn)
	closeBtn.Activated:Connect(close)

	for i, bedId in ipairs(BED_IDS) do
		makeRow(i, bedId)
	end

	waterHint = Instance.new("TextLabel")
	waterHint.BackgroundTransparency = 1
	waterHint.Position = UDim2.fromOffset(24, 436)
	waterHint.Size = UDim2.fromOffset(512, 24)
	waterHint.Font = UiTheme.BodyFont
	waterHint.TextSize = 15
	waterHint.TextColor3 = UiTheme.Colors.SoftInk
	waterHint.Text = "💧 Water a friend's garden for a growth boost!"
	waterHint.Parent = panel

	-- the gentle plant-confirm box
	confirmBox = UiTheme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(400, 180),
		BackgroundColor3 = UiTheme.Colors.Panel,
		radius = 20,
	})
	confirmBox.Visible = false
	confirmBox.ZIndex = 40
	confirmBox.Active = true
	confirmBox.Parent = panel
	UiTheme.stroke(UiTheme.Colors.AccentDeep, 3, confirmBox)

	confirmLabel = Instance.new("TextLabel")
	confirmLabel.BackgroundTransparency = 1
	confirmLabel.Position = UDim2.fromOffset(18, 20)
	confirmLabel.Size = UDim2.fromOffset(364, 80)
	confirmLabel.Font = UiTheme.HeaderFont
	confirmLabel.TextSize = 20
	confirmLabel.TextWrapped = true
	confirmLabel.TextColor3 = UiTheme.Colors.Ink
	confirmLabel.ZIndex = 41
	confirmLabel.Text = ""
	confirmLabel.Parent = confirmBox

	confirmYes = Instance.new("TextButton")
	confirmYes.Position = UDim2.fromOffset(206, 120)
	confirmYes.Size = UDim2.fromOffset(176, 44)
	confirmYes.BackgroundColor3 = UiTheme.Colors.Accent
	confirmYes.Font = UiTheme.HeaderFont
	confirmYes.TextSize = 20
	confirmYes.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmYes.Text = "Plant"
	confirmYes.ZIndex = 41
	confirmYes.Parent = confirmBox
	UiTheme.corner(14, confirmYes)
	confirmYes.Activated:Connect(function()
		confirmBox.Visible = false
		if pending and onPlantCb then
			onPlantCb(pending.bedId, pending.seedId)
		end
		pending = nil
	end)

	local confirmNo = Instance.new("TextButton")
	confirmNo.Position = UDim2.fromOffset(18, 120)
	confirmNo.Size = UDim2.fromOffset(176, 44)
	confirmNo.BackgroundColor3 = UiTheme.Colors.Shade
	confirmNo.BackgroundTransparency = 0.3
	confirmNo.Font = UiTheme.HeaderFont
	confirmNo.TextSize = 20
	confirmNo.TextColor3 = UiTheme.Colors.Ink
	confirmNo.Text = "Not now"
	confirmNo.ZIndex = 41
	confirmNo.Parent = confirmBox
	UiTheme.corner(14, confirmNo)
	confirmNo.Activated:Connect(function()
		confirmBox.Visible = false
		pending = nil
	end)
end

return GardenUI
