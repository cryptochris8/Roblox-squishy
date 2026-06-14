-- CollectionBookUI
-- The "Squishy Book": a full-screen album of all 48 launch friends (plus an
-- Events tab). Locked friends show a gentle silhouette; discovered friends show
-- their card. Tapping a discovered friend opens a detail card with "Equip Buddy".

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SquishyData = require(Shared:WaitForChild("SquishyData"))
local VariantConfig = require(Shared:WaitForChild("VariantConfig"))
local UiTheme = require(script.Parent.UiTheme)

local CollectionBookUI = {}

local root, grid, progressLabel, detailHolder
local cells = {} -- defId -> { def, frame, refresh(discovered) }
local tabButtons = {}
local currentTab = "All"
local lastState = nil
local onEquipCb = nil
local openDetailDef = nil -- the friend whose detail card is currently open
local openEquipBtn = nil  -- its Equip Buddy button (reconciled from server state)

local TABS = { "All", "Pudding Hills", "Goo Coast", "Moonlit Hollow", "Events", "⭐ Family" }

-- Which tab a friend belongs to (All = every launch friend; Events = weekly/
-- event; Family = the three daughter cards; zone tabs = that land's launch).
local function tabMatch(def, tab)
	if tab == "All" then
		return def.ReleaseType == "launch"
	elseif tab == "⭐ Family" then
		return def.ReleaseType == "family"
	elseif tab == "Events" then
		return def.ReleaseType ~= "launch" and def.ReleaseType ~= "family"
	else
		return def.ReleaseType == "launch" and def.Zone == tab
	end
end

-- Count discovered / total across the 48-friend launch roster, for completion %.
local launchRosterCache = nil
local function launchStats(discoveredSet)
	if not launchRosterCache then
		launchRosterCache = SquishyData.getLaunchRoster()
	end
	local disc = 0
	for _, def in ipairs(launchRosterCache) do
		if discoveredSet[def.Id] then
			disc += 1
		end
	end
	return disc, #launchRosterCache
end

local function isRealImage(id)
	return type(id) == "string" and id ~= "" and not string.find(id, "REPLACE_ME")
end

local function loreFor(def)
	return ("A " .. UiTheme.rarityLabel(def.Rarity) .. " friend from " .. (def.Zone or "the Squishy world")
		.. ".  Feeling: " .. (def.Feeling or "Cozy") .. ".  Says \"" .. (def.SignatureSound or "Squish") .. "!\"")
end

-- The art area of a card: real uploaded image if present, else a soft coloured
-- placeholder with the friend's name (so the book works before art is uploaded).
local function artInto(holder, def, discovered)
	for _, c in ipairs(holder:GetChildren()) do
		if not c:IsA("UICorner") then
			c:Destroy()
		end
	end
	if not discovered then
		-- A cute "mystery friend" silhouette: a dark squishy ball with a soft "?".
		local blob = Instance.new("Frame")
		blob.AnchorPoint = Vector2.new(0.5, 0.5)
		blob.Position = UDim2.fromScale(0.5, 0.54)
		blob.Size = UDim2.fromScale(0.66, 0.66)
		blob.BackgroundColor3 = Color3.fromRGB(108, 96, 122)
		blob.BackgroundTransparency = 0.1
		blob.BorderSizePixel = 0
		blob.Parent = holder
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(1, 0)
		bc.Parent = blob
		local q = Instance.new("TextLabel")
		q.BackgroundTransparency = 1
		q.Size = UDim2.fromScale(1, 1)
		q.Font = UiTheme.HeaderFont
		q.TextSize = 34
		q.TextColor3 = Color3.fromRGB(255, 255, 255)
		q.TextTransparency = 0.2
		q.Text = "?"
		q.Parent = blob
		return
	end
	if isRealImage(def.ImageAssetId) then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.ScaleType = Enum.ScaleType.Fit
		img.Image = def.ImageAssetId
		img.Parent = holder
	else
		local nameLbl = Instance.new("TextLabel")
		nameLbl.BackgroundTransparency = 1
		nameLbl.Size = UDim2.fromScale(1, 1)
		nameLbl.Font = UiTheme.HeaderFont
		nameLbl.TextSize = 16
		nameLbl.TextWrapped = true
		nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLbl.TextStrokeColor3 = UiTheme.Colors.Shade
		nameLbl.TextStrokeTransparency = 0.5
		nameLbl.Text = def.DisplayName
		nameLbl.Parent = holder
	end
end

local function makeCell(def)
	local frame = Instance.new("TextButton")
	frame.Name = def.Id
	frame.Size = UDim2.fromOffset(150, 196)
	frame.BackgroundColor3 = UiTheme.Colors.Panel
	frame.BorderSizePixel = 0
	frame.AutoButtonColor = false
	frame.Text = ""
	UiTheme.corner(16, frame)
	local stroke = UiTheme.stroke(UiTheme.rarityColor(def.Rarity), 3, frame)

	-- rarity header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 26)
	header.BackgroundColor3 = UiTheme.rarityColor(def.Rarity)
	header.BorderSizePixel = 0
	header.Parent = frame
	UiTheme.corner(16, header)
	local badge = Instance.new("TextLabel")
	badge.BackgroundTransparency = 1
	badge.Size = UDim2.fromScale(1, 1)
	badge.Font = UiTheme.HeaderFont
	badge.TextSize = 14
	badge.TextColor3 = Color3.fromRGB(255, 255, 255)
	badge.Text = UiTheme.rarityLabel(def.Rarity)
	badge.Parent = header

	-- art holder
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.Position = UDim2.fromOffset(10, 32)
	art.Size = UDim2.fromOffset(130, 116)
	art.BackgroundColor3 = UiTheme.rarityColor(def.Rarity)
	art.BorderSizePixel = 0
	art.Parent = frame
	UiTheme.corner(12, art)
	UiTheme.gradient(Color3.fromRGB(255, 255, 255), UiTheme.rarityColor(def.Rarity), 90, art)

	-- name + number
	local nameLbl = Instance.new("TextLabel")
	nameLbl.BackgroundTransparency = 1
	nameLbl.Position = UDim2.fromOffset(6, 150)
	nameLbl.Size = UDim2.new(1, -12, 0, 22)
	nameLbl.Font = UiTheme.HeaderFont
	nameLbl.TextSize = 14
	nameLbl.TextColor3 = UiTheme.Colors.Ink
	nameLbl.TextWrapped = true
	nameLbl.Parent = frame

	local numLbl = Instance.new("TextLabel")
	numLbl.BackgroundTransparency = 1
	numLbl.Position = UDim2.fromOffset(6, 172)
	numLbl.Size = UDim2.new(1, -12, 0, 18)
	numLbl.Font = UiTheme.BodyFont
	numLbl.TextSize = 12
	numLbl.TextColor3 = UiTheme.Colors.SoftInk
	numLbl.Text = def.CardNumber or ""
	numLbl.Parent = frame

	-- Full uploaded card render: shown (covering the chrome) for discovered
	-- friends that have real art, since the image already has name/stats/number.
	local fullImg = Instance.new("ImageLabel")
	fullImg.Name = "FullCard"
	fullImg.Size = UDim2.fromScale(1, 1)
	fullImg.BackgroundColor3 = UiTheme.Colors.Cream
	fullImg.BorderSizePixel = 0
	fullImg.ScaleType = Enum.ScaleType.Fit
	fullImg.Visible = false
	fullImg.Parent = frame
	UiTheme.corner(16, fullImg)

	-- variant ribbon (Sparkly/Rainbow), top-right; hidden until the friend is upgraded
	local vBadge = Instance.new("TextLabel")
	vBadge.Name = "VariantBadge"
	vBadge.AnchorPoint = Vector2.new(1, 0)
	vBadge.Position = UDim2.fromOffset(144, 30)
	vBadge.Size = UDim2.fromOffset(78, 22)
	vBadge.BackgroundColor3 = UiTheme.Colors.Accent
	vBadge.BorderSizePixel = 0
	vBadge.Font = UiTheme.HeaderFont
	vBadge.TextSize = 13
	vBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	vBadge.ZIndex = 3
	vBadge.Visible = false
	vBadge.Parent = frame
	UiTheme.corner(11, vBadge)
	UiTheme.stroke(Color3.fromRGB(255, 255, 255), 1, vBadge)

	local function refresh(discovered, variantLevel)
		local vl = variantLevel or 0
		local hasArt = discovered and isRealImage(def.ImageAssetId)
		fullImg.Visible = hasArt
		fullImg.Image = hasArt and def.ImageAssetId or ""
		header.Visible = not hasArt
		art.Visible = not hasArt
		nameLbl.Visible = not hasArt
		numLbl.Visible = not hasArt
		if discovered and vl >= 1 then
			stroke.Color = VariantConfig.colorFor(vl)
			vBadge.Visible = true
			vBadge.Text = VariantConfig.iconFor(vl) .. " " .. VariantConfig.nameFor(vl)
			vBadge.BackgroundColor3 = VariantConfig.colorFor(vl)
		else
			stroke.Color = discovered and UiTheme.rarityColor(def.Rarity) or UiTheme.Colors.Locked
			vBadge.Visible = false
		end
		if hasArt then
			return
		end
		if discovered then
			header.BackgroundColor3 = UiTheme.rarityColor(def.Rarity)
			badge.Text = UiTheme.rarityLabel(def.Rarity)
			nameLbl.Text = def.DisplayName
			nameLbl.TextColor3 = UiTheme.Colors.Ink
			art.BackgroundColor3 = UiTheme.rarityColor(def.Rarity)
		else
			header.BackgroundColor3 = UiTheme.PackColor[def.Zone] or UiTheme.Colors.Locked
			badge.Text = "?"
			nameLbl.Text = "? ? ?"
			nameLbl.TextColor3 = UiTheme.Colors.SoftInk
			art.BackgroundColor3 = UiTheme.Colors.Locked
		end
		artInto(art, def, discovered)
	end

	frame.Activated:Connect(function()
		local discovered = lastState and lastState.discovered and lastState.discovered[def.Id]
		if discovered then
			CollectionBookUI.openDetail(def)
		end
	end)

	refresh(false)
	return { def = def, frame = frame, refresh = refresh }
