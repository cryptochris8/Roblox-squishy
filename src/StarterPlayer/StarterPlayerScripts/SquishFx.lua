-- SquishFx
-- Plays the squishy "feel" on the friends in the world: a wobble/squash when
-- squished, a Joy Meter that fills, and a sparkly Happy Pop when they wake up.
-- Driven by the server's SquishResult events (the server stays the authority;
-- the client just makes it feel good) — plus WO-1 "Juice the Squish":
--   • an escalating squash + pitch arc, and an "about to pop" shimmy near full
--   • rarity-scaled Happy Pops with per-friend colour + goo volume
--   • Sparkle Chain floaties (POP x2!) and a confetti ring at x5
--   • telegraphed rare sleepers (gold zZz, sparkle column, snore bubble)
--   • per-friend squish FEEL (deform/elastic/goo dials) so no two feel alike
--   • silly one-in-a-few reactions (spin / hop / jelly wobble + squeaks)
--   • grow-in spawn reveals, and instant local click feedback while you mash

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SquishyData = require(Shared:WaitForChild("SquishyData"))
local SoundConfig = require(Shared:WaitForChild("SoundConfig"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))
local SquishFeel = require(Shared:WaitForChild("SquishFeel"))
local UiTheme = require(script.Parent.UiTheme)
local ToastUI = require(script.Parent.ToastUI)

local SquishFx = {}

local localPlayer = Players.LocalPlayer
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- Rarity ranks (from RarityConfig.SortOrder): common 1, rare 2, epic 3, …
local RARE_RANK = 2
local EPIC_RANK = 3
-- Happy Pop sparkle counts by rarity (before the per-friend goo modifier and
-- the global FX budget). A Legendary pop should look several times bigger.
local RARITY_POP_SPARKLES = {
	common = 26, rare = 40, epic = 60, legendary = 90, mythic = 90, family = 90,
}
-- Joy just before a friend pops, and the "about to pop" threshold (one squish
-- before the pop). Derived from JoyPerSquish so a config change can't strand it.
local LAST_SQUISH_JOY = math.max(0.34, 1 - GameConfig.JoyPerSquish)
local ABOUT_TO_POP = LAST_SQUISH_JOY - 0.03
local GROW_DUR = 0.42

local entries = {} -- objectId -> entry
local revealed = {} -- objectId -> true once its grow-in has played
local newSpawn = {} -- objectId -> true if it appeared AFTER boot (a real respawn)
local booted = false
local revealYawnAt = 0 -- global rate-limit so a burst of stream-ins doesn't yawn in chorus
local lastLocalClick = 0 -- item 9 rate-limit (~10/s)

-- ── FX budget ────────────────────────────────────────────────────────────────
-- One global cap keeps celebration sparkles from stacking into a frame-rate
-- cliff when several friends pop at once (three kids chain-popping on a
-- tablet). Burst counts scale down in the compact/mobile layout and again in
-- Calm Sparkles mode (the gentler-effects toggle in Today's Quests).
local FX_MAX_PER_SECOND = 260
local FX_MIN_BURST = 3 -- a squish always answers with SOMETHING
local recentBursts = {} -- sliding one-second window of { at, count }

local function fxScalar(): number
	local s = UiTheme.isCompact() and 0.5 or 1
	if localPlayer:GetAttribute("CalmSparkles") == true then
		s *= 0.5
	end
	return s
end

local function budgetBurst(requested: number): number
	local now = os.clock()
	local total = 0
	for i = #recentBursts, 1, -1 do
		if now - recentBursts[i].at > 1 then
			table.remove(recentBursts, i)
		else
			total += recentBursts[i].count
		end
	end
	local scalar = fxScalar()
	local allowed = math.max(math.floor(requested * scalar + 0.5), FX_MIN_BURST)
	local ceiling = math.floor(FX_MAX_PER_SECOND * scalar)
	if total + allowed > ceiling then
		allowed = math.clamp(ceiling - total, FX_MIN_BURST, allowed)
	end
	table.insert(recentBursts, { at = now, count = allowed })
	return allowed
end

local function buildBillboard(body, def)
	local gui = Instance.new("BillboardGui")
	gui.Name = "SquishyLabel"
	gui.Size = UDim2.fromOffset(150, 54)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90 -- a distant zZz should beckon across the spread-out lands
	gui.Parent = body

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 24)
	name.Font = UiTheme.HeaderFont
	name.TextSize = 18
	name.TextColor3 = Color3.fromRGB(110, 80, 110)
	name.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	name.TextStrokeTransparency = 0.2
	name.Text = (def and def.DisplayName) or "Squishy Friend"
	name.Parent = gui

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -20, 0, 12)
	barBg.Position = UDim2.new(0, 10, 0, 32)
	barBg.BackgroundColor3 = Color3.fromRGB(240, 225, 235)
	barBg.BorderSizePixel = 0
	barBg.Parent = gui
	UiTheme.corner(6, barBg)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = UiTheme.Colors.Accent
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	UiTheme.corner(6, fill)

	local zzz = Instance.new("TextLabel")
	zzz.Name = "Zzz"
	zzz.BackgroundTransparency = 1
	zzz.Size = UDim2.fromScale(1, 1)
	zzz.Font = UiTheme.HeaderFont
	zzz.TextSize = 13
	zzz.TextColor3 = Color3.fromRGB(150, 150, 200)
	zzz.Text = "z Z z"
	zzz.Parent = barBg

	return fill, zzz
