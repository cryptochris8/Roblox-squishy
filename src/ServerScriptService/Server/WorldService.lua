-- WorldService (SERVER)
-- Builds a simple, cozy Pudding Hills starter zone out of placeholder parts:
-- a pastel ground, soft hill mounds, a Sparkle Capsule machine, a Soft Dumpling
-- guide, a player spawn, and the pads where sleepy squishy friends appear.
-- Returns the things Main needs to wire up (spawn pad CFrames + the two prompts).

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local WorldService = {}

-- Small helper to make an anchored, smooth, soft-looking part.
local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(p :: any)[key] = value
	end
	return p
end

local function floatingLabel(text: string, color: Color3, parent: BasePart, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(190, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 22
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
end

function WorldService.build()
	-- Cozy storybook lighting + soft post-processing (all free + built-in). Wrapped
	-- in pcall so a cosmetic hiccup can NEVER stop the world from building.
	-- (Lighting.Technology can't be assigned from a script at runtime — set it to
	-- Future in Studio's Lighting properties if you want nicer shadows.)
	pcall(function()
		Lighting.Brightness = 2.5
		Lighting.ClockTime = 16.8 -- warm golden-hour storybook light
		Lighting.GeographicLatitude = 14
		Lighting.Ambient = Color3.fromRGB(196, 176, 178)
		Lighting.OutdoorAmbient = Color3.fromRGB(238, 210, 196)
		Lighting.ExposureCompensation = 0.25
		Lighting.EnvironmentDiffuseScale = 1
		Lighting.EnvironmentSpecularScale = 0.85
		Lighting.FogEnd = 1800

		-- Create-or-update a lighting child so this is safe to run more than once.
		local function ensure(parent: Instance, className: string, name: string, props)
			local inst = parent:FindFirstChild(name)
			if not inst then
				inst = Instance.new(className)
				inst.Name = name
				inst.Parent = parent
			end
			for key, value in pairs(props) do
				(inst :: any)[key] = value
			end
			return inst
		end

		-- Soft hazy air for depth and dreaminess.
		ensure(Lighting, "Atmosphere", "Atmosphere", {
			Density = 0.42, Offset = 0.2,
			Color = Color3.fromRGB(252, 230, 214), -- warm cream-peach haze
			Decay = Color3.fromRGB(236, 176, 150), -- warm decay pulls the sky off blue toward peach
			Glare = 0.2, Haze = 2.4,
		})
		-- Pastel sky with a big, gentle sun.
		ensure(Lighting, "Sky", "Sky", { SunAngularSize = 16, MoonAngularSize = 11 })
		-- Warm, lightly saturated storybook grade.
		ensure(Lighting, "ColorCorrectionEffect", "Grade", {
			Brightness = 0.02, Contrast = 0.04, Saturation = 0.1,
			TintColor = Color3.fromRGB(255, 238, 224), -- warm storybook grade
		})
		-- Soft glow on the brightest spots (suits the "sparkle" theme).
		ensure(Lighting, "BloomEffect", "Bloom", { Intensity = 0.6, Size = 24, Threshold = 1.25 })
		-- Gentle sun halo.
		ensure(Lighting, "SunRaysEffect", "SunRays", { Intensity = 0.08, Spread = 0.85 })
		-- Dreamy fluffy clouds (Clouds live under Terrain, not Lighting).
		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			ensure(terrain, "Clouds", "Clouds", {
				Cover = 0.5, Density = 0.42,
				Color = Color3.fromRGB(255, 210, 210), -- soft dusty-pink storybook clouds
			})
		end
	end)

	-- Remove Studio's default Baseplate so our pastel ground is the only floor. Its
	-- grid texture sits at the same height (y=0) and was z-fighting through / showing
	-- its checkerboard past the edges of our ground.
	local oldBaseplate = Workspace:FindFirstChild("Baseplate")
	if oldBaseplate then
		oldBaseplate:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "PuddingHills"
	folder.Parent = Workspace

	-- Ground — soft creamy peach, extra-wide so the hill ring sits on land.
	local ground = part({
		Name = "Ground",
		Size = Vector3.new(320, 4, 320),
		Position = Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(255, 238, 214), -- warm cream, matching the storybook valley floor
	})
	ground.Parent = folder

	-- Rolling "cream-bowl" hills: half-buried pastel domes ringing the cozy valley.
	-- Placed beyond the play area (radius > 55) so they frame the world without
	-- blocking the pads, capsule, or spawn. CanCollide off so nothing snags on them.
	local hillRng = Random.new(2026)
	-- Warm golden/honey/butterscotch dunes, matching the storybook Pudding Hills plate.
	local hillPalette = {
		Color3.fromRGB(247, 193, 116), -- golden butterscotch
		Color3.fromRGB(255, 214, 150), -- honey
		Color3.fromRGB(255, 228, 178), -- warm cream-gold
		Color3.fromRGB(243, 184, 120), -- caramel
		Color3.fromRGB(255, 236, 201), -- pale cream-gold
		Color3.fromRGB(250, 204, 138), -- soft amber
	}
	local hillCount = 16
	for i = 1, hillCount do
		local angle = (i / hillCount) * math.pi * 2 + hillRng:NextNumber(-0.18, 0.18)
		local radius = hillRng:NextNumber(58, 104)
		local size = hillRng:NextNumber(26, 52)
		local mound = part({
			Name = "Hill" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			Position = Vector3.new(
				math.cos(angle) * radius,
				-size * hillRng:NextNumber(0.34, 0.46),
				math.sin(angle) * radius
			),
			Color = hillPalette[((i - 1) % #hillPalette) + 1],
			CanCollide = false,
		})
		mound.Parent = folder
	end

	-- Player spawn.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.Position = Vector3.new(0, 0.5, 34)
	spawn.Color = Color3.fromRGB(255, 200, 222)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.Neutral = true
	spawn.Parent = folder

	-- Sparkle Capsule machine.
	local capsuleModel = Instance.new("Model")
	capsuleModel.Name = "SparkleCapsule"
	local capsuleBase = part({
		Name = "Base",
		Size = Vector3.new(6, 7, 6),
		Position = Vector3.new(0, 3.5, -12),
		Color = Color3.fromRGB(255, 180, 205),
	})
	capsuleBase.Parent = capsuleModel
	local capsuleDome = part({
		Name = "Dome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6.5, 6.5, 6.5),
		Position = Vector3.new(0, 8.5, -12),
		Color = Color3.fromRGB(190, 230, 255),
		Transparency = 0.35,
		Material = Enum.Material.Glass,
		CanCollide = false,
	})
	capsuleDome.Parent = capsuleModel
	capsuleModel.PrimaryPart = capsuleBase
	floatingLabel("Sparkle Capsule", Color3.fromRGB(225, 90, 150), capsuleBase, 6.5)

	local capsulePrompt = Instance.new("ProximityPrompt")
	capsulePrompt.ActionText = "Open Sparkle Capsule"
	capsulePrompt.ObjectText = "Sparkle Capsule"
	capsulePrompt.HoldDuration = 0.2
	capsulePrompt.MaxActivationDistance = 14
	capsulePrompt.RequiresLineOfSight = false
	capsulePrompt.Parent = capsuleBase
	capsuleModel.Parent = folder

	-- Soft Dumpling guide.
	local guideModel = Instance.new("Model")
	guideModel.Name = "GuideSoftDumpling"
	local guideBody = part({
		Name = "Body",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(5, 5, 5),
		Position = Vector3.new(-14, 2.5, 12),
		Color = Color3.fromRGB(255, 224, 196),
		CanCollide = false,
	})
	guideBody.Parent = guideModel
	guideModel.PrimaryPart = guideBody
	floatingLabel("Soft Dumpling", Color3.fromRGB(225, 140, 90), guideBody, 4.5)

	local guidePrompt = Instance.new("ProximityPrompt")
	guidePrompt.ActionText = "Talk"
	guidePrompt.ObjectText = "Soft Dumpling"
	guidePrompt.HoldDuration = 0.1
	guidePrompt.MaxActivationDistance = 14
	guidePrompt.RequiresLineOfSight = false
	guidePrompt.Parent = guideBody
	guideModel.Parent = folder

	-- Spawn pads where sleepy squishy friends appear.
	local padPositions = {
		Vector3.new(-16, 2, 4),
		Vector3.new(-8, 2, -4),
		Vector3.new(0, 2, 6),
		Vector3.new(8, 2, -4),
		Vector3.new(16, 2, 4),
	}
	local pads = {}
	for i, pos in ipairs(padPositions) do
		local pad = part({
			Name = "Pad" .. i,
			Size = Vector3.new(6, 0.4, 6),
			Position = pos - Vector3.new(0, 1.8, 0),
			Color = Color3.fromRGB(255, 238, 246),
			CanCollide = false,
		})
		pad.Parent = folder
		table.insert(pads, CFrame.new(pos))
	end

	-- ── Phase 2: landmarks ──────────────────────────────────────────────────
	-- Syrup river: a glossy amber ribbon winding west→east across the valley,
	-- thinning to a trickle at the eastern (Goo Coast) border. CanCollide off so it
	-- reads as shallow syrup the player wades through; a bridge crosses it.
	local riverFolder = Instance.new("Folder")
	riverFolder.Name = "SyrupRiver"
	riverFolder.Parent = folder
	local riverPts = {
		Vector3.new(-104, 0, 26), Vector3.new(-55, 0, 15), Vector3.new(-16, 0, 23),
		Vector3.new(20, 0, 18), Vector3.new(58, 0, 25), Vector3.new(104, 0, 20),
	}
	local riverW = { 14, 12, 11, 9, 6, 3 }
	for i = 1, #riverPts - 1 do
		local a, b = riverPts[i], riverPts[i + 1]
		local mid = (a + b) / 2
		local dir = b - a
		local width = (riverW[i] + riverW[i + 1]) / 2
		local seg = part({
			Name = "River" .. i,
			Size = Vector3.new(dir.Magnitude + width, 0.4, width),
			Color = Color3.fromRGB(255, 245, 226), -- pale cream "syrup" (matches the book plate)
			Reflectance = 0.08,
			Transparency = 0,
			CanCollide = false,
			CanQuery = false,
		})
		seg.CFrame = CFrame.new(mid.X, 0.16, mid.Z) * CFrame.Angles(0, math.atan2(-dir.Z, dir.X), 0)
		seg.Parent = riverFolder
	end

	-- A cozy bridge over the syrup, on the spawn → play-area path.
	local bridge = Instance.new("Model")
	bridge.Name = "SyrupBridge"
	local deck = part({
		Name = "Deck",
		Size = Vector3.new(12, 0.8, 18),
		Position = Vector3.new(0, 0.4, 20.5),
		Color = Color3.fromRGB(255, 236, 212),
	})
	deck.Parent = bridge
	for _, sx in ipairs({ -1, 1 }) do
		local rail = part({
			Name = "Rail",
			Size = Vector3.new(0.6, 1.6, 18),
			Position = Vector3.new(sx * 5.4, 1.3, 20.5),
			Color = Color3.fromRGB(236, 196, 158),
		})
		rail.Parent = bridge
	end
	bridge.PrimaryPart = deck
	bridge.Parent = folder

	-- Orchard: a little grove of soft pastel trees (a landmark), northeast of the
	-- play area. Trunks are solid; fluffy canopies are walk-through.
	local orchard = Instance.new("Folder")
	orchard.Name = "Orchard"
	orchard.Parent = folder
	local treeRng = Random.new(77)
	local canopyColors = {
		Color3.fromRGB(186, 224, 180), Color3.fromRGB(255, 200, 214),
		Color3.fromRGB(206, 224, 255), Color3.fromRGB(220, 204, 240),
	}
	local treeSpots = {
		Vector3.new(40, 0, -30), Vector3.new(52, 0, -22), Vector3.new(34, 0, -42),
		Vector3.new(50, 0, -42), Vector3.new(60, 0, -32), Vector3.new(44, 0, -54),
	}
	local canopyPuffs = {
		{ Vector3.new(0, 0, 0), 9 }, { Vector3.new(3.4, -1.2, 1.2), 6 },
		{ Vector3.new(-3, -1, -1.6), 6 }, { Vector3.new(0.5, 3, 0), 6.5 },
	}
	for ti, spot in ipairs(treeSpots) do
		local scale = treeRng:NextNumber(0.85, 1.25)
		local trunkH = 7 * scale
		local trunk = part({
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(trunkH, 2.2 * scale, 2.2 * scale),
			Color = Color3.fromRGB(196, 154, 116),
		})
		trunk.CFrame = CFrame.new(spot.X, trunkH / 2, spot.Z) * CFrame.Angles(0, 0, math.rad(90))
		trunk.Parent = orchard
		local canopyColor = canopyColors[((ti - 1) % #canopyColors) + 1]
		local baseY = trunkH + 1.5 * scale
		for _, puff in ipairs(canopyPuffs) do
			local off, d = puff[1], puff[2] * scale
			local canopy = part({
				Name = "Canopy",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(d, d, d),
				Position = Vector3.new(spot.X + off.X, baseY + off.Y, spot.Z + off.Z),
				Color = canopyColor,
				CanCollide = false,
			})
			canopy.Parent = orchard
		end
	end

	-- A cozy cream cottage hub, west of spawn.
	local cottage = Instance.new("Model")
	cottage.Name = "CottageHub"
	local cBase = Vector3.new(-48, 0, 34)
	local body = part({
		Name = "Body",
		Size = Vector3.new(18, 13, 15),
		Position = cBase + Vector3.new(0, 6.5, 0),
		Color = Color3.fromRGB(255, 240, 224),
	})
	body.Parent = cottage
	local roof = part({ -- soft rounded dome roof
		Name = "Roof",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(20, 11, 17),
		Position = cBase + Vector3.new(0, 14, 0),
		Color = Color3.fromRGB(255, 196, 178),
		CanCollide = false,
	})
	roof.Parent = cottage
	local door = part({
		Name = "Door",
		Size = Vector3.new(4.5, 7, 0.6),
		Position = cBase + Vector3.new(0, 3.5, 7.6),
		Color = Color3.fromRGB(196, 150, 120),
	})
	door.Parent = cottage
	local window = part({
		Name = "Window",
		Size = Vector3.new(3.6, 3.6, 0.6),
		Position = cBase + Vector3.new(5.5, 8, 7.6),
		Color = Color3.fromRGB(190, 226, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.25,
	})
	window.Parent = cottage
	cottage.PrimaryPart = body
	cottage.Parent = folder

	-- ── Phase 3: life & polish ──────────────────────────────────────────────
	-- Ambient drifting sparkle motes across the whole valley — gentle floating magic.
	local sparkleField = part({
		Name = "ValleySparkles",
		Size = Vector3.new(190, 1, 190),
		Position = Vector3.new(0, 3, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	sparkleField.Parent = folder
	local motesField = Instance.new("ParticleEmitter")
	motesField.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motesField.LightEmission = 0.9
	motesField.LightInfluence = 0
	motesField.Color = ColorSequence.new(Color3.fromRGB(255, 244, 222), Color3.fromRGB(255, 214, 232))
	motesField.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.4, 1.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	motesField.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.3),
		NumberSequenceKeypoint.new(0.8, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	motesField.Lifetime = NumberRange.new(4, 7)
	motesField.Rate = 36
	motesField.Speed = NumberRange.new(1, 3)
	motesField.Acceleration = Vector3.new(0, 1.5, 0)
	motesField.EmissionDirection = Enum.NormalId.Top
	motesField.SpreadAngle = Vector2.new(40, 40)
	motesField.Rotation = NumberRange.new(0, 360)
	motesField.RotSpeed = NumberRange.new(-30, 30)
	motesField.Parent = sparkleField

	-- The Sparkle: the light that comes from being found (storybook canon) — a soft
	-- glowing orb high above the world. Purely cosmetic; gently breathes + glows.
	local sparkle = Instance.new("Model")
	sparkle.Name = "TheSparkle"
	local sparkleCore = part({
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(12, 12, 12),
		Position = Vector3.new(0, 92, -44),
		Color = Color3.fromRGB(255, 250, 232),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	sparkleCore.Parent = sparkle
	sparkle.PrimaryPart = sparkleCore

	local halo = part({
		Name = "Halo",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(22, 22, 22),
		Position = sparkleCore.Position,
		Color = Color3.fromRGB(255, 236, 214),
		Material = Enum.Material.Neon,
		Transparency = 0.72,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	halo.Parent = sparkle

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 238, 210)
	glow.Brightness = 2
	glow.Range = 60
	glow.Parent = sparkleCore

	local motes = Instance.new("ParticleEmitter")
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.LightEmission = 1
	motes.LightInfluence = 0
	motes.Color = ColorSequence.new(Color3.fromRGB(255, 244, 224), Color3.fromRGB(255, 214, 236))
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 3.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.Lifetime = NumberRange.new(2.2, 3.4)
	motes.Rate = 22
	motes.Speed = NumberRange.new(2, 5)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Rotation = NumberRange.new(0, 360)
	motes.RotSpeed = NumberRange.new(-40, 40)
	motes.Parent = sparkleCore

	sparkle.Parent = folder

	-- Gentle "breathing" glow (looping fire-and-forget tween; no runtime loop).
	TweenService:Create(
		halo,
		TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.5, Size = Vector3.new(28, 28, 28) }
	):Play()

	return {
		pads = pads,
		capsulePrompt = capsulePrompt,
		guidePrompt = guidePrompt,
	}
end

return WorldService
