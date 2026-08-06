-- OddsUI ("What's Inside?", doc 15 §5)
-- The kid-readable Sparkle Capsule odds page. Content is GENERATED from the
-- real CapsuleConfig weights, FILTERED to the rarities this capsule's packs
-- actually contain (mirroring the server's buildRarityPool — pickRarity skips
-- empty tiers and renormalizes, so the page must too or it lies about tiers
-- that can never drop), then renormalized to /100. A hundred-chart of dots
-- (one dot = one capsule) lets a six-year-old literally count the mythic dots.
-- Honest, calm, zero urgency copy — capsules are free and there are no misses.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiTheme = require(script.Parent.UiTheme)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CapsuleConfig = require(Shared:WaitForChild("CapsuleConfig"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))
local SquishyData = require(Shared:WaitForChild("SquishyData"))

local OddsUI = {}

local screen, panel, backdrop

-- Weights -> whole numbers summing to exactly 100 (largest-remainder rounding).
local function toHundred(weights)
	local total = 0
	for _, w in pairs(weights) do
		total += w
	end
	if total <= 0 then
		return {}
	end
	local rows = {}
	local used = 0
	for rarity, w in pairs(weights) do
		local exact = w / total * 100
		local floor = math.floor(exact)
		table.insert(rows, { rarity = rarity, count = floor, frac = exact - floor })
		used += floor
	end
	table.sort(rows, function(a, b)
		return a.frac > b.frac
	end)
	local i = 1
	while used < 100 and i <= #rows do
		rows[i].count += 1
		used += 1
		i += 1
	end
	table.sort(rows, function(a, b)
		local sa = (RarityConfig[a.rarity] and RarityConfig[a.rarity].SortOrder) or 0
		local sb = (RarityConfig[b.rarity] and RarityConfig[b.rarity].SortOrder) or 0
		return sa < sb
	end)
	return rows
end

-- Only the rarities this capsule can actually roll (the server's
-- buildRarityPool, mirrored): a weight counts only if some friend of that
-- rarity exists in one of the capsule's packs.
local function presentWeights(cfg)
	local present = {}
	for _, packId in ipairs(cfg.AllowedPackIds) do
		for _, def in ipairs(SquishyData.getByPack(packId)) do
			present[def.Rarity] = true
		end
	end
	local filtered = {}
	for rarity, w in pairs(cfg.RarityWeights) do
		if present[rarity] then
			filtered[rarity] = w
		end
	end
	return filtered
end