end

-- A cute always-facing-camera face that sits on the friend: bead eyes with a
-- shine, rosy cheeks, and a little mouth. It can switch between a sleepy
-- (closed-eyes) look and an awake (open-eyes, bigger smile) look.
local EYE_COLOR = Color3.fromRGB(64, 48, 64)

local function buildFace(body)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Face"
	gui.Size = UDim2.fromOffset(84, 72)
	gui.StudsOffset = Vector3.new(0, 0.15, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 60
	gui.Parent = body

	local function eye(px: number)
		local open = Instance.new("Frame")
		open.AnchorPoint = Vector2.new(0.5, 0.5)
		open.Position = UDim2.fromScale(px, 0.42)
		open.Size = UDim2.fromOffset(15, 17)
		open.BackgroundColor3 = EYE_COLOR
		open.BorderSizePixel = 0
		open.Parent = gui
		UiTheme.corner(8, open)
		local shine = Instance.new("Frame")
		shine.AnchorPoint = Vector2.new(0.5, 0.5)
		shine.Position = UDim2.fromScale(0.36, 0.3)
		shine.Size = UDim2.fromOffset(5, 5)
		shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		shine.BorderSizePixel = 0
		shine.Parent = open
		UiTheme.corner(3, shine)

		local closed = Instance.new("Frame")
		closed.AnchorPoint = Vector2.new(0.5, 0.5)
		closed.Position = UDim2.fromScale(px, 0.44)
		closed.Size = UDim2.fromOffset(16, 5)
		closed.BackgroundColor3 = EYE_COLOR
		closed.BorderSizePixel = 0
		closed.Parent = gui
		UiTheme.corner(3, closed)
		return open, closed
	end

	local leftOpen, leftClosed = eye(0.3)
	local rightOpen, rightClosed = eye(0.7)

	local function cheek(px: number)
		local c = Instance.new("Frame")
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Position = UDim2.fromScale(px, 0.56)
		c.Size = UDim2.fromOffset(13, 9)
		c.BackgroundColor3 = Color3.fromRGB(255, 150, 175)
		c.BackgroundTransparency = 0.35
		c.BorderSizePixel = 0
		c.Parent = gui
		UiTheme.corner(6, c)
	end
	cheek(0.14)
	cheek(0.86)

	local mouth = Instance.new("Frame")
	mouth.AnchorPoint = Vector2.new(0.5, 0.5)
	mouth.Position = UDim2.fromScale(0.5, 0.64)
	mouth.Size = UDim2.fromOffset(9, 6)
	mouth.BackgroundColor3 = EYE_COLOR
	mouth.BorderSizePixel = 0
	mouth.Parent = gui
	UiTheme.corner(4, mouth)

	local face = {}
	function face.setSleepy()
		leftOpen.Visible = false
		rightOpen.Visible = false
		leftClosed.Visible = true
		rightClosed.Visible = true
		mouth.Size = UDim2.fromOffset(8, 5)
	end
	function face.setAwake()
		leftOpen.Visible = true
		rightOpen.Visible = true
		leftClosed.Visible = false
		rightClosed.Visible = false
		TweenService:Create(mouth, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(18, 10),
		}):Play()
	end
	return face
