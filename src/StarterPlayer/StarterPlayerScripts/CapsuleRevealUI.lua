-- CapsuleRevealUI ("The Wobble Count", doc 15 §5)
-- The Sparkle Capsule ceremony. The capsule starts PEARL — identical for every
-- tier — and every extra wobble means a better friend (1 wobble = cozy, 5 =
-- mythic), with colour bleeding in and a chime pitch-ladder rising per wobble.
-- Countable suspense, honest by construction: no telegraph channel may ever
-- overshoot the rarity the player actually got (RevealConfig's honesty rule).
-- Duplicates stay a happy "Friendship Bonus" (Sparkly -> Rainbow shine-ups);
-- never gambling-flavored, no misses, no near-miss fakery.
--
-- Safety net kept from v1: the pcall + watchdog guarantee the reveal can never
-- strand on screen; canDismiss stops the opening tap from insta-closing it; a
-- tap DURING the ceremony fast-forwards to the card (a skip is never silent —
-- one arrival pop still plays); Esc works; the stage auto-fits phones.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local UiTheme = require(script.Parent.UiTheme)
local StreamerMode = require(script.Parent.StreamerMode)
local RevealFx = require(script.Parent.RevealFx)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local VariantConfig = require(Shared:WaitForChild("VariantConfig"))
local SoundConfig = require(Shared:WaitForChild("SoundConfig"))
local RevealConfig = require(Shared:WaitForChild("RevealConfig"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))
local PatternConfig = require(Shared:WaitForChild("PatternConfig"))

local CapsuleRevealUI = {}

local PEARL = Color3.fromRGB(248, 244, 238)
local WHITE = Color3.fromRGB(255, 255, 255)

local screen, layer, stage
local callbacks = {} -- { onOpenAgain = fn(capsuleKey), onShowOdds = fn(capsuleKey) }
local soundTemplates = {} -- id -> pre-warmed Sound template (see mount)
local busy = false
local queued = nil -- 1-deep: a result arriving mid-reveal plays next (v1 dropped it)
local currentTl = nil
local currentDismiss = nil

-- ── Timeline: every wait/tween of a ceremony runs through this so ONE tap can
-- fast-forward the whole thing to its final state. ─────────────────────────────
local Timeline = {}
Timeline.__index = Timeline

function Timeline.new()
	return setmetatable({ skipped = false, tweens = {} }, Timeline)
end

function Timeline:wait(t)
	if self.skipped then
		return
	end
	local deadline = os.clock() + t
	while os.clock() < deadline do
		if self.skipped then
			return
		end
		task.wait()
	end
end

function Timeline:tween(inst, info, props)
	if self.skipped then
		for k, v in pairs(props) do
			pcall(function()
				inst[k] = v
			end)
		end
		return
	end
	local tw = TweenService:Create(inst, info, props)
	table.insert(self.tweens, { tw = tw, inst = inst, props = props })
	tw:Play()
end

function Timeline:skip()
	if self.skipped then
		return
	end
	self.skipped = true
	for _, e in ipairs(self.tweens) do
		pcall(function()
			e.tw:Cancel()
		end)
		if e.inst and e.inst.Parent then
			for k, v in pairs(e.props) do
				pcall(function()
					e.inst[k] = v
				end)
			end
		end
	end
end

-- ── Small helpers ─────────────────────────────────────────────────────────────

local function isRealImage(id)
	return type(id) == "string" and id ~= "" and not string.find(id, "REPLACE_ME")
end

-- A short 2D sound. The chime ladder + count-ticks reuse ONE template id with
-- PlaybackSpeed (zero new uploads); clones of the pre-warmed template ring over
-- each other and Debris cleans them. Cloning a loaded template sidesteps the
-- "SoundId set + Play same frame" landmine for every note after mount.
local function uiSound(id, volume, pitch)
	if not id or id == "" or not screen then
		return
	end
	local template = soundTemplates[id]
	local s = template and template:Clone() or Instance.new("Sound")
	if not template then
		s.SoundId = id
	end
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch or 1
	s.Parent = screen
	s:Play()
	Debris:AddItem(s, 4)
end

local function chime(pitch, volume)
	uiSound(SoundConfig.Chime, volume or 0.5, pitch)
end

local function happyPop(pitch, volume)
	uiSound(SoundConfig.pick(SoundConfig.HappyPopVariants) or SoundConfig.HappyPop, volume or 0.5, pitch)
end

-- The ceremony recipe for this specific result: the tier table + skin flags.
local function tierFor(result)
	local base = RevealConfig.Tiers[result.rarity] or RevealConfig.Tiers.common
	local t = table.clone(base)
	t.rarityColor = UiTheme.rarityColor(result.rarity)
	t.chimeBase = RevealConfig.ChimeBasePitch
	t.isGift = result.giftFrom ~= nil
	if t.isGift then
		t.chimeBase = RevealConfig.GiftChimeBasePitch
	end
	-- Already-known friend, no shine-up: keep the honest wobble count but cut the
	-- ceremony fat — repeat-open cadence beats pageantry when you know the friend.
	if result.isNew ~= true and result.variantUpgraded ~= true and not t.isGift then
		t.preHold = 0
		t.slowMo = 0
		t.risePx = 0
		t.cardStyle = "pop"
		t.rayLayers = 0
		t.starRain = false
	end
	return t
end

-- "✨ Sparkly" / "🌈 Rainbow" ribbon, stamped in by extrasBeat.
local function variantBadge(parent, icon, name, color, position)
	local vb = Instance.new("TextLabel")
	vb.AnchorPoint = Vector2.new(1, 0)
	vb.Position = position
	vb.Size = UDim2.fromOffset(118, 28)
	vb.BackgroundColor3 = color
	vb.BorderSizePixel = 0
	vb.Font = UiTheme.HeaderFont
	vb.TextSize = 15
	vb.TextColor3 = WHITE
	vb.Text = icon .. " " .. name
	vb.ZIndex = 12
	vb.Parent = parent
	UiTheme.corner(14, vb)
	UiTheme.stroke(WHITE, 2, vb)
	return vb
end

local function cardArt(parent, result)
	local art = Instance.new("Frame")
	art.Position = UDim2.fromOffset(20, 18)
	art.Size = UDim2.fromOffset(260, 200)
	art.BackgroundColor3 = UiTheme.rarityColor(result.rarity)
	art.BorderSizePixel = 0
	art.Parent = parent
	UiTheme.corner(16, art)
	UiTheme.gradient(WHITE, UiTheme.rarityColor(result.rarity), 90, art)
	if isRealImage(result.imageAssetId) then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.ScaleType = Enum.ScaleType.Fit
		img.Image = result.imageAssetId
		img.Parent = art
	else
		local nameLbl = Instance.new("TextLabel")
		nameLbl.BackgroundTransparency = 1
		nameLbl.Size = UDim2.fromScale(1, 1)
		nameLbl.Font = UiTheme.HeaderFont
		nameLbl.TextSize = 24
		nameLbl.TextWrapped = true
		nameLbl.TextColor3 = WHITE
		nameLbl.TextStrokeColor3 = UiTheme.Colors.Shade
		nameLbl.TextStrokeTransparency = 0.55
		nameLbl.Text = result.displayName
		nameLbl.Parent = art
	end
	return art
end

local function headlineText(result, variantIcon, variantName)
	if result.giftFrom then
		return "💝 A gift from " .. StreamerMode.mask(result.giftFrom) .. "!"
	elseif result.switcherooStamp then
		return "🚂 A traveler stepped off the Express!"
	elseif result.isNew then
		return "New Friend Discovered!"
	elseif result.variantUpgraded then
		return variantIcon .. " " .. variantName .. "!"
	else
		return "Friendship Bonus!"
	end
end

-- ── The ceremony ──────────────────────────────────────────────────────────────

function CapsuleRevealUI.play(result, onClose)
	if not layer then
		return
	end
	if busy then
		-- v1 silently dropped a result arriving mid-reveal (a gift during a
		-- capsule open lost its moment). Now: queue it, fast-forward the current
		-- ceremony, give the kid a beat to see the finished card, then advance.
		queued = { result = result, onClose = onClose }
		if currentTl then
			currentTl:skip()
		end
		local d = currentDismiss
		if d then
			task.delay(0.9, function()
				d(true)
			end)
		end
		return
	end
	busy = true
	layer:ClearAllChildren()
	stage:ClearAllChildren()

	local tier = tierFor(result)
	local variantLevel = result.variantLevel or 0
	local variantUpgraded = result.variantUpgraded == true
	local variantName = VariantConfig.nameFor(variantLevel)
	local variantColor = VariantConfig.colorFor(variantLevel)
	local variantIcon = VariantConfig.iconFor(variantLevel)

	local tl = Timeline.new()
	currentTl = tl
	local startedAt = os.clock()

	local closed = false
	local canDismiss = false
	local escConn = nil
	local cleanups = {} -- orbiters / rays / star-rain stoppers

	local function dismiss(force)
		if closed or (not force and not canDismiss) then
			return
		end
		closed = true
		busy = false
		tl.skipped = true
		if currentTl == tl then
			currentTl = nil
			currentDismiss = nil
		end
		for _, fn in ipairs(cleanups) do
			pcall(fn)
		end
		if escConn then
			escConn:Disconnect()
			escConn = nil
		end
		if layer then
			layer:ClearAllChildren()
		end
		if stage then
			stage:ClearAllChildren()
		end
		if onClose then
			onClose()
		end
		-- A queued result (gift-during-reveal, capsule chain) plays next.
		if queued then
			local q = queued
			queued = nil
			task.defer(function()
				CapsuleRevealUI.play(q.result, q.onClose)
			end)
		end
	end
	currentDismiss = dismiss

	-- One tap: during the ceremony = fast-forward (never silent — burstBeat still
	-- pops); once the card is up (canDismiss) = close. The 0.15s guard stops the
	-- very tap that opened the capsule from doing either.
	local function tapped()
		if canDismiss then
			dismiss()
		elseif os.clock() - startedAt > 0.15 and not tl.skipped then
			tl:skip()
		end
	end

	-- Watchdog: tier-aware, still absolute. The reveal can never strand.
	task.delay((tier.total or 3) + 8, function()
		dismiss(true)
	end)

	escConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.Escape and not gameProcessed then
			tapped()
		end
	end)

	-- Dim: the world hushes deeper for rarer friends.
	local dim = Instance.new("TextButton")
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = UiTheme.Colors.Shade
	dim.BackgroundTransparency = 1
	dim.BorderSizePixel = 0
	dim.Text = ""
	dim.ZIndex = 1
	dim.AutoButtonColor = false
	dim.Active = true
	dim.Parent = layer
	dim.Activated:Connect(tapped)
	dim.MouseButton1Click:Connect(tapped)
	TweenService:Create(dim, TweenInfo.new(0.3), { BackgroundTransparency = tier.dimT }):Play()

	-- The capsule group: under-glow halos + the PEARL shell (+ a gift bow).
	-- Identical for every tier at t=0 — the whole point.
	local group = Instance.new("Frame")
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.new(0.5, 0, 0.5, -28)
	group.Size = UDim2.fromOffset(150, 150)
	group.BackgroundTransparency = 1
	group.Parent = stage

	local function halo(size, transparency)
		local h = Instance.new("Frame")
		h.AnchorPoint = Vector2.new(0.5, 0.5)
		h.Position = UDim2.fromScale(0.5, 0.5)
		h.Size = UDim2.fromOffset(size, size)
		h.BackgroundColor3 = PEARL
		h.BackgroundTransparency = transparency
		h.BorderSizePixel = 0
		h.ZIndex = 2
		h.Parent = group
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = h
		return h
	end
	local haloB = halo(230, 0.92)
	local haloA = halo(190, 0.85)

	local capsule = Instance.new("Frame")
	capsule.AnchorPoint = Vector2.new(0.5, 0.5)
	capsule.Position = UDim2.fromScale(0.5, 0.5)
	capsule.Size = UDim2.fromOffset(150, 150)
	capsule.BackgroundColor3 = PEARL
	capsule.BorderSizePixel = 0
	capsule.ZIndex = 3
	capsule.Parent = group
	UiTheme.corner(75, capsule)
	local capStroke = UiTheme.stroke(WHITE, 4, capsule)
	UiTheme.gradient(WHITE, PEARL, 90, capsule)

	if tier.isGift then
		-- A little rose bow so a gift feels wrapped.
		for _, rot in ipairs({ -35, 35 }) do
			local loop = Instance.new("Frame")
			loop.AnchorPoint = Vector2.new(0.5, 0.5)
			loop.Position = UDim2.new(0.5, rot < 0 and -20 or 20, 0, -2)
			loop.Size = UDim2.fromOffset(34, 20)
			loop.BackgroundColor3 = UiTheme.Colors.Accent
			loop.BorderSizePixel = 0
			loop.Rotation = rot
			loop.ZIndex = 4
			loop.Parent = capsule
			UiTheme.corner(10, loop)
		end
		local knot = Instance.new("Frame")
		knot.AnchorPoint = Vector2.new(0.5, 0.5)
		knot.Position = UDim2.new(0.5, 0, 0, -2)
		knot.Size = UDim2.fromOffset(16, 16)
		knot.BackgroundColor3 = UiTheme.Colors.AccentDeep
		knot.BorderSizePixel = 0
		knot.ZIndex = 5
		knot.Parent = capsule
		UiTheme.corner(8, knot)
	end

	-- Where the pop happens (the capsule may have risen by then).
	local popPos = UDim2.new(0.5, 0, 0.5, -28 - (tier.risePx or 0))

	task.spawn(function()
		local ok, err = pcall(function()
			-- ── Intro: drop in ──────────────────────────────────────────────
			-- A traveler arrives by train: the toy whistle announces the Express.
			if result.switcherooStamp and not tl.skipped then
				uiSound(SoundConfig.TrainWhistle, 0.45)
			end
			tl:tween(group, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, 0, 0.5, -28),
			})
			tl:wait(0.2)

			-- ── The wobble count ────────────────────────────────────────────
			local orbCleanup = nil
			for i = 1, tier.wobbles do
				if closed then
					return
				end
				local amp = 10 + i
				local f = i / tier.wobbles
				-- Light leaks from INSIDE the shell: halos + stroke tint toward
				-- the true colour; the pearl shell itself holds until the pop.
				local glowColor = PEARL:Lerp(tier.rarityColor, f)
				if tier.isGift then
					glowColor = glowColor:Lerp(UiTheme.Colors.Accent, 0.4)
				end
				local glowInfo = TweenInfo.new(tier.wobbleDur * 2, Enum.EasingStyle.Sine)
				tl:tween(haloA, glowInfo, { BackgroundColor3 = glowColor, BackgroundTransparency = 0.85 - 0.4 * f })
				tl:tween(haloB, glowInfo, { BackgroundColor3 = glowColor, BackgroundTransparency = 0.92 - 0.3 * f })
				tl:tween(capStroke, glowInfo, { Color = glowColor })
				if not tl.skipped then
					chime(tier.chimeBase + (i - 1) * RevealConfig.ChimePitchStep, 0.5)
				end
				tl:tween(capsule, TweenInfo.new(tier.wobbleDur * 0.5, Enum.EasingStyle.Sine), { Rotation = amp })
				tl:wait(tier.wobbleDur * 0.5)
				tl:tween(capsule, TweenInfo.new(tier.wobbleDur * 0.5, Enum.EasingStyle.Sine), { Rotation = -amp })
				tl:wait(tier.wobbleDur * 0.5)
				if tier.wobbles >= 3 and not tl.skipped then
					RevealFx.ring(stage, UDim2.new(0.5, 0, 0.5, -28), tier.rarityColor)
					if i == 2 and not orbCleanup then
						orbCleanup = RevealFx.orbiters(stage, UDim2.new(0.5, 0, 0.5, -28), 8, tier.rarityColor)
						table.insert(cleanups, orbCleanup)
					end
				end
			end
			tl:tween(capsule, TweenInfo.new(0.1), { Rotation = 0 })
			tl:wait(0.1)
			if closed then
				return
			end

			-- ── Pre-burst: rise / rays / held breath / slow-mo ──────────────
			if (tier.risePx or 0) > 0 then
				local riseDur = tier.risePx >= 60 and 0.8 or 0.2
				tl:tween(group, TweenInfo.new(riseDur, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Position = popPos,
				})
				tl:wait(riseDur)
				if (tier.rayLayers or 0) > 0 and not tl.skipped then
					table.insert(cleanups, RevealFx.rays(stage, popPos, tier.rarityColor, tier.rayLayers))
				end
			end
			if tier.starRain and not tl.skipped then
				local palette
				if tier.hearts then
					palette = { UiTheme.Rarity.family, WHITE }
				elseif result.rarity == "mythic" then
					palette = { UiTheme.Rarity.mythic, Color3.fromRGB(150, 190, 235) }
				else
					palette = { tier.rarityColor, WHITE }
				end
				table.insert(cleanups, RevealFx.starRain(stage, palette))
			end
			if (tier.preHold or 0) > 0 then
				tl:wait(tier.preHold)
			end
			if (tier.slowMo or 0) > 0 then
				if not tl.skipped then
					chime(0.7, 0.35) -- the low inhale under the inflate
				end
				tl:tween(capsule, TweenInfo.new(tier.slowMo, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Size = UDim2.fromOffset(177, 177),
				})
				tl:wait(tier.slowMo)
			end
			if closed then
				return
			end

			-- ── The pop (a skip is never silent: exactly one pop still plays) ──
			-- The orbit ring retires here on BOTH paths — a skip mid-wobble must
			-- not leave sparkles circling a capsule that no longer exists.
			if orbCleanup then
				pcall(orbCleanup)
				orbCleanup = nil
			end
			if tl.skipped then
				happyPop(1.05, 0.5)
			else
				-- Design units, not AbsoluteSize — the stage's auto-fit already scales.
				local capSize = (tier.slowMo or 0) > 0 and 177 or 150
				tl:tween(capsule, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Size = UDim2.fromOffset(capSize, math.floor(capSize * 0.82)),
				})
				tl:wait(0.09)
				tl:tween(capsule, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
					Size = UDim2.fromOffset(0, 0),
				})
				tl:wait(0.13)
				local rank = (RarityConfig[result.rarity] and RarityConfig[result.rarity].SortOrder) or 1
				if tier.hearts or tier.isGift then
					RevealFx.hearts(stage, popPos, tier.burst)
				else
					RevealFx.burst(stage, popPos, tier.burst, tier.rarityColor)
				end
				RevealFx.ring(stage, popPos, tier.rarityColor)
				if rank >= 4 then
					RevealFx.flash(stage) -- the ONE soft veil this reveal is allowed
					task.delay(0.1, function()
						if not closed then
							RevealFx.ring(stage, popPos, tier.rarityColor)
						end
					end)
					happyPop(1.0, 0.55)
					chime(1.5, 0.5)
				elseif rank == 3 then
					happyPop(1.1, 0.5) -- SquishFx's epic double-pop, on-screen
					task.delay(0.12, function()
						if not closed then
							happyPop(0.82, 0.45)
						end
					end)
				elseif rank == 2 then
					happyPop(1.1, 0.5)
					chime(1.3, 0.4)
				else
					happyPop(1.15, 0.5)
				end
				if (tier.afterBurst or 0) > 0 then
					task.delay(0.08, function()
						if not closed then
							local c = result.rarity == "mythic" and tier.rarityColor or WHITE
							RevealFx.burst(stage, popPos, tier.afterBurst, c)
						end
					end)
				end
			end
			group:Destroy()

			-- ── The card ────────────────────────────────────────────────────
			local bigArt = isRealImage(result.imageAssetId)
			local cardW = bigArt and 322 or 300
			local cardH = bigArt and 430 or 380

			local holder = Instance.new("Frame")
			holder.AnchorPoint = Vector2.new(0.5, 0.5)
			holder.Position = UDim2.fromScale(0.5, 0.5)
			holder.Size = UDim2.fromOffset(0, cardH)
			holder.BackgroundTransparency = 1
			holder.ZIndex = 10
			holder.Parent = stage

			local flipDur = tier.flipDur or 0
			if tier.cardStyle ~= "pop" and flipDur > 0 and not tl.skipped then
				-- Card-back tease: a pearl back with a ✨ mark collapses away...
				local back = Instance.new("Frame")
				back.AnchorPoint = Vector2.new(0.5, 0.5)
				back.Position = UDim2.fromScale(0.5, 0.5)
				back.Size = UDim2.fromOffset(cardW, cardH)
				back.BackgroundColor3 = PEARL
				back.ZIndex = 10
				back.Parent = stage
				UiTheme.corner(22, back)
				UiTheme.stroke(tier.rarityColor, 4, back)
				local mark = Instance.new("TextLabel")
				mark.BackgroundTransparency = 1
				mark.Size = UDim2.fromScale(1, 1)
				mark.Font = UiTheme.HeaderFont
				mark.TextSize = 64
				mark.Text = "✨"
				mark.ZIndex = 11
				mark.Parent = back
				tl:tween(back, TweenInfo.new(flipDur * 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Size = UDim2.fromOffset(0, cardH),
				})
				tl:wait(flipDur * 0.45)
				back:Destroy()
			end

			-- ...and the real card flips/pops in.
			local content
			if bigArt then
				local img = Instance.new("ImageLabel")
				img.BackgroundTransparency = 1
				img.Size = UDim2.fromScale(1, 1)
				img.ScaleType = Enum.ScaleType.Fit
				img.Image = result.imageAssetId
				img.ZIndex = 10
				img.Parent = holder
				content = holder
			else
				local card = UiTheme.panel({
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = UiTheme.Colors.Cream,
					radius = 22,
				})
				card.ZIndex = 10
				card.Parent = holder
				UiTheme.stroke(variantLevel >= 1 and variantColor or tier.rarityColor, 4, card)
				cardArt(card, result)
				local sub = Instance.new("TextLabel")
				sub.BackgroundTransparency = 1
				sub.Position = UDim2.fromOffset(12, 240)
				sub.Size = UDim2.new(1, -24, 0, 60)
				sub.Font = UiTheme.BodyFont
				sub.TextSize = 16
				sub.TextWrapped = true
				sub.TextColor3 = UiTheme.Colors.Ink
				sub.ZIndex = 11
				if result.isNew then
					sub.Text = result.displayName .. " (" .. (result.cardNumber or "") .. ") joined your Squishy Book!"
				elseif variantUpgraded then
					sub.Text = result.displayName .. " is now " .. variantName .. "!"
				else
					sub.Text = "You already know " .. result.displayName .. "!"
				end
				sub.Parent = card
				content = card
			end

			local entryDur = tier.cardStyle == "pop" and 0.3 or math.max(flipDur * 0.55, 0.25)
			tl:tween(holder, TweenInfo.new(entryDur, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(cardW, cardH),
			})
			tl:wait(entryDur + 0.02)
			if not tl.skipped then
				uiSound(SoundConfig.CapsuleReveal, 0.5)
				if (tier.shineDur or 0) > 0 then
					RevealFx.shineSweep(content, tier.shineDur)
				end
			end

			-- Headline above the card.
			local headline = Instance.new("TextLabel")
			headline.AnchorPoint = Vector2.new(0.5, 0.5)
			headline.Position = UDim2.new(0.5, 0, 0.5, -(cardH / 2) - 36)
			headline.Size = UDim2.fromOffset(540, 40)
			headline.BackgroundTransparency = 1
			headline.Font = UiTheme.HeaderFont
			headline.TextSize = 28
			headline.TextColor3 = WHITE
			headline.TextStrokeColor3 = variantUpgraded and variantColor or UiTheme.Colors.AccentDeep
			headline.TextStrokeTransparency = 0.15
			headline.ZIndex = 11
			headline.Text = headlineText(result, variantIcon, variantName)
			headline.Parent = stage

			-- The rarity's own storybook line, for brand-new friends.
			if result.isNew and RarityConfig[result.rarity] then
				local rarityLine = Instance.new("TextLabel")
				rarityLine.AnchorPoint = Vector2.new(0.5, 0.5)
				rarityLine.Position = UDim2.new(0.5, 0, 0.5, -(cardH / 2) - 10)
				rarityLine.Size = UDim2.fromOffset(540, 24)
				rarityLine.BackgroundTransparency = 1
				rarityLine.Font = UiTheme.BodyFont
				rarityLine.TextSize = 17
				rarityLine.TextColor3 = WHITE
				rarityLine.TextStrokeColor3 = UiTheme.Colors.Shade
				rarityLine.TextStrokeTransparency = 0.35
				rarityLine.ZIndex = 11
				rarityLine.Text = RarityConfig[result.rarity].KidFriendlyReveal
				rarityLine.Parent = stage
			end

			-- Practice ribbon: owner rehearsal reveals can never pose as real pulls.
			if result.demo then
				local ribbon = Instance.new("TextLabel")
				ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
				ribbon.Position = UDim2.new(0.5, -(cardW / 2) + 30, 0.5, -(cardH / 2) + 24)
				ribbon.Size = UDim2.fromOffset(120, 28)
				ribbon.BackgroundColor3 = UiTheme.Colors.SoftInk
				ribbon.BorderSizePixel = 0
				ribbon.Rotation = -12
				ribbon.Font = UiTheme.HeaderFont
				ribbon.TextSize = 15
				ribbon.TextColor3 = WHITE
				ribbon.Text = "Practice ✨"
				ribbon.ZIndex = 13
				ribbon.Parent = stage
				UiTheme.corner(14, ribbon)
			end

			-- ── Extras: variant stamp + coin count-up ───────────────────────
			if variantLevel >= 1 then
				tl:wait(0.25)
				local badgePos = UDim2.new(0.5, cardW / 2 + 46, 0.5, -(cardH / 2) + 20)
				local badge = variantBadge(stage, variantIcon, variantName, variantColor, badgePos)
				if not tl.skipped and variantUpgraded then
					badge.Size = UDim2.fromOffset(170, 40)
					tl:tween(badge, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						Size = UDim2.fromOffset(118, 28),
					})
					RevealFx.burst(stage, badgePos + UDim2.fromOffset(-59, 14), 10, variantColor)
					if variantLevel >= 2 then
						RevealFx.shineSweep(content, 0.5) -- the Rainbow gets a second gleam
					end
				end
			end

			-- ── Sparkle Pattern beat: a NEW pattern shimmers onto the card ──
			if result.patternIsNew and result.patternId then
				local pat = PatternConfig.get(result.patternId)
				if pat then
					tl:wait(0.2)
					local pBadge = Instance.new("TextLabel")
					pBadge.AnchorPoint = Vector2.new(1, 0)
					pBadge.Position = UDim2.new(0.5, cardW / 2 + 46, 0.5, -(cardH / 2) + 56)
					pBadge.Size = UDim2.fromOffset(118, 28)
					pBadge.BackgroundColor3 = pat.badgeColor
					pBadge.BorderSizePixel = 0
					pBadge.Font = UiTheme.HeaderFont
					pBadge.TextSize = 13
					pBadge.TextColor3 = WHITE
					pBadge.Text = "✨ " .. pat.name
					pBadge.ZIndex = 12
					pBadge.Parent = stage
					UiTheme.corner(14, pBadge)
					UiTheme.stroke(WHITE, 2, pBadge)
					if not tl.skipped then
						pBadge.Size = UDim2.fromOffset(170, 40)
						tl:tween(pBadge, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
							Size = UDim2.fromOffset(118, 28),
						})
						RevealFx.burst(stage, UDim2.new(0.5, cardW / 2 - 13, 0.5, -(cardH / 2) + 70), 12, pat.badgeColor)
						RevealFx.shineSweep(content, 0.45)
						chime(1.6, 0.35)
					end
				end
			end

			local totalCoins = (result.bonusCoins or 0) + (result.patternBonusCoins or 0)
			if totalCoins > 0 then
				local coinLine = Instance.new("TextLabel")
				coinLine.AnchorPoint = Vector2.new(0.5, 0.5)
				coinLine.Position = UDim2.new(0.5, 0, 0.5, (cardH / 2) + 28)
				coinLine.Size = UDim2.fromOffset(400, 30)
				coinLine.BackgroundTransparency = 1
				coinLine.Font = UiTheme.HeaderFont
				coinLine.TextSize = 22
				coinLine.TextColor3 = UiTheme.Colors.Coin
				coinLine.TextStrokeColor3 = UiTheme.Colors.Shade
				coinLine.TextStrokeTransparency = 0.3
				coinLine.ZIndex = 11
				coinLine.Text = "+0 Sparkle Coins"
				coinLine.Parent = stage
				if tl.skipped then
					coinLine.Text = "+" .. totalCoins .. " Sparkle Coins"
				else
					RevealFx.countUp(coinLine, 0, totalCoins, 0.5, function(v)
						return "+" .. v .. " Sparkle Coins"
					end, function()
						chime(1.8, 0.15)
					end)
				end
			end

			-- ── Switcheroo traveler: the Travel Stamp line ABOVE the headline
			-- (below the card it z-fought the buttons — review catch). The
			-- from-name is a CROSS-SERVER name StreamerMode.mask can't alias
			-- (it only knows this server's players), so Streamer Mode hides it
			-- outright; it only exists for Roblox friends in the first place.
			if type(result.switcherooStamp) == "table" then
				local stamp = result.switcherooStamp
				local text
				if type(stamp.from) == "string" and stamp.from ~= "" then
					if StreamerMode.isOn() then
						text = "🚂 Once loved by a faraway friend!"
					else
						text = "🚂 Once loved by " .. stamp.from .. "!"
					end
				else
					text = "🚂 A traveler from a faraway world!"
				end
				local stampLine = Instance.new("TextLabel")
				stampLine.AnchorPoint = Vector2.new(0.5, 0.5)
				stampLine.Position = UDim2.new(0.5, 0, 0.5, -(cardH / 2) - 62)
				stampLine.Size = UDim2.fromOffset(460, 26)
				stampLine.BackgroundTransparency = 1
				stampLine.Font = UiTheme.BodyFont
				stampLine.TextSize = 16
				stampLine.TextColor3 = WHITE
				stampLine.TextStrokeColor3 = UiTheme.Colors.Shade
				stampLine.TextStrokeTransparency = 0.3
				stampLine.ZIndex = 11
				stampLine.Text = text
				stampLine.Parent = stage
			end

			-- ── Buttons ─────────────────────────────────────────────────────
			local function button(text, x, w, primary)
				local b = Instance.new("TextButton")
				b.AnchorPoint = Vector2.new(0.5, 0.5)
				b.Position = UDim2.new(0.5, x, 0.5, (cardH / 2) + 68)
				b.Size = UDim2.fromOffset(w, 48)
				b.BackgroundColor3 = primary and UiTheme.Colors.AccentDeep or UiTheme.Colors.Accent
				b.BorderSizePixel = 0
				b.Font = UiTheme.HeaderFont
				b.TextSize = primary and 22 or 17
				b.TextColor3 = WHITE
				b.Text = text
				b.ZIndex = 12
				b.Active = true
				b.Parent = stage
				UiTheme.corner(24, b)
				return b
			end

			-- "Open another": present only when it's YOUR capsule, you can afford
			-- it, and it isn't a rehearsal. Absent — never greyed, never teased.
			local canChain = not tier.isGift
				and not result.demo
				and type(result.capsuleKey) == "string"
				and type(result.cost) == "number"
				and type(result.coinsAfter) == "number"
				and result.coinsAfter >= result.cost
				and callbacks.onOpenAgain ~= nil

			local yay
			if canChain then
				yay = button("Yay!", -105, 180, true)
				local again = button("Open another! ✨ " .. result.cost, 105, 190, false)
				again.Activated:Connect(function()
					if not canDismiss then
						return
					end
					local key = result.capsuleKey
					dismiss()
					callbacks.onOpenAgain(key)
				end)
			else
				yay = button("Yay!", 0, 200, true)
			end
			yay.Activated:Connect(function()
				dismiss()
			end)
			yay.MouseButton1Click:Connect(function()
				dismiss()
			end)

			if type(result.capsuleKey) == "string" and not result.demo and callbacks.onShowOdds then
				local odds = Instance.new("TextButton")
				odds.AnchorPoint = Vector2.new(0.5, 0.5)
				odds.Position = UDim2.new(0.5, 0, 0.5, (cardH / 2) + 104)
				odds.Size = UDim2.fromOffset(200, 24)
				odds.BackgroundTransparency = 1
				odds.Font = UiTheme.BodyFont
				odds.TextSize = 15
				odds.TextColor3 = WHITE
				odds.TextStrokeColor3 = UiTheme.Colors.Shade
				odds.TextStrokeTransparency = 0.4
				odds.Text = "What's inside?"
				odds.ZIndex = 12
				odds.Active = true
				odds.Parent = stage
				local key = result.capsuleKey
				odds.Activated:Connect(function()
					callbacks.onShowOdds(key)
				end)
			end

			canDismiss = true
		end)
		if not ok then
			warn("[CapsuleRevealUI] reveal failed: " .. tostring(err))
			dismiss(true)
		end
	end)