end

function CollectionBookUI.openDetail(def)
	detailHolder:ClearAllChildren()

	local dim = Instance.new("TextButton")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = UiTheme.Colors.Shade
	dim.BackgroundTransparency = 0.4
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Parent = detailHolder
	dim.Activated:Connect(function()
		detailHolder:ClearAllChildren()
		openDetailDef = nil
		openEquipBtn = nil
	end)

	openDetailDef = def

	-- Equip Buddy button, shared by both layouts. Its text is reconciled from the
	-- server's authoritative StateSync in update(), so it can never falsely claim
	-- "Your Buddy" if the equip is declined.
	local function makeEquip(parent, position)
		local equip = Instance.new("TextButton")
		equip.AnchorPoint = Vector2.new(0.5, 1)
		equip.Position = position
		equip.Size = UDim2.fromOffset(220, 48)
		equip.BackgroundColor3 = UiTheme.Colors.AccentDeep
		equip.BorderSizePixel = 0
		equip.Font = UiTheme.HeaderFont
		equip.TextSize = 20
		equip.TextColor3 = Color3.fromRGB(255, 255, 255)
		local isBuddy = lastState and (lastState.equippedBuddyId == def.Id or lastState.equippedBuddyId2 == def.Id)
		equip.Text = isBuddy and "★ Your Buddy" or "Equip Buddy"
		equip.Parent = parent
		UiTheme.corner(24, equip)
		openEquipBtn = equip
		equip.Activated:Connect(function()
			if onEquipCb then
				onEquipCb(def.Id)
			end
		end)
	end

	if isRealImage(def.ImageAssetId) then
		-- The full uploaded card render is the star (it already has the name,
		-- rarity, stats, lore, and number baked in), so we just frame it + Equip.
		local holder = Instance.new("Frame")
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.5)
		holder.Size = UDim2.fromOffset(372, 548)
		holder.BackgroundTransparency = 1
		holder.Parent = detailHolder
		-- Shrink-to-fit on small screens so the card AND its Equip Buddy button
		-- (pinned to the bottom) stay on-screen on phones — the fixed 548-tall
		-- card otherwise runs its bottom (the button) off a short mobile viewport.
		UiTheme.autoFit(holder, 372, 548)

		local img = Instance.new("ImageLabel")
		img.AnchorPoint = Vector2.new(0.5, 0)
		img.Position = UDim2.fromScale(0.5, 0)
		img.Size = UDim2.fromOffset(360, 480)
		img.BackgroundTransparency = 1
		img.ScaleType = Enum.ScaleType.Fit
		img.Image = def.ImageAssetId
		img.Parent = holder

		makeEquip(holder, UDim2.new(0.5, 0, 1, 0))
		return
	end

	local card = UiTheme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(320, 440),
		radius = 22,
	})
	card.Parent = detailHolder
	UiTheme.stroke(UiTheme.rarityColor(def.Rarity), 4, card)
	-- Same shrink-to-fit for the placeholder-art detail (Equip button at bottom).
	UiTheme.autoFit(card, 320, 440)

	local art = Instance.new("Frame")
	art.Position = UDim2.fromOffset(20, 20)
	art.Size = UDim2.fromOffset(280, 220)
	art.BackgroundColor3 = UiTheme.rarityColor(def.Rarity)
	art.BorderSizePixel = 0
	art.Parent = card
	UiTheme.corner(16, art)
	UiTheme.gradient(Color3.fromRGB(255, 255, 255), UiTheme.rarityColor(def.Rarity), 90, art)
	artInto(art, def, true)

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(16, 250)
	name.Size = UDim2.new(1, -32, 0, 30)
	name.Font = UiTheme.HeaderFont
	name.TextSize = 24
	name.TextColor3 = UiTheme.Colors.Ink
	name.Text = def.DisplayName .. "  " .. (def.CardNumber or "")
	name.Parent = card

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(16, 282)
	sub.Size = UDim2.new(1, -32, 0, 22)
	sub.Font = UiTheme.BodyFont
	sub.TextSize = 15
	sub.TextColor3 = UiTheme.Colors.AccentDeep
	local detailVl = (lastState and lastState.variants and lastState.variants[def.Id]) or 0
	local variantPrefix = detailVl >= 1 and (VariantConfig.iconFor(detailVl) .. " " .. VariantConfig.nameFor(detailVl) .. "  •  ") or ""
	sub.Text = variantPrefix .. UiTheme.rarityLabel(def.Rarity) .. "  •  " .. (def.PackName or "") .. "  •  " .. (def.Zone or "")
	sub.Parent = card

	local lore = Instance.new("TextLabel")
	lore.BackgroundTransparency = 1
	lore.Position = UDim2.fromOffset(16, 308)
	lore.Size = UDim2.new(1, -32, 0, 60)
	lore.Font = UiTheme.BodyFont
	lore.TextSize = 14
	lore.TextWrapped = true
	lore.TextColor3 = UiTheme.Colors.SoftInk
	lore.Text = loreFor(def)
	lore.Parent = card

	makeEquip(card, UDim2.new(0.5, 0, 1, -16))
