-- WorldService (SERVER)
-- Builds a simple, cozy Pudding Hills starter zone out of placeholder parts:
-- a pastel ground, soft hill mounds, a Sparkle Capsule machine, a Soft Dumpling
-- guide, a player spawn, and the pads where sleepy squishy friends appear.
-- Returns the things Main needs to wire up (spawn pad CFrames + the two prompts).

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

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
	-- Cozy daytime lighting.
	Lighting.Brightness = 2
	Lighting.ClockTime = 14
	Lighting.Ambient = Color3.fromRGB(180, 170, 190)
	Lighting.OutdoorAmbient = Color3.fromRGB(205, 195, 215)
	Lighting.FogEnd = 1200

	local folder = Instance.new("Folder")
	folder.Name = "PuddingHills"
	folder.Parent = Workspace

	-- Ground
	local ground = part({
		Name = "Ground",
		Size = Vector3.new(240, 4, 240),
		Position = Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(255, 226, 236),
	})
	ground.Parent = folder

	-- Soft hill mounds (half-buried pastel spheres).
	local hills = {
		{ pos = Vector3.new(-46, -6, -46), size = 34, color = Color3.fromRGB(255, 214, 228) },
		{ pos = Vector3.new(50, -8, -34), size = 42, color = Color3.fromRGB(255, 232, 210) },
		{ pos = Vector3.new(24, -5, 56), size = 30, color = Color3.fromRGB(238, 222, 255) },
		{ pos = Vector3.new(-58, -6, 28), size = 32, color = Color3.fromRGB(214, 240, 255) },
	}
	for i, h in ipairs(hills) do
		local mound = part({
			Name = "Hill" .. i,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(h.size, h.size, h.size),
			Position = h.pos,
			Color = h.color,
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

	return {
		pads = pads,
		capsulePrompt = capsulePrompt,
		guidePrompt = guidePrompt,
	}
end

return WorldService