end

-- ── Aura + snore (telegraph a rare sleeper, and dribble when about to pop) ────
local function ensureAura(entry)
	local body = entry.body
	local em = body:FindFirstChild("AuraSparkle")
	if not em then
		em = Instance.new("ParticleEmitter")
		em.Name = "AuraSparkle"
		em.Texture = SPARKLE
		em.Rate = 0
		em.Lifetime = NumberRange.new(0.7, 1.1)
		em.Speed = NumberRange.new(2, 4)
		em.SpreadAngle = Vector2.new(24, 24)
		em.Acceleration = Vector3.new(0, 3, 0)
		em.Size = NumberSequence.new(1.0)
		em.LightEmission = 0.7
		em.EmissionDirection = Enum.NormalId.Top
		em.Parent = body
	end
	entry.auraEmitter = em
	return em
end

-- mode: "telegraph" (gold column on a rare sleeper) | "abouttopop" (rarity-colour
-- dribble near full) | "off".
local function setAura(entry, mode)
	if not entry.body or not entry.body.Parent then
		return
	end
	local em = ensureAura(entry)
	local scalar = fxScalar()
	if mode == "telegraph" then
		em.Color = ColorSequence.new(Color3.fromRGB(255, 224, 130))
		em.Rate = 7 * scalar
	elseif mode == "abouttopop" then
		em.Color = ColorSequence.new(entry.rarityColor or Color3.fromRGB(255, 240, 205))
		em.Rate = 16 * scalar
	else
		em.Rate = 0
	end
end

local function stopSnore(entry)
	entry.snoreOn = false
end

-- Epic+ sleepers puff a little snore bubble that inflates and pops on a loop.
local function startSnore(entry)
	if entry.snoreOn or not entry.body or not entry.body.Parent then
		return
	end
	entry.snoreOn = true
	local gui = Instance.new("BillboardGui")
	gui.Name = "Snore"
	gui.Size = UDim2.fromOffset(30, 30)
	gui.StudsOffset = Vector3.new(1.0, 1.0, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 70
	gui.Parent = entry.body
	local bubble = Instance.new("Frame")
	bubble.AnchorPoint = Vector2.new(0.5, 0.5)
	bubble.Position = UDim2.fromScale(0.5, 0.5)
	bubble.Size = UDim2.fromScale(0.25, 0.25)
	bubble.BackgroundColor3 = Color3.fromRGB(212, 232, 255)
	bubble.BackgroundTransparency = 0.25
	bubble.BorderSizePixel = 0
	bubble.Parent = gui
	UiTheme.corner(20, bubble)
	entry.snoreGui = gui
	task.spawn(function()
		while entry.snoreOn and entry.body and entry.body.Parent do
			bubble.Size = UDim2.fromScale(0.25, 0.25)
			bubble.BackgroundTransparency = 0.25
			TweenService:Create(bubble, TweenInfo.new(1.0, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(1, 1),
			}):Play()
			task.wait(1.0)
			if not (entry.snoreOn and entry.body and entry.body.Parent) then
				break
			end
			TweenService:Create(bubble, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
				Size = UDim2.fromScale(1.25, 1.25),
				BackgroundTransparency = 1,
			}):Play()
			task.wait(0.9)
		end
		if entry.snoreGui then
			entry.snoreGui:Destroy()
			entry.snoreGui = nil
		end
	end)
end

-- ── Reveal helpers ───────────────────────────────────────────────────────────
local function sparkle(body, count, color)
	if not body or not body.Parent then
		return
	end
	-- Reuse this body's emitter when it still exists (per-body pooling: bursts
	-- are frequent, and the emitter dies with the body on pop/respawn anyway).
	local emitter = body:FindFirstChild("SquishSparkle")
	if not emitter then
		emitter = Instance.new("ParticleEmitter")
		emitter.Name = "SquishSparkle"
		emitter.Texture = SPARKLE
		emitter.Rate = 0
		emitter.Lifetime = NumberRange.new(0.5, 0.9)
		emitter.Speed = NumberRange.new(6, 15)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.Size = NumberSequence.new(1.4)
		emitter.LightEmission = 0.6
		emitter.Parent = body
	end
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(255, 232, 180))
	emitter:Emit(budgetBurst(count))
