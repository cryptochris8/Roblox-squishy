-- WorldService (SERVER)
-- Builds a simple, cozy Pudding Hills starter zone out of placeholder parts:
-- a pastel ground, soft hill mounds, a Sparkle Capsule machine, a Soft Dumpling
-- guide, a player spawn, and the pads where sleepy squishy friends appear.
-- Returns the things Main needs to wire up (spawn pad CFrames + the two prompts).

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ZoneConfig"))

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

-- ── Reusable builders for the lands beyond Pudding Hills ────────────────────
-- These build the shared gameplay infrastructure (ground, dunes, pads, capsule,
-- guide, shard pedestal, landing pad) for a land, themed by colour. Each new land
-- then adds its own bespoke props. Pudding Hills keeps its own hand-built code.

local function makeCapsule(folder: Instance, pos: Vector3, displayName: string, color: Color3): ProximityPrompt
	local base = part({ Name = "CapsuleBase", Size = Vector3.new(6, 7, 6), Position = pos, Color = color })
	base.Parent = folder
	local dome = part({
		Name = "CapsuleDome", Shape = Enum.PartType.Ball, Size = Vector3.new(6.5, 6.5, 6.5),
		Position = pos + Vector3.new(0, 5, 0), Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Glass, Transparency = 0.3,
	})
	dome.Parent = folder
	floatingLabel(displayName, color, dome, 4)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = displayName
	prompt.ActionText = "Open " .. displayName
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	return prompt
end

local function makeGuide(folder: Instance, pos: Vector3, name: string, color: Color3): ProximityPrompt
	local body = part({ Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 5, 5), Position = pos, Color = color })
	body.Parent = folder
	floatingLabel(name, color, body, 3.5)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = name
	prompt.ActionText = "Talk"
	prompt.HoldDuration = 0.1
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = body
	return prompt
end