function OddsUI.show(capsuleKey)
	if not screen then
		return
	end
	OddsUI.hide()
	local cfg = CapsuleConfig[capsuleKey] or CapsuleConfig.StarterCapsule
	local rows = toHundred(presentWeights(cfg))
	if #rows == 0 then
		return
	end

	-- A full-screen backdrop that SINKS input (the page can sit over the reveal
	-- ceremony — a stray tap must not fall through and dismiss it). Tapping the
	-- backdrop just closes the odds page.
	backdrop = Instance.new("TextButton")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = UiTheme.Colors.Shade
	backdrop.BackgroundTransparency = 0.6
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.Active = true
	backdrop.ZIndex = 19
	backdrop.Parent = screen
	backdrop.Activated:Connect(function()
		OddsUI.hide()
	end)

	panel = UiTheme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 520),
		BackgroundColor3 = UiTheme.Colors.Cream,
		radius = 22,
	})
	panel.ZIndex = 20
	panel.Parent = screen
	UiTheme.stroke(UiTheme.Colors.Accent, 3, panel)
	UiTheme.autoFit(panel, 380, 520)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 12)
	title.Size = UDim2.new(1, -32, 0, 30)
	title.Font = UiTheme.HeaderFont
	title.TextSize = 22
	title.TextColor3 = UiTheme.Colors.AccentDeep
	title.Text = "What's inside the " .. (cfg.DisplayName or "Sparkle Capsule") .. "?"
	title.TextWrapped = true
	title.ZIndex = 21
	title.Parent = panel

	local intro = Instance.new("TextLabel")
	intro.BackgroundTransparency = 1
	intro.Position = UDim2.fromOffset(16, 44)
	intro.Size = UDim2.new(1, -32, 0, 22)
	intro.Font = UiTheme.BodyFont
	intro.TextSize = 15
	intro.TextColor3 = UiTheme.Colors.Ink
	intro.Text = "Out of every 100 Sparkle Capsules, about..."
	intro.TextXAlignment = Enum.TextXAlignment.Left
	intro.ZIndex = 21
	intro.Parent = panel

	-- Legend rows: colour dot + count + the rarity's own storybook phrasing.
	local y = 70
	for _, row in ipairs(rows) do
		local color = UiTheme.rarityColor(row.rarity)
		local dot = Instance.new("Frame")
		dot.Position = UDim2.fromOffset(20, y + 4)
		dot.Size = UDim2.fromOffset(14, 14)
		dot.BackgroundColor3 = color
		dot.BorderSizePixel = 0
		dot.ZIndex = 21
		dot.Parent = panel
		UiTheme.corner(7, dot)
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Position = UDim2.fromOffset(42, y)
		lbl.Size = UDim2.new(1, -58, 0, 22)
		lbl.Font = UiTheme.BodyFont
		lbl.TextSize = 15
		lbl.TextColor3 = UiTheme.Colors.Ink
		-- "A cozy friend appeared!" -> "cozy friends" (drop the article + verb,
		-- pluralize) so a row reads "50  —  cozy friends".
		local phrase = (RarityConfig[row.rarity] and RarityConfig[row.rarity].KidFriendlyReveal) or row.rarity
		local legend = phrase:gsub("^An? ", ""):gsub(" appeared!$", ""):gsub("friend$", "friends")
		lbl.Text = row.count .. "  —  " .. legend
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.ZIndex = 21
		lbl.Parent = panel
		y += 24
	end

	-- The hundred-chart: 10x10 dots, one per capsule, coloured by tier.
	local grid = Instance.new("Frame")
	grid.Position = UDim2.fromOffset(50, y + 10)
	grid.Size = UDim2.fromOffset(280, 140)
	grid.BackgroundTransparency = 1
	grid.ZIndex = 21
	grid.Parent = panel
	local index = 0
	for _, row in ipairs(rows) do
		for _ = 1, row.count do
			local col = index % 20
			local rowIx = math.floor(index / 20)
			local d = Instance.new("Frame")
			d.Position = UDim2.fromOffset(col * 14, rowIx * 14)
			d.Size = UDim2.fromOffset(10, 10)
			d.BackgroundColor3 = UiTheme.rarityColor(row.rarity)
			d.BorderSizePixel = 0
			d.ZIndex = 21
			d.Parent = grid
			UiTheme.corner(5, d)
			index += 1
		end
	end

	-- Honest footnotes, plain sentences, zero urgency.
	local notes = Instance.new("TextLabel")
	notes.BackgroundTransparency = 1
	notes.Position = UDim2.fromOffset(16, y + 90)
	notes.Size = UDim2.new(1, -32, 0, 190)
	notes.Font = UiTheme.BodyFont
	notes.TextSize = 14
	notes.TextWrapped = true
	notes.TextColor3 = UiTheme.Colors.SoftInk
	notes.TextXAlignment = Enum.TextXAlignment.Left
	notes.TextYAlignment = Enum.TextYAlignment.Top
	notes.Text = "Sometimes more, sometimes fewer — every capsule is a surprise!\n\n"
		.. "Capsules always open with Sparkle Coins you earn by playing. Never Robux.\n\n"
		.. "Already know the friend? They shine up ✨ → 🌈 and you get bonus Sparkle Coins. There are no misses.\n\n"
		.. "Sometimes a friend arrives wearing a Sparkle Pattern — Berry Swirl (about 1 in 6) all the way to Golden Crumb (about 1 in 250). Patterns are never lost, and every pattern can appear in every capsule, always.\n\n"
		.. "Family friends aren't in capsules — you earn them by restoring the lands, and they'll always be waiting for you."
	notes.ZIndex = 21
	notes.Parent = panel

	local ok = Instance.new("TextButton")
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.new(0.5, 0, 1, -14)
	ok.Size = UDim2.fromOffset(160, 42)
	ok.BackgroundColor3 = UiTheme.Colors.AccentDeep
	ok.BorderSizePixel = 0
	ok.Font = UiTheme.HeaderFont
	ok.TextSize = 20
	ok.TextColor3 = Color3.fromRGB(255, 255, 255)
	ok.Text = "Okay!"
	ok.ZIndex = 22
	ok.Active = true
	ok.Parent = panel
	UiTheme.corner(21, ok)
	ok.Activated:Connect(function()
		OddsUI.hide()
	end)
end

function OddsUI.hide()
	if panel then
		panel:Destroy()
		panel = nil
	end
	if backdrop then
		backdrop:Destroy()
		backdrop = nil
	end
end

function OddsUI.mount(playerGui)
	screen = Instance.new("ScreenGui")
	screen.Name = "CapsuleOdds"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 70 -- above the reveal (60), so "What's inside?" overlays it
	screen.Parent = playerGui
end

return OddsUI