end

-- A short positional sound on the friend (3D, so it plays where the squish happens).
local function playSound(body, id, volume, pitch)
	if not body or not body.Parent or not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.PlaybackSpeed = pitch or 1
	s.RollOffMaxDistance = 80
	s.Parent = body
	s:Play()
	Debris:AddItem(s, 3)
end

-- A brief, gentle rate-limited yawn+poof for a friend that just grew in.
local function maybeYawn(body)
	local now = os.clock()
	if now - revealYawnAt < 0.5 then
		return
	end
	revealYawnAt = now
	sparkle(body, 8, Color3.fromRGB(255, 240, 210))
	playSound(body, SoundConfig.pick(SoundConfig.SquishVariants) or SoundConfig.Squish, 0.3, 0.8)
end

-- A brief fading ground splat under a popped friend, tinted by its DecalPreset.
local function groundSplat(body, color)
	if not body or not body.Parent then
		return
	end
	local pos = body.Position
	local splat = Instance.new("Part")
	splat.Anchored = true
	splat.CanCollide = false
	splat.CanQuery = false
	splat.CanTouch = false
	splat.CastShadow = false
	splat.Material = Enum.Material.SmoothPlastic
	splat.Shape = Enum.PartType.Cylinder
	splat.Size = Vector3.new(0.3, 5.4, 5.4)
	splat.CFrame = CFrame.new(pos.X, pos.Y - 2.2, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	splat.Color = color
	splat.Transparency = 0.3
	splat.Parent = Workspace
	TweenService:Create(splat, TweenInfo.new(1.4, Enum.EasingStyle.Quad), {
		Transparency = 1,
		Size = Vector3.new(0.3, 7, 7),
	}):Play()
	Debris:AddItem(splat, 1.5)
end

local function floatingCoins(body, coins)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(130, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = body
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = UiTheme.HeaderFont
	lbl.TextSize = 26
	lbl.TextColor3 = UiTheme.Colors.CoinDeep
	lbl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.1
	lbl.Text = "+" .. coins
	lbl.Parent = gui
	TweenService:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, 9, 0),
	}):Play()
	TweenService:Create(lbl, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(gui, 1)
end

-- "POP x3!" floatie for the local player's own chain (item 3). Never a
-- chain-LOST message — a lapsed chain just quietly stops appearing.
local function chainFloatie(body, chain)
	if not body or not body.Parent then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 48)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5.6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = body
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = UiTheme.HeaderFont
	lbl.TextSize = 30
	lbl.TextColor3 = Color3.fromRGB(255, 246, 210)
	lbl.TextStrokeColor3 = UiTheme.Colors.AccentDeep
	lbl.TextStrokeTransparency = 0.1
	lbl.Text = "POP x" .. chain .. "!"
	lbl.Parent = gui
	TweenService:Create(gui, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, 10.6, 0),
	}):Play()
	TweenService:Create(lbl, TweenInfo.new(1.0), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(gui, 1.1)
end

local function confettiRing(body)
	sparkle(body, 50, Color3.fromRGB(255, 200, 120))
	task.delay(0.06, function()
		sparkle(body, 30, Color3.fromRGB(150, 200, 255))
	end)
end

local function goldFlash(body)
	if not body or not body.Parent then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 225, 150)
	light.Brightness = 6
	light.Range = 16
	light.Parent = body
	TweenService:Create(light, TweenInfo.new(0.7), { Brightness = 0 }):Play()
	Debris:AddItem(light, 0.8)
end