end

local function buildTabs(parent)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(20, 70)
	row.Size = UDim2.new(1, -40, 0, 48)
	row.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.Parent = row

	for _, tabName in ipairs(TABS) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.fromOffset(104, 48) -- 6 tabs now (incl. ⭐ Family) — fit the row
		btn.BackgroundColor3 = UiTheme.Colors.Panel
		btn.BorderSizePixel = 0
		btn.Font = UiTheme.HeaderFont
		btn.TextSize = 14
		btn.TextWrapped = true
		btn.TextColor3 = UiTheme.Colors.SoftInk
		btn.Text = tabName
		btn.Parent = row
		UiTheme.corner(18, btn)
		UiTheme.stroke(UiTheme.Colors.Accent, 2, btn)
		tabButtons[tabName] = btn
		btn.Activated:Connect(function()
			currentTab = tabName
			CollectionBookUI.refresh()
		end)
	end
end

local function cellMatchesTab(def)
	return tabMatch(def, currentTab)
end

function CollectionBookUI.refresh()
	local discoveredSet = (lastState and lastState.discovered) or {}

	-- tab highlight + per-tab discovered/total counts
	for _, tabName in ipairs(TABS) do
		local btn = tabButtons[tabName]
		if btn then
			local d, t = 0, 0
			for _, entry in pairs(cells) do
				if tabMatch(entry.def, tabName) then
					t += 1
					if discoveredSet[entry.def.Id] then
						d += 1
					end
				end
			end
			local active = (tabName == currentTab)
			btn.BackgroundColor3 = active and UiTheme.Colors.AccentDeep or UiTheme.Colors.Panel
			btn.TextColor3 = active and Color3.fromRGB(255, 255, 255) or UiTheme.Colors.SoftInk
			btn.Text = tabName .. "\n" .. d .. " / " .. t
		end
	end

	local variantSet = (lastState and lastState.variants) or {}
	for _, entry in pairs(cells) do
		local visible = cellMatchesTab(entry.def)
		entry.frame.Visible = visible
		if visible then
			entry.refresh(discoveredSet[entry.def.Id] == true, variantSet[entry.def.Id] or 0)
		end
	end

	if progressLabel then
		local disc, total = launchStats(discoveredSet)
		local pct = total > 0 and math.floor(disc / total * 100 + 0.5) or 0
		progressLabel.Text = disc .. " / " .. total .. "  •  " .. pct .. "% complete"
	end