local function makeShardPedestal(folder: Instance, shardSpot: Vector3, color: Color3)
	local pedestal = part({
		Name = "ShardPedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 8, 8),
		Color = color, Reflectance = 0.1, CanCollide = false,
	})
	pedestal.CFrame = CFrame.new(shardSpot + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pedestal.Parent = folder
end

local function makeLandingPad(folder: Instance, pos: Vector3, color: Color3)
	local pad = part({
		Name = "LandingPad", Size = Vector3.new(16, 0.4, 16), Position = pos - Vector3.new(0, 1.6, 0),
		Color = color, Transparency = 0.1, CanCollide = false,
	})
	pad.Parent = folder
end

-- A small travel hub (signpost pads) for hopping to the other lands. The server
-- gates each hop on shard progress; these pads just send the request.
local function buildTravelHub(folder: Instance, center: Vector3, currentZoneName: string)
	local travelPads = {}
	local idx = 0
	for _, destName in ipairs(ZoneConfig.Order) do
		if destName ~= currentZoneName then
			idx += 1
			local pos = center + Vector3.new((idx - 1.5) * 14, 2, 46)
			local pad = part({
				Name = "TravelPad", Size = Vector3.new(9, 0.6, 9),
				Position = pos - Vector3.new(0, 1.6, 0),
				Color = Color3.fromRGB(255, 224, 150), Material = Enum.Material.Neon, CanCollide = false,
			})
			pad.Parent = folder
			local post = part({
				Name = "Signpost", Size = Vector3.new(0.7, 6, 0.7),
				Position = pos + Vector3.new(0, 1.5, 0), Color = Color3.fromRGB(244, 230, 214),
			})
			post.Parent = folder
			floatingLabel("→ " .. destName, Color3.fromRGB(120, 90, 60), post, 3.5)
			local prompt = Instance.new("ProximityPrompt")
			prompt.ObjectText = "Travel Pad"
			prompt.ActionText = "Go to " .. destName
			prompt.HoldDuration = 0.3
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = pad
			travelPads[#travelPads + 1] = { prompt = prompt, destZone = destName }
		end
	end
	return travelPads
end

-- Goo Coast's own coastal pad layout (a curving shore + tide pools + the pier),
-- deliberately different from Pudding Hills so the land feels its own.
local GOO_PAD_OFFSETS = {
	Vector3.new(-40, 2, 30), Vector3.new(-20, 2, 38), Vector3.new(2, 2, 40), Vector3.new(24, 2, 36), Vector3.new(42, 2, 28),
	Vector3.new(-30, 2, 6), Vector3.new(34, 2, 10), Vector3.new(-8, 2, -6),
	Vector3.new(10, 2, -18), Vector3.new(-20, 2, -26), Vector3.new(28, 2, -24), Vector3.new(0, 2, -36),
}

-- Goo Coast: a bespoke seafoam coast — a glossy gooey sea with a wooden pier out
-- to the shard, bouncy translucent jelly dunes, tide-pools with shells, and a
-- cheerful sandcastle. Hand-built, not a recoloured Pudding Hills.
local function buildGooCoast()
	local zone = ZoneConfig.get("Goo Coast")
	local center = zone.center
	local folder = Instance.new("Folder")
	folder.Name = "GooCoast"
	folder.Parent = Workspace
	local rng = Random.new(404)

	-- pale seafoam-sand beach
	local ground = part({
		Name = "Ground", Size = Vector3.new(320, 4, 320), Position = center + Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(226, 236, 214),
	})
	ground.Parent = folder

	-- the gooey sea: a big glossy aqua lagoon across the north of the coast
	local sea = part({
		Name = "GooSea", Size = Vector3.new(300, 1.2, 150), Position = center + Vector3.new(0, 0.2, -78),
		Color = Color3.fromRGB(96, 220, 206), Material = Enum.Material.Glass,
		Reflectance = 0.2, Transparency = 0.2, CanCollide = false,
	})
	sea.Parent = folder
	TweenService:Create(sea, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.36 }):Play()

	-- bouncy translucent jelly dunes (arc around the beach, leaving the sea open)
	local jellyColors = { Color3.fromRGB(140, 230, 214), Color3.fromRGB(255, 190, 200), Color3.fromRGB(180, 220, 255), Color3.fromRGB(200, 245, 210) }
	for i = 1, 10 do
		local angle = math.rad(15) + (i / 10) * math.pi * 1.15
		local radius = rng:NextNumber(72, 98)
		local size = rng:NextNumber(22, 40)
		local mound = part({
			Name = "JellyDune" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(size, size * 0.8, size),
			Position = center + Vector3.new(math.cos(angle) * radius, -size * 0.42, math.sin(angle) * radius + 24),
			Color = jellyColors[((i - 1) % #jellyColors) + 1], Material = Enum.Material.Glass,
			Transparency = 0.25, Reflectance = 0.1, CanCollide = false,
		})
		mound.Parent = folder
	end

	-- a wooden pier reaching from the beach out over the goo sea toward the shard
	for i = 0, 10 do
		local z = 14 - i * 6
		local plank = part({ Name = "Plank", Size = Vector3.new(10, 0.8, 5), Position = center + Vector3.new(0, 1.4, z), Color = Color3.fromRGB(206, 170, 120) })
		plank.Parent = folder
		if i % 2 == 0 then
			for _, sx in ipairs({ -1, 1 }) do
				local post = part({ Name = "Post", Size = Vector3.new(0.8, 4, 0.8), Position = center + Vector3.new(sx * 4.2, 0, z), Color = Color3.fromRGB(170, 134, 92) })
				post.Parent = folder
			end
		end
	end

	-- tide pools with little shells
	local shellColors = { Color3.fromRGB(255, 214, 224), Color3.fromRGB(255, 236, 200), Color3.fromRGB(214, 230, 255) }
	for _, off in ipairs({ Vector3.new(-34, 0, 12), Vector3.new(36, 0, 16), Vector3.new(-14, 0, 0) }) do
		local pool = part({
			Name = "TidePool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 12, 12),
			Color = Color3.fromRGB(120, 224, 220), Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.15, CanCollide = false,
		})
		pool.CFrame = CFrame.new(center + off + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
		pool.Parent = folder
		for s = 1, 3 do
			local shell = part({
				Name = "Shell", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 1.3, 2.4),
				Position = center + off + Vector3.new(rng:NextNumber(-5, 5), 0.4, rng:NextNumber(-5, 5)),
				Color = shellColors[((s - 1) % #shellColors) + 1], CanCollide = false,
			})
			shell.Parent = folder
		end
	end

	-- a cheerful sandcastle landmark
	local sandColor = Color3.fromRGB(240, 218, 168)
	local castleBase = center + Vector3.new(-48, 0, 42)
	local keep = part({ Name = "CastleKeep", Size = Vector3.new(12, 8, 12), Position = castleBase + Vector3.new(0, 4, 0), Color = sandColor })
	keep.Parent = folder
	for _, off in ipairs({ Vector3.new(-6, 0, -6), Vector3.new(6, 0, -6), Vector3.new(-6, 0, 6), Vector3.new(6, 0, 6) }) do
		local tower = part({ Name = "CastleTower", Size = Vector3.new(5, 11, 5), Position = castleBase + off + Vector3.new(0, 5.5, 0), Color = sandColor })
		tower.Parent = folder
		local coneTop = part({ Name = "CastleTop", Shape = Enum.PartType.Ball, Size = Vector3.new(5.4, 4, 5.4), Position = castleBase + off + Vector3.new(0, 12, 0), Color = Color3.fromRGB(255, 150, 170) })
		coneTop.Parent = folder
	end

	-- drifting glossy bubbles for life
	for i = 1, 14 do
		local sz = rng:NextNumber(1.6, 3.4)
		local pos = center + Vector3.new(rng:NextNumber(-60, 60), rng:NextNumber(3, 8), rng:NextNumber(-70, 50))
		local bubble = part({
			Name = "Bubble", Shape = Enum.PartType.Ball, Size = Vector3.new(sz, sz, sz), Position = pos,
			Color = Color3.fromRGB(200, 245, 255), Material = Enum.Material.Glass, Transparency = 0.4, Reflectance = 0.1, CanCollide = false, CastShadow = false,
		})
		bubble.Parent = folder
		TweenService:Create(bubble, TweenInfo.new(rng:NextNumber(2, 3.5), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = pos + Vector3.new(0, 2.5, 0) }):Play()
	end

	-- gameplay infrastructure: own coastal pads + themed capsule/guide + shard + travel
	local pads = {}
	for _, off in ipairs(GOO_PAD_OFFSETS) do
		local pos = center + off
		local pad = part({ Name = "Pad", Size = Vector3.new(6, 0.4, 6), Position = pos - Vector3.new(0, 1.8, 0), Color = Color3.fromRGB(150, 232, 224), Transparency = 0.2, CanCollide = false })
		pad.Parent = folder
		pads[#pads + 1] = CFrame.new(pos)
	end
	makeLandingPad(folder, zone.spawn, Color3.fromRGB(120, 220, 224))
	local capsulePrompt = makeCapsule(folder, center + Vector3.new(-22, 3.5, 26), "Goo Capsule", Color3.fromRGB(120, 220, 200))
	local guidePrompt = makeGuide(folder, center + Vector3.new(16, 2.5, 18), "Bloop the Goo Guide", Color3.fromRGB(150, 226, 234))
	makeShardPedestal(folder, zone.shardSpot, Color3.fromRGB(120, 220, 224))
	local travelPads = buildTravelHub(folder, center, "Goo Coast")

	return {
		zone = "Goo Coast",
		packId = zone.packId,
		capsuleKey = zone.capsuleKey,
		pads = pads,
		capsulePrompt = capsulePrompt,
		guidePrompt = guidePrompt,
		travelPads = travelPads,
	}
end

-- Moonlit Hollow's own glade pad layout (around the moonpool, in the mushroom
-- grove, and by the cozy log) — different from the other lands.
local MOON_PAD_OFFSETS = {
	Vector3.new(-14, 2, -4), Vector3.new(14, 2, -8), Vector3.new(-4, 2, -24),
	Vector3.new(-40, 2, 14), Vector3.new(-30, 2, 32), Vector3.new(-48, 2, -2),
	Vector3.new(34, 2, 18), Vector3.new(44, 2, 2), Vector3.new(28, 2, 36),
	Vector3.new(6, 2, 30), Vector3.new(-10, 2, 42), Vector3.new(18, 2, -32),
}

-- Moonlit Hollow: a bespoke twilight glade — a still reflective moonpool under a
-- low moon, a grove of giant glowing mushrooms, a cozy fallen log, glowing
-- flowers, and drifting fireflies. Soft-spooky, never scary (book canon).
local function buildMoonlitHollow()
	local zone = ZoneConfig.get("Moonlit Hollow")
	local center = zone.center
	local folder = Instance.new("Folder")
	folder.Name = "MoonlitHollow"
	folder.Parent = Workspace
	local rng = Random.new(777)
	local capColors = { Color3.fromRGB(190, 130, 255), Color3.fromRGB(130, 200, 255), Color3.fromRGB(255, 150, 220), Color3.fromRGB(160, 255, 220) }

	-- twilight ground
	local ground = part({ Name = "Ground", Size = Vector3.new(320, 4, 320), Position = center + Vector3.new(0, -2, 0), Color = Color3.fromRGB(122, 112, 160) })
	ground.Parent = folder

	-- the Moonpool: a still, mirror-glossy pool, ringed by a soft glow
	local pool = part({
		Name = "Moonpool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 46, 46),
		Color = Color3.fromRGB(70, 80, 140), Material = Enum.Material.Glass, Reflectance = 0.5, Transparency = 0.1, CanCollide = false,
	})
	pool.CFrame = CFrame.new(center + Vector3.new(0, 0.2, -12)) * CFrame.Angles(0, 0, math.rad(90))
	pool.Parent = folder
	local ring = part({
		Name = "PoolGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 52, 52),
		Color = Color3.fromRGB(172, 162, 255), Material = Enum.Material.Neon, Transparency = 0.7, CanCollide = false,
	})
	ring.CFrame = CFrame.new(center + Vector3.new(0, 0.12, -12)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder

	-- the Moon, low over the pool so it reflects
	local moon = part({
		Name = "Moon", Shape = Enum.PartType.Ball, Size = Vector3.new(22, 22, 22),
		Position = center + Vector3.new(0, 72, -92), Color = Color3.fromRGB(236, 234, 255),
		Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, CastShadow = false,
	})
	moon.Parent = folder
	local moonLight = Instance.new("PointLight")
	moonLight.Color = Color3.fromRGB(200, 200, 255)
	moonLight.Brightness = 1.4
	moonLight.Range = 90
	moonLight.Parent = moon

	-- glowing mushrooms (stem + neon cap + glow)
	local function mushroom(pos, h, capSize, color)
		local stem = part({ Name = "Stem", Size = Vector3.new(h * 0.22, h, h * 0.22), Position = pos + Vector3.new(0, h / 2, 0), Color = Color3.fromRGB(236, 228, 244), CanCollide = false })
		stem.Parent = folder
		local cap = part({ Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(capSize, capSize * 0.65, capSize), Position = pos + Vector3.new(0, h + capSize * 0.2, 0), Color = color, Material = Enum.Material.Neon, CanCollide = false, CastShadow = false })
		cap.Parent = folder
		local light = Instance.new("PointLight")
		light.Color = color
		light.Brightness = 1.6
		light.Range = capSize * 3
		light.Parent = cap
	end
	-- a grove of GIANT mushrooms on the west side
	for i = 1, 5 do
		mushroom(center + Vector3.new(rng:NextNumber(-62, -34), 0, rng:NextNumber(-12, 42)), rng:NextNumber(7, 12), rng:NextNumber(6, 10), capColors[((i - 1) % #capColors) + 1])
	end
	-- smaller mushrooms dotted around the glade
	for i = 1, 10 do
		mushroom(center + Vector3.new(rng:NextNumber(-56, 56), 0, rng:NextNumber(-52, 52)), rng:NextNumber(2.5, 4.5), rng:NextNumber(2.4, 3.6), capColors[((i - 1) % #capColors) + 1])
	end

	-- a cozy fallen log on the east side
	local log = part({ Name = "CozyLog", Shape = Enum.PartType.Cylinder, Size = Vector3.new(22, 5, 5), Color = Color3.fromRGB(150, 116, 92) })
	log.CFrame = CFrame.new(center + Vector3.new(40, 2.3, 20)) * CFrame.Angles(0, math.rad(35), 0)
	log.Parent = folder

	-- glowing twilight flowers scattered low to the ground
	for _ = 1, 12 do
		local flower = part({
			Name = "GlowFlower", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4),
			Position = center + Vector3.new(rng:NextNumber(-58, 58), 0.6, rng:NextNumber(-58, 58)),
			Color = capColors[rng:NextInteger(1, #capColors)], Material = Enum.Material.Neon, CanCollide = false, CastShadow = false,
		})
		flower.Parent = folder
	end

	-- drifting fireflies
	local fField = part({ Name = "Fireflies", Size = Vector3.new(180, 1, 180), Position = center + Vector3.new(0, 4, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	fField.Parent = folder
	local fly = Instance.new("ParticleEmitter")
	fly.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	fly.LightEmission = 1
	fly.LightInfluence = 0
	fly.Color = ColorSequence.new(Color3.fromRGB(200, 170, 255), Color3.fromRGB(170, 230, 255))
	fly.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 1), NumberSequenceKeypoint.new(1, 0) })
	fly.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(0.8, 0.45), NumberSequenceKeypoint.new(1, 1) })
	fly.Lifetime = NumberRange.new(3, 6)
	fly.Rate = 34
	fly.Speed = NumberRange.new(1, 3)
	fly.Acceleration = Vector3.new(0, 1, 0)
	fly.SpreadAngle = Vector2.new(60, 60)
	fly.Parent = fField

	-- gameplay infrastructure: own glade pads + themed capsule/guide + shard + travel
	local pads = {}
	for _, off in ipairs(MOON_PAD_OFFSETS) do
		local pos = center + off
		local pad = part({ Name = "Pad", Size = Vector3.new(6, 0.4, 6), Position = pos - Vector3.new(0, 1.8, 0), Color = Color3.fromRGB(186, 164, 230), Transparency = 0.2, CanCollide = false })
		pad.Parent = folder
		pads[#pads + 1] = CFrame.new(pos)
	end
	makeLandingPad(folder, zone.spawn, Color3.fromRGB(196, 166, 255))
	local capsulePrompt = makeCapsule(folder, center + Vector3.new(24, 3.5, 26), "Moonlit Capsule", Color3.fromRGB(150, 120, 210))
	local guidePrompt = makeGuide(folder, center + Vector3.new(-18, 2.5, 18), "Nox the Night Guide", Color3.fromRGB(176, 152, 224))
	makeShardPedestal(folder, zone.shardSpot, Color3.fromRGB(196, 166, 255))
	local travelPads = buildTravelHub(folder, center, "Moonlit Hollow")

	return {
		zone = "Moonlit Hollow",
		packId = zone.packId,
		capsuleKey = zone.capsuleKey,
		pads = pads,
		capsulePrompt = capsulePrompt,
		guidePrompt = guidePrompt,
		travelPads = travelPads,
	}
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

	-- Spawn pads where sleepy squishy friends appear — spread across Pudding Hills
	-- (west, east-by-the-orchard, central, and deeper north) so the world is a place
	-- to explore, not one click-cluster.
	local padPositions = {
		Vector3.new(-10, 2, 2), Vector3.new(9, 2, -2), Vector3.new(2, 2, 9),
		Vector3.new(-34, 2, 2), Vector3.new(-28, 2, -18), Vector3.new(-40, 2, 8),
		Vector3.new(30, 2, -12), Vector3.new(40, 2, 4), Vector3.new(22, 2, -22),
		Vector3.new(-6, 2, -30), Vector3.new(14, 2, -34), Vector3.new(-20, 2, -38),
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
	-- Dessert treats scattered through the valley (native candy props, walk-through).
	local treats = Instance.new("Folder")
	treats.Name = "Treats"
	treats.Parent = folder
	local candy = {
		Color3.fromRGB(255, 170, 190), Color3.fromRGB(180, 224, 200),
		Color3.fromRGB(190, 200, 255), Color3.fromRGB(255, 214, 160),
		Color3.fromRGB(214, 190, 240),
	}
	local function vcyl(name, size, pos, color, refl)
		local p = part({ Name = name, Shape = Enum.PartType.Cylinder, Size = size, Color = color, CanCollide = false })
		if refl then p.Reflectance = refl end
		p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
		p.Parent = treats
		return p
	end
	local function ballAt(name, size, pos, color, refl)
		local p = part({ Name = name, Shape = Enum.PartType.Ball, Size = size, Position = pos, Color = color, CanCollide = false })
		if refl then p.Reflectance = refl end
		p.Parent = treats
		return p
	end
	local function gumdrop(pos, c)
		ballAt("Gumdrop", Vector3.new(4.6, 5.6, 4.6), pos + Vector3.new(0, 1.9, 0), c, 0.08)
	end
	local function lollipop(pos, c)
		vcyl("Stick", Vector3.new(8, 0.7, 0.7), pos + Vector3.new(0, 4, 0), Color3.fromRGB(255, 250, 240))
		ballAt("Candy", Vector3.new(4.4, 4.4, 1.3), pos + Vector3.new(0, 8.4, 0), c, 0.06)
	end
	local function cupcake(pos, c)
		vcyl("Wrapper", Vector3.new(3.4, 4.2, 4.2), pos + Vector3.new(0, 1.7, 0), Color3.fromRGB(255, 224, 196))
		ballAt("Frosting", Vector3.new(5, 5, 5), pos + Vector3.new(0, 4.8, 0), c)
		ballAt("Cherry", Vector3.new(1.4, 1.4, 1.4), pos + Vector3.new(0, 7.4, 0), Color3.fromRGB(255, 120, 140))
	end
	local function macaron(pos, c)
		vcyl("Shell", Vector3.new(1.4, 5.4, 5.4), pos + Vector3.new(0, 1.2, 0), c)
		vcyl("Cream", Vector3.new(0.9, 4.4, 4.4), pos + Vector3.new(0, 2.1, 0), Color3.fromRGB(255, 244, 224))
		vcyl("Shell", Vector3.new(1.4, 5.4, 5.4), pos + Vector3.new(0, 3.0, 0), c)
	end
	local treatSpots = {
		{ Vector3.new(-30, 0, -24), gumdrop }, { Vector3.new(28, 0, 8), lollipop },
		{ Vector3.new(-36, 0, -6), cupcake }, { Vector3.new(22, 0, -32), macaron },
		{ Vector3.new(-26, 0, 46), gumdrop }, { Vector3.new(36, 0, 46), lollipop },
		{ Vector3.new(-56, 0, 2), macaron }, { Vector3.new(52, 0, -6), cupcake },
		{ Vector3.new(-42, 0, -40), gumdrop }, { Vector3.new(14, 0, 48), lollipop },
	}
	for i, ts in ipairs(treatSpots) do
		ts[2](ts[1], candy[((i - 1) % #candy) + 1])
	end

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

	-- Gentle background music (global, looping). The MCP can't pick audio, so paste a
	-- track id into SoundConfig.Music (Studio -> Toolbox -> Audio) to enable it.
	local soundCfg = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("SoundConfig"))
	if soundCfg.Music and soundCfg.Music ~= "" then
		local music = Instance.new("Sound")
		music.Name = "PuddingHillsMusic"
		music.SoundId = soundCfg.Music
		music.Looped = true
		music.Volume = soundCfg.MusicVolume or 0.3
		music.Parent = game:GetService("SoundService")
		music:Play()
	end

	-- ── Phase A: quest landmarks ─────────────────────────────────────────────
	-- The lost shard's resting place at the orchard's edge (book canon). Empty now;
	-- QuestService floats the shard here once enough friends are woken.
	local shardSpot = Vector3.new(47, 0, -40)
	local pedestal = part({
		Name = "ShardPedestal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 8, 8),
		Color = Color3.fromRGB(244, 230, 214),
		Reflectance = 0.1,
		CanCollide = false,
	})
	pedestal.CFrame = CFrame.new(shardSpot + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pedestal.Parent = folder

	-- Goo Coast gate at the eastern border (where the syrup thins to a trickle). A
	-- LOCKED teaser; recovering the First Shard opens it. (The Goo Coast zone itself
	-- is future work — this is the visual promise.)
	local gate = Instance.new("Model")
	gate.Name = "GooCoastGate"
	local gx = 124
	for _, sx in ipairs({ -1, 1 }) do
		local post = part({ Name = "Post", Size = Vector3.new(3, 16, 3),
			Position = Vector3.new(gx, 8, 20 + sx * 9), Color = Color3.fromRGB(150, 224, 214) })
		post.Parent = gate
	end
	local arch = part({ Name = "Arch", Size = Vector3.new(3, 3, 24),
		Position = Vector3.new(gx, 17.5, 20), Color = Color3.fromRGB(150, 224, 214) })
	arch.Parent = gate
	local barrier = part({ Name = "Barrier", Size = Vector3.new(1.2, 16, 18),
		Position = Vector3.new(gx, 8, 20), Color = Color3.fromRGB(190, 240, 255),
		Material = Enum.Material.Glass, Transparency = 0.5 })
	barrier.Parent = gate
	floatingLabel("Goo Coast", Color3.fromRGB(40, 150, 150), arch, 4)
	gate.PrimaryPart = arch
	gate.Parent = folder

	local puddingHills = {
		zone = "Pudding Hills",
		packId = "launch_squishy_foods",
		capsuleKey = "StarterCapsule",
		pads = pads,
		capsulePrompt = capsulePrompt,
		guidePrompt = guidePrompt,
		travelPads = buildTravelHub(folder, Vector3.new(0, 0, 0), "Pudding Hills"),
	}

	return { zones = { puddingHills, buildGooCoast(), buildMoonlitHollow() } }
end

return WorldService