-- ── Silly reactions (item 7) — cosmetic only, no reward difference ──────────
local function applyReaction(entry, def)
	local tag = ((def and def.ThemeTag) or ""):lower()
	local cat = (def and def.Category) or ""
	local now = os.clock()
	local kind
	if tag:find("bat") or tag:find("bunny") or tag:find("ghost") or tag:find("phantom") or tag:find("dream") then
		kind = "spin"
	elseif cat == "goo_fidget" or tag:find("goo") or tag:find("jelly") or tag:find("slime") or tag:find("blob") or tag:find("sticky") then
		kind = "wobble"
	else
		kind = "hop"
	end
	if kind == "spin" then
		entry.spinAt = now
		entry.spinDur = 0.55
	elseif kind == "hop" then
		entry.hopAt = now
	else -- jelly wobble: an exaggerated, longer squash-spring
		entry.squashAmp = (entry.squashAmp or 0.2) * 1.5
		entry.springDur = 0.66
		entry.springFreq = 7
		entry.squashAt = now
	end
	-- ~half the time an extra "achoo!" squeak on top
	if entry.body and math.random(2) == 1 then
		playSound(entry.body, SoundConfig.pick(SoundConfig.SquishVariants) or SoundConfig.Squish, 0.4, 1.5)
	end
end