end

function CollectionBookUI.update(state)
	lastState = state
	-- Keep an open detail card's Equip button honest with the authoritative state.
	if openEquipBtn and openDetailDef then
		openEquipBtn.Text = (state and (state.equippedBuddyId == openDetailDef.Id or state.equippedBuddyId2 == openDetailDef.Id)) and "★ Your Buddy" or "Equip Buddy"
	end
	if root and root.Visible then
		CollectionBookUI.refresh()
	elseif progressLabel and state then
		local disc, total = launchStats(state.discovered or {})
		local pct = total > 0 and math.floor(disc / total * 100 + 0.5) or 0
		progressLabel.Text = disc .. " / " .. total .. "  •  " .. pct .. "% complete"
	end
end

function CollectionBookUI.show()
	if not root then
		return
	end
	root.Visible = true
	CollectionBookUI.refresh()
	root.BackgroundTransparency = 1
	TweenService:Create(root, TweenInfo.new(0.2), { BackgroundTransparency = 0.15 }):Play()
end

function CollectionBookUI.hide()
	if root then
		detailHolder:ClearAllChildren()
		openDetailDef = nil
		openEquipBtn = nil
		root.Visible = false
	end
end

function CollectionBookUI.mount(playerGui, onEquip)
	onEquipCb = onEquip

	local screen = Instance.new("ScreenGui")
	screen.Name = "SquishyBook"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.DisplayOrder = 20
	screen.Enabled = true
	screen.Parent = playerGui

	root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = UiTheme.Colors.Shade
	root.BackgroundTransparency = 0.15
	root.BorderSizePixel = 0
	root.Visible = false
	root.Parent = screen

	local panel = UiTheme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(720, 560),
		BackgroundColor3 = UiTheme.Colors.Cream,
		radius = 26,
	})
	panel.Parent = root
	UiTheme.stroke(UiTheme.Colors.Accent, 3, panel)
	UiTheme.autoFit(panel, 720, 560)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(24, 16)
	title.Size = UDim2.fromOffset(360, 40)
	title.Font = UiTheme.HeaderFont
	title.TextSize = 32
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = UiTheme.Colors.AccentDeep
	title.Text = "Squishy Book"
	title.Parent = panel

	progressLabel = Instance.new("TextLabel")
	progressLabel.BackgroundTransparency = 1
	progressLabel.Position = UDim2.new(1, -260, 0, 24)
	progressLabel.Size = UDim2.fromOffset(220, 28)
	progressLabel.Font = UiTheme.HeaderFont
	progressLabel.TextSize = 20
	progressLabel.TextXAlignment = Enum.TextXAlignment.Right
	progressLabel.TextColor3 = UiTheme.Colors.Ink
	progressLabel.Text = "0 / 48 Discovered"
	progressLabel.Parent = panel

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
		CollectionBookUI.hide()
	end)

	buildTabs(panel)

	grid = Instance.new("ScrollingFrame")
	grid.Position = UDim2.fromOffset(20, 128)
	grid.Size = UDim2.new(1, -40, 1, -144)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 8
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = panel
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.fromOffset(150, 196)
	gl.CellPadding = UDim2.fromOffset(14, 14)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.Parent = grid

	-- detail modal layer (on top of the grid)
	detailHolder = Instance.new("Frame")
	detailHolder.Size = UDim2.fromScale(1, 1)
	detailHolder.BackgroundTransparency = 1
	detailHolder.Parent = root

	-- build all cells: 48 launch (sorted) then the event friends
	local order = 0
	local function addCells(list)
		for _, def in ipairs(list) do
			order += 1
			local cell = makeCell(def)
			cell.frame.LayoutOrder = order
			cell.frame.Parent = grid
			cells[def.Id] = cell
		end
	end
	addCells(SquishyData.getLaunchRoster())
	addCells(SquishyData.getEventRoster())
	addCells(SquishyData.getFamilyRoster())

	CollectionBookUI.refresh()
end

return CollectionBookUI
