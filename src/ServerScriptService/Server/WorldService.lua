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
		Lighting.Brightness = 2.6
		Lighting.ClockTime = 15.6 -- warm late-afternoon storybook light
		Lighting.GeographicLatitude = 18
		Lighting.Ambient = Color3.fromRGB(182, 168, 186)
		Lighting.OutdoorAmbient = Color3.fromRGB(226, 204, 206)
		Lighting.ExposureCompensation = 0.2
		Lighting.EnvironmentDiffuseScale = 1
		Lighting.EnvironmentSpecularScale = 0.9
		Lighting.FogEnd = 1600

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
			Density = 0.34, Offset = 0.15,
			Color = Color3.fromRGB(240, 226, 234),
			Decay = Color3.fromRGB(170, 160, 205),
			Glare = 0.15, Haze = 1.6,
		})
		-- Pastel sky with a big, gentle sun.
		ensure(Lighting, "Sky", "Sky", { SunAngularSize = 16, MoonAngularSize = 11 })
		-- Warm, lightly saturated storybook grade.
		ensure(Lighting, "ColorCorrectionEffect", "Grade", {
			Brightness = 0, Contrast = 0.05, Saturation = 0.12,
			TintColor = Color3.fromRGB(255, 242, 232),
		})
		-- Soft glow on the brightest spots (suits the "sparkle" theme).
		ensure(Lighting, "BloomEffect", "Bloom", { Intensity = 0.6, Size = 24, Threshold = 1.25 })
		-- Gentle sun halo.
		ensure(Lighting, "SunRaysEffect", "SunRays", { Intensity = 0.08, Spread = 0.85 })
		-- Dreamy fluffy clouds (Clouds live under Terrain, not Lighting).
		local terrain = Workspace:FindFirstChildOfClass("Terrain")
		if terrain then
			ensure(terrain, "Clouds", "Clouds", {
				Cover = 0.55, Density = 0.5,
				Color = Color3.fromRGB(255, 250, 248),
			})
		end
	end)

	local folder = Instance.new("Folder")
	folder.Name = "PuddingHills"
	folder.Parent = Workspace

	-- Ground — soft creamy peach, extra-wide so the hill ring sits on land.
	local ground = part({
		Name = "Ground",
		Size = Vector3.new(320, 4, 320),
		Position = Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(255, 232, 222),
	})
	ground.Parent = folder

	-- Rolling "cream-bowl" hills: half-buried pastel domes ringing the cozy valley.
	-- Placed beyond the play area (radius > 55) so they frame the world without
	-- blocking the pads, capsule, or spawn. CanCollide off so nothing snags on them.
	local hillRng = Random.new(2026)
	local hillPalette = {
		Color3.fromRGB(255, 214, 228), -- pink
		Color3.fromRGB(255, 232, 210), -- peach
		Color3.fromRGB(238, 222, 255), -- lavender
		Color3.fromRGB(214, 240, 255), -- sky-mint
		Color3.fromRGB(255, 244, 224), -- cream
		Color3.fromRGB(255, 224, 236), -- blush
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