-- Dress a friend's Body with its face, name label, and Joy bar. Safe to call
-- again when a body streams back in — it only rebuilds if this body is new.
local function attachFx(model, objectId, body)
	if not body or not body.Parent then
		return
	end
	local existing = entries[objectId]
	if existing and existing.body == body then
		return -- this body is already dressed
	end
	local def = SquishyData.getById(model:GetAttribute("DefId"))
	local fill, zzz = buildBillboard(body, def)
	-- Card-faithful mesh bodies have their face baked into the texture — no
	-- billboard face for them (the zZz + Joy bar still show sleepy/awake).
	local face = nil
	if model:GetAttribute("BakedFace") ~= true then
		face = buildFace(body)
	end

	local rarity = def and def.Rarity or "common"
	local rank = (RarityConfig[rarity] and RarityConfig[rarity].SortOrder) or 1

	-- The breathing bob and squish-spring run in one Heartbeat loop (see init),
	-- moving the WHOLE model so ears, wings, and drips ride along.
	local entry = {
		model = model,
		body = body,
		fill = fill,
		fillBaseColor = fill.BackgroundColor3,
		zzz = zzz,
		face = face,
		baseScale = model:GetScale(),
		basePivot = model:GetPivot(),
		phase = (string.byte(objectId, #objectId) or 0) * 0.7,
		rank = rank,
		rarityColor = def and UiTheme.rarityColor(rarity) or nil,
		feel = SquishFeel.get(model:GetAttribute("DefId") or ""),
		squashAt = nil,
		aboutToPop = false,
	}
	entries[objectId] = entry

	-- A re-streamed friend may already be mid-meter; show what the server knows.
	local joy = math.clamp(model:GetAttribute("Joy") or 0, 0, 1)
	fill.Size = UDim2.new(joy, 0, 1, 0)
	if joy > 0 then
		if face then
			face.setAwake()
		end
		zzz.Visible = false
		if joy >= ABOUT_TO_POP and not model:GetAttribute("Popped") then
			entry.aboutToPop = true
			setAura(entry, "abouttopop")
		end
	else
		if face then
			face.setSleepy()
		end
		-- Telegraph a rare sleeper: gold zZz + a soft sparkle column, and a snore
		-- bubble for the really special ones.
		if rank >= RARE_RANK then
			zzz.TextColor3 = Color3.fromRGB(255, 215, 120)
			setAura(entry, "telegraph")
			if rank >= EPIC_RANK then
				startSnore(entry)
			end
		end
	end

	-- Grow-in reveal (item 8.1) — only a genuinely FRESH spawn (a Happy-Pop
	-- respawn or an event golden), only once, only while still sleepy. The spawn
	-- timestamp keeps far-land friends that simply streamed in as you arrived from
	-- all snapping-and-growing at once (they were spawned long ago at world build).
	local spawnedAt = model:GetAttribute("SpawnedAt")
	local fresh = type(spawnedAt) == "number" and (Workspace:GetServerTimeNow() - spawnedAt) < 2
	if newSpawn[objectId] and fresh and not revealed[objectId] and joy == 0 and not model:GetAttribute("Popped") then
		revealed[objectId] = true
		entry.growAt = os.clock()
		model:ScaleTo(entry.baseScale * 0.1) -- start tiny so there's no full-size flash
		maybeYawn(body)
	end
end

-- Instant local click feedback (item 9): a micro-squash + soft "pmf" the moment
-- YOU click, before the server's authoritative SquishResult round-trips.
local function localSquishFeedback(objectId)
	local now = os.clock()
	if now - lastLocalClick < 0.1 then
		return -- ~10 pmfs a second, tops
	end
	lastLocalClick = now
	local e = entries[objectId]
	if e and e.body and e.body.Parent then
		e.microAt = now
		playSound(e.body, SoundConfig.pick(SoundConfig.SquishVariants) or SoundConfig.Squish, 0.35, 1.0 + math.random() * 0.06)
	end
end

-- Weak keys so a popped friend's ClickDetector drops out on GC (no leak, and we
-- never mutate the replicated instance).
local wiredClicks = setmetatable({}, { __mode = "k" })
local function connectClientClick(detector, objectId)
	if wiredClicks[detector] then
		return
	end
	wiredClicks[detector] = true
	-- ClickDetector.MouseClick fires locally for the player who clicked, so this
	-- gives instant feedback without waiting on the server.
	detector.MouseClick:Connect(function(plr)
		if plr == localPlayer then
			localSquishFeedback(objectId)
		end
	end)
end

local function register(model, isNewSpawn)
	if not model:IsA("Model") then
		return
	end
	task.spawn(function()
		-- With StreamingEnabled the Model container reaches the client right away,
		-- but its attributes can lag by a beat — wait briefly for the id.
		local deadline = os.clock() + 6
		local objectId = model:GetAttribute("ObjectId")
		while type(objectId) ~= "string" and os.clock() < deadline and model.Parent do
			task.wait(0.1)
			objectId = model:GetAttribute("ObjectId")
		end
		if type(objectId) ~= "string" then
			return
		end
		if isNewSpawn then
			newSpawn[objectId] = true
		end
		-- The Body part only streams in when the player comes near (and is removed
		-- when they leave, taking our client-built face with it) — so dress the
		-- friend now if the body is here, and again every time it streams back in.
		-- Also wire the ClickDetector for instant local feedback.
		model.ChildAdded:Connect(function(child)
			if child.Name == "Body" and child:IsA("BasePart") then
				task.defer(attachFx, model, objectId, child)
			elseif child:IsA("ClickDetector") then
				connectClientClick(child, objectId)
			end
		end)
		local existingClick = model:FindFirstChildWhichIsA("ClickDetector")
		if existingClick then
			connectClientClick(existingClick, objectId)
		end
		attachFx(model, objectId, model:FindFirstChild("Body") or model.PrimaryPart)
	end)
end

-- The whole-model pop: swell up while every part fades out (the server keeps
-- the model alive long enough for this to finish).
local function popModel(entry)
	local model = entry.model
	local parts = {}
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			parts[#parts + 1] = { p = p, t0 = p.Transparency }
		end
	end
	task.spawn(function()
		local start = os.clock()
		while model.Parent do
			local k = math.min(1, (os.clock() - start) / 0.3)
			model:ScaleTo(entry.baseScale * (1 + 0.5 * k))
			for _, q in ipairs(parts) do
				if q.p.Parent then
					q.p.Transparency = q.t0 + (1 - q.t0) * k
				end
			end
			if k >= 1 then
				break
			end
			task.wait()
		end
	end)
end

function SquishFx.handle(result)
	local entry = entries[result.objectId]
	if not entry then
		return
	end
	local body = entry.body
	if entry.fill then
		entry.fill.Size = UDim2.new(math.clamp(result.joy or 0, 0, 1), 0, 1, 0)
	end
	if entry.zzz then
		entry.zzz.Visible = false
	end
	if entry.face then
		entry.face.setAwake()
	end

	if result.popped then
		local def = SquishyData.getById(result.defId)
		local rarity = def and def.Rarity or "common"
		local rank = (RarityConfig[rarity] and RarityConfig[rarity].SortOrder) or 1
		local feel = entry.feel or SquishFeel.get(result.defId or "")

		-- Rarity-scaled Happy Pop, volume nudged by the friend's gooLevel.
		local base = RARITY_POP_SPARKLES[rarity] or 26
		local count = math.floor(base * (0.7 + (feel.goo or 0.6) * 0.5) + 0.5)
		local pColor = SquishFeel.particleColor(def) or (def and UiTheme.rarityColor(rarity)) or nil
		sparkle(body, count, pColor)
		if rank >= RARE_RANK then
			-- a second white pop-burst for the sparkly ones
			task.delay(0.05, function()
				sparkle(body, math.floor(count * 0.4), Color3.fromRGB(255, 255, 255))
			end)
		end
		local sColor = SquishFeel.splatColor(def) or pColor
		if sColor then
			groundSplat(body, sColor)
		end

		local chain = result.chain or 1
		local popPitch = 1.04 + math.random() * 0.08 + math.min(chain - 1, 6) * 0.03
		playSound(body, SoundConfig.pick(SoundConfig.HappyPopVariants) or SoundConfig.HappyPop, 0.6, popPitch)

		if rank >= EPIC_RANK then
			goldFlash(body)
			-- a layered second pop = a little "ta-da"
			task.delay(0.12, function()
				playSound(body, SoundConfig.pick(SoundConfig.HappyPopVariants) or SoundConfig.HappyPop, 0.5, 0.82)
			end)
			if result.byUserId == localPlayer.UserId then
				local nm = (RarityConfig[rarity] and RarityConfig[rarity].DisplayName) or "Sparkly"
				local article = nm:match("^[AEIOUaeiou]") and "An" or "A" -- "An Epic", "A Legendary"
				ToastUI.show("WOW! " .. article .. " " .. nm .. " Happy Pop!", "celebration")
			end
		end

		-- ~1-in-12 extra-silly: a helium-pitched signature squish + confetti sneeze
		if math.random(12) == 1 then
			local sigPool = def and def.SignatureSound and SoundConfig.SignatureSounds
				and SoundConfig.SignatureSounds[def.SignatureSound]
			playSound(body, SoundConfig.pick(sigPool) or SoundConfig.pick(SoundConfig.SquishVariants) or SoundConfig.Squish, 0.6, 1.7)
			task.delay(0.04, function()
				sparkle(body, 16, Color3.fromRGB(255, 200, 235))
			end)
		end

		if result.byUserId == localPlayer.UserId then
			if result.coins then
				floatingCoins(body, result.coins)
			end
			if chain >= 2 then
				chainFloatie(body, chain)
			end
			if chain >= 5 then
				confettiRing(body)
			end
		end

		setAura(entry, "off")
		stopSnore(entry)
		if result.coSquish then
			-- a bigger shared celebration; a helper sees their own coins float up
			-- (the popper's coins/chain already showed above)
			confettiRing(body)
			if result.byUserId == localPlayer.UserId then
				ToastUI.show("Squished together! ✨", "celebration")
			elseif result.coCredit and result.coCredit[localPlayer.UserId] then
				floatingCoins(body, result.coCredit[localPlayer.UserId])
			end
		end
		entries[result.objectId] = nil -- leave the anim loop before the pop swell
		popModel(entry)
	else
		local def = SquishyData.getById(entry.model:GetAttribute("DefId"))
		local feel = entry.feel or SquishFeel.get(entry.model:GetAttribute("DefId") or "")
		local joy = math.clamp(result.joy or 0, 0, 1)
		local t = math.clamp(joy / LAST_SQUISH_JOY, 0, 1)

		-- Escalating squash arc (0.16 → 0.24), scaled by per-friend deformability;
		-- rebound speed keyed off elasticity.
		local arc = 0.16 + 0.08 * t
		local deformFactor = 0.62 + (feel.deform or 0.85) * 0.45
		entry.squashAmp = arc * deformFactor
		entry.springDur = 0.55 - (feel.elastic or 0.6) * 0.25
		entry.springFreq = 6 + (feel.elastic or 0.6) * 5
		entry.squashAt = os.clock()

		sparkle(body, 6, Color3.fromRGB(255, 240, 205))

		-- Escalating pitch (0.96 → 1.15) with a hair of jitter so it never repeats.
		local pitch = 0.96 + 0.19 * t + (math.random() - 0.5) * 0.03
		local sigPool = def and def.SignatureSound and SoundConfig.SignatureSounds
			and SoundConfig.SignatureSounds[def.SignatureSound]
		local squishId = SoundConfig.pick(sigPool) or SoundConfig.pick(SoundConfig.SquishVariants) or SoundConfig.Squish
		playSound(body, squishId, 0.7, pitch)

		-- Waking clears the sleeper telegraph; near-full enters "about to pop".
		if entry.rank and entry.rank >= EPIC_RANK then
			stopSnore(entry)
		end
		if entry.zzz then
			entry.zzz.TextColor3 = Color3.fromRGB(150, 150, 200)
		end
		if joy >= ABOUT_TO_POP then
			entry.aboutToPop = true
			setAura(entry, "abouttopop")
		else
			entry.aboutToPop = false
			setAura(entry, "off")
		end

		-- ~1-in-6 silly reaction on a plain squish
		if math.random(6) == 1 then
			applyReaction(entry, def)
		end
	end
end

local function squashCurve(t, amp, dur, freq)
	if t < 0.07 then
		return 1 - (t / 0.07) * amp
	else
		local k = (t - 0.07) / (dur - 0.07)
		return 1 - amp * (1 - k) * math.cos(k * freq)
	end
end

local function growEase(g)
	local c1 = 1.70158
	local c3 = c1 + 1
	local x = g - 1
	local e = 1 + c3 * x * x * x + c1 * x * x
	return 0.1 + 0.9 * e
end

function SquishFx.init()
	local folder = Workspace:WaitForChild("Squishies")
	for _, model in ipairs(folder:GetChildren()) do
		register(model, false) -- the world's starting friends: no grow-in
	end
	booted = true
	folder.ChildAdded:Connect(function(model)
		register(model, booted) -- anything that appears now is a real spawn
	end)
	folder.ChildRemoved:Connect(function(model)
		local id = model:GetAttribute("ObjectId")
		if type(id) == "string" then
			entries[id] = nil
			revealed[id] = nil
			newSpawn[id] = nil
		end
	end)

	-- One loop animates every friend: a breathing bob (whole model, so ears and
	-- drips ride along), the squish-spring, grow-in, the about-to-pop shimmy, and
	-- any silly hop/spin — all composed into one scale + one pivot per frame.
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, e in pairs(entries) do
			if e.model.Parent and e.body.Parent then
				local scaleMul = 1
				if e.growAt then
					local g = (now - e.growAt) / GROW_DUR
					if g >= 1 then
						e.growAt = nil
					else
						scaleMul *= growEase(g)
					end
				end
				if e.squashAt then
					local st = now - e.squashAt
					local dur = e.springDur or 0.45
					if st >= dur then
						e.squashAt = nil
					else
						scaleMul *= squashCurve(st, e.squashAmp or 0.16, dur, e.springFreq or 8)
					end
				end
				if e.microAt then
					local mt = (now - e.microAt) / 0.12
					if mt >= 1 then
						e.microAt = nil
					else
						scaleMul *= (1 - 0.05 * math.sin(mt * math.pi))
					end
				end
				if e.aboutToPop then
					local sp = 20 + (1 - (e.feel and e.feel.burst or 0.79)) * 10
					scaleMul *= (1 + math.sin(now * sp + e.phase) * 0.02)
					if e.fill then
						e.fill.BackgroundColor3 = e.fillBaseColor:Lerp(Color3.fromRGB(255, 255, 255), 0.35 + 0.35 * math.sin(now * 12))
					end
				end

				local scaleActive = e.growAt or e.squashAt or e.microAt or e.aboutToPop
				if scaleActive then
					e.model:ScaleTo(e.baseScale * scaleMul)
					e.scaleWasActive = true
				elseif e.scaleWasActive then
					e.model:ScaleTo(e.baseScale)
					e.scaleWasActive = false
				end

				local bob = math.sin(now * 1.9 + e.phase) * 0.22
				if e.aboutToPop then
					bob += math.sin(now * 9 + e.phase) * 0.05
				end
				local hop = 0
				if e.hopAt then
					local ht = (now - e.hopAt) / 0.4
					if ht >= 1 then
						e.hopAt = nil
					else
						hop = math.sin(ht * math.pi) * 0.8
					end
				end
				local yaw = 0
				if e.spinAt then
					local yt = (now - e.spinAt) / (e.spinDur or 0.55)
					if yt >= 1 then
						e.spinAt = nil
					else
						yaw = yt * math.pi * 2
					end
				end
				e.model:PivotTo(e.basePivot * CFrame.new(0, bob + hop, 0) * CFrame.Angles(0, yaw, 0))
			end
		end
	end)
end

return SquishFx
