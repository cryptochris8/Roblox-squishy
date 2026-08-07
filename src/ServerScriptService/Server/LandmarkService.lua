--!strict
-- LandmarkService (SERVER)
-- Tier 1 of the Sparkle Beacon system: a tethered candy balloon floating over
-- every registered landmark, so a kid standing anywhere can SEE that there are
-- places to go (doc: LandmarkConfig's header has the measurement that motivated
-- this — one readable destination name from spawn, in a 320x320 land).
--
-- Physical parts have NO MaxDistance, so a balloon reads from across the plate.
-- It carries no text at all: colour + a floating icon is a language a six-year-
-- old who can't read yet still understands. The NAME lives on the client
-- (LandmarkBeacons), where the caps that keep it out of word soup can live too.
--
-- LANDMINE — StreamingEnabled: a beacon sits AT its district, so by default it
-- would not exist client-side until you were already near it, which defeats the
-- whole point. Every beacon model is ModelStreamingMode.Persistent (the same
-- trick CoasterService uses for the train).

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LandmarkConfig = require(Shared:WaitForChild("LandmarkConfig"))

local LandmarkService = {}

-- NOT "SparkleBeacon" — BeaconFx already ships a part by that name for the
-- capsule-discovery cheer beam, and two systems sharing a name is how a future
-- FindFirstChild grabs the wrong one.
local FOLDER_NAME = "LandmarkBeacons"

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(p :: any)[key] = value
	end
	return p
end

-- Where the ribbon should START: on top of whatever is actually under the
-- balloon. Landmarks sit on stalls, platforms and pedestals of every height, so
-- a ribbon that always ran to y=0 would spear the coaster station's canopy and
-- the Boutique's awning. One downward ray per beacon, at build time, means no
-- hand-tuned coordinates to drift out of date.
local function tetherHeight(x: number, z: number, top: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { Workspace:FindFirstChild(FOLDER_NAME) :: any }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -(top + 8), 0), params)
	if hit and hit.Position.Y > 0.5 then
		return hit.Position.Y
	end
	return 0
end

local function buildBeacon(lm, parent: Instance)
	local height = lm.height or LandmarkConfig.DefaultHeight
	local model = Instance.new("Model")
	model.Name = "Beacon_" .. lm.id
	-- must exist client-side from anywhere, or the beacon can't do its job
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	-- An explicit footY wins over the ray: CoasterService and PlaygroundService
	-- build with CanQuery = false, so a downward ray passes straight through
	-- their canopies and towers and the ribbon would spear a roof.
	local footY = lm.footY or tetherHeight(lm.pos.X, lm.pos.Z, height)
	local base = Vector3.new(lm.pos.X, footY, lm.pos.Z)
	local ribbonLen = math.max(6, height)

	-- The ribbon tethering the balloon to its place: this is what says "the
	-- thing is HERE", not "somewhere under that balloon".
	local ribbon = part({
		Name = "Ribbon",
		Size = Vector3.new(0.35, ribbonLen, 0.35),
		Position = base + Vector3.new(0, ribbonLen / 2, 0),
		Color = lm.color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	})
	ribbon.Parent = model

	local balloon = part({
		Name = "Balloon",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 9, 9),
		Position = base + Vector3.new(0, ribbonLen + 4.5, 0),
		Color = lm.color,
		Material = Enum.Material.Neon,
		Transparency = 0.12,
	})
	balloon.Parent = model
	model.PrimaryPart = balloon
	-- the client finds its banner anchor by this attribute
	balloon:SetAttribute("LandmarkId", lm.id)

	-- A soft knot where the ribbon meets the balloon, so it reads as a balloon
	-- and not a floating orb on a stick.
	local knot = part({
		Name = "Knot",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.6, 1.6, 1.6),
		Position = base + Vector3.new(0, ribbonLen - 0.2, 0),
		Color = lm.color,
	})
	knot.Parent = model

	-- Works at Moonlit's night lighting too.
	local light = Instance.new("PointLight")
	light.Name = "BeaconGlow"
	light.Color = lm.color
	light.Brightness = 0.9
	light.Range = 26
	-- Shadows off: these are the only always-loaded lights in the game (the
	-- models are Persistent), and 25 shadow-casting lights is a real mobile cost
	-- for a decorative glow.
	light.Shadows = false
	light.Parent = balloon

	-- A gentle bob. Fire-and-forget looping tween, the codebase's idiom for
	-- ambient motion (BoutiqueService's breathing bow).
	task.spawn(function()
		local up = balloon.Position + Vector3.new(0, 1.2, 0)
		local down = balloon.Position - Vector3.new(0, 1.2, 0)
		local info = TweenInfo.new(3.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		while balloon.Parent do
			local a = TweenService:Create(balloon, info, { Position = up })
			a:Play()
			a.Completed:Wait()
			if not balloon.Parent then
				break
			end
			local b = TweenService:Create(balloon, info, { Position = down })
			b:Play()
			b.Completed:Wait()
		end
	end)

	model.Parent = parent
	return model
end

function LandmarkService.init()
	task.spawn(function()
		-- Let the async self-building districts (Garden, Boutique, Switcheroo,
		-- the Weekly tent) land first, so the tether ray sees what it is
		-- standing on rather than bare ground.
		task.wait(3)
		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = Workspace
		for _, lm in ipairs(LandmarkConfig.Landmarks) do
			local ok, err = pcall(buildBeacon, lm, folder)
			if not ok then
				warn("[LandmarkService] beacon " .. lm.id .. " failed: " .. tostring(err))
			end
		end
	end)
end

return LandmarkService