end

function CapsuleRevealUI.mount(playerGui, mountCallbacks)
	callbacks = mountCallbacks or {}
	screen = Instance.new("ScreenGui")
	screen.Name = "CapsuleReveal"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.DisplayOrder = 60 -- above the HUD (0), Book (20) and Toast (50)
	screen.Parent = playerGui

	layer = Instance.new("Frame")
	layer.Size = UDim2.fromScale(1, 1)
	layer.BackgroundTransparency = 1
	layer.Parent = screen

	-- The ceremony lives on a stage that shrinks to fit small screens (the
	-- headline sits ~270 above centre and the buttons ~320 below). Two review
	-- catches, both inherited from v1: (1) the stage must be ANCHORED at the
	-- screen centre — UIScale scales about the AnchorPoint, so a default (0,0)
	-- anchor shoved the whole shrunken ceremony into a phone's top-left corner;
	-- (2) the ceremony is cleared per reveal, so the content lives in a CHILD of
	-- the scaled root — v1 called stage:ClearAllChildren() and destroyed its own
	-- AutoFit UIScale on the first reveal.
	local stageRoot = Instance.new("Frame")
	stageRoot.Name = "Stage"
	stageRoot.AnchorPoint = Vector2.new(0.5, 0.5)
	stageRoot.Position = UDim2.fromScale(0.5, 0.5)
	stageRoot.Size = UDim2.fromScale(1, 1)
	stageRoot.BackgroundTransparency = 1
	stageRoot.Parent = screen
	UiTheme.autoFit(stageRoot, 560, 660)

	stage = Instance.new("Frame")
	stage.Name = "Content"
	stage.Size = UDim2.fromScale(1, 1)
	stage.BackgroundTransparency = 1
	stage.Parent = stageRoot

	-- Warm the ceremony's sounds now (doc 14 §2: a Sound played the same frame
	-- its SoundId is set can be silently eaten while the asset streams in — and
	-- the FIRST chime of the ladder is the one that must never be). uiSound
	-- clones these warm templates instead of building cold Sounds from strings.
	local ids = { SoundConfig.Chime, SoundConfig.CapsuleReveal, SoundConfig.HappyPop }
	for _, id in ipairs(SoundConfig.HappyPopVariants) do
		table.insert(ids, id)
	end
	for _, id in ipairs(ids) do
		if id and id ~= "" and not soundTemplates[id] then
			local s = Instance.new("Sound")
			s.Name = "RevealTemplate"
			s.SoundId = id
			s.Volume = 0
			s.Parent = screen
			soundTemplates[id] = s
		end
	end
	task.spawn(function()
		local list = {}
		for _, s in pairs(soundTemplates) do
			table.insert(list, s)
		end
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync(list)
		end)
	end)
end

return CapsuleRevealUI
