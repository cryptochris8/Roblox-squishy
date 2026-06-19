-- SquishFx
-- Plays the squishy "feel" on the friends in the world: a wobble/squash when
-- squished, a Joy Meter that fills, and a sparkly Happy Pop when they wake up.
-- Driven entirely by the server's SquishResult events (the server stays the
-- authority; the client just makes it feel good).

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SquishyData = require(Shared:WaitForChild("SquishyData"))
local SoundConfig = require(Shared:WaitForChild("SoundConfig"))
local UiTheme = require(script.Parent.UiTheme)

local SquishFx = {}

local localPlayer = Players.LocalPlayer
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local BASE_SIZE = Vector3.new(4, 4, 4)

local entries = {} -- objectId -> { body, fill, zzz }

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
	-- A re-streamed friend may already be mid-meter; show what the server knows.
	local joy = math.clamp(model:GetAttribute("Joy") or 0, 0, 1)
	fill.Size = UDim2.new(joy, 0, 1, 0)
	if joy > 0 then
		if face then
			face.setAwake()
		end
		zzz.Visible = false
	elseif face then
		face.setSleepy()
	end

	-- The breathing bob and squish-spring run in one Heartbeat loop (see init),
	-- moving the WHOLE model so ears, wings, and drips ride along.
	entries[objectId] = {
		model = model,
		body = body,
		fill = fill,
		zzz = zzz,
		face = face,
		baseScale = model:GetScale(),
		basePivot = model:GetPivot(),
		phase = (string.byte(objectId, #objectId) or 0) * 0.7,
		squashAt = nil,
	}
end

local function register(model)
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
		-- The Body part only streams in when the player comes near (and is removed
		-- when they leave, taking our client-built face with it) — so dress the
		-- friend now if the body is here, and again every time it streams back in.
		model.ChildAdded:Connect(function(child)
			if child.Name == "Body" and child:IsA("BasePart") then
				task.defer(attachFx, model, objectId, child)
			end
		end)
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

local function sparkle(body, count, color)
	if not body or not body.Parent then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(6, 15)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Size = NumberSequence.new(1.4)
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(255, 232, 180))
	emitter.LightEmission = 0.6
	emitter.Parent = body
	emitter:Emit(count)
	Debris:AddItem(emitter, 1)
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
		local color = def and UiTheme.rarityColor(def.Rarity) or nil
		sparkle(body, 26, color)
		playSound(body, SoundConfig.pick(SoundConfig.HappyPopVariants) or SoundConfig.HappyPop, 0.6, 1.04 + math.random() * 0.08)
		if result.byUserId == localPlayer.UserId and result.coins then
			floatingCoins(body, result.coins)
		end
		entries[result.objectId] = nil -- leave the anim loop before the pop swell
		popModel(entry)
	else
		entry.squashAt = os.clock() -- the Heartbeat loop plays the squish-spring
		sparkle(body, 6, Color3.fromRGB(255, 240, 205))
		playSound(body, SoundConfig.pick(SoundConfig.SquishVariants) or SoundConfig.Squish, 0.7, 0.96 + math.random() * 0.08)
	end
end

function SquishFx.init()
	local folder = Workspace:WaitForChild("Squishies")
	for _, model in ipairs(folder:GetChildren()) do
		register(model)
	end
	folder.ChildAdded:Connect(register)
	folder.ChildRemoved:Connect(function(model)
		local id = model:GetAttribute("ObjectId")
		if type(id) == "string" then
			entries[id] = nil
		end
	end)

	-- One loop animates every friend: a gentle breathing bob (whole model, so
	-- ears and drips ride along) and the squish-spring when someone squishes.
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, e in pairs(entries) do
			if e.model.Parent and e.body.Parent then
				if e.squashAt then
					local t = now - e.squashAt
					if t >= 0.45 then
						e.squashAt = nil
						e.model:ScaleTo(e.baseScale)
					elseif t < 0.07 then
						e.model:ScaleTo(e.baseScale * (1 - (t / 0.07) * 0.16))
					else
						local k = (t - 0.07) / 0.38
						e.model:ScaleTo(e.baseScale * (1 - 0.16 * (1 - k) * math.cos(k * 7)))
					end
				end
				local bob = math.sin(now * 1.9 + e.phase) * 0.22
				e.model:PivotTo(e.basePivot * CFrame.new(0, bob, 0))
			end
		end
	end)
end

return SquishFx
