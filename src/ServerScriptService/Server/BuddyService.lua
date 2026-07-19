--!strict
-- BuddyService (SERVER)
-- Spawns the player's equipped Squishy Friend as a cute companion that floats and
-- gently bobs along behind them. Purely cosmetic, server-spawned (so everyone sees
-- each other's buddies) and never collides with or blocks anything.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SquishyData = require(Shared:WaitForChild("SquishyData"))
local VariantConfig = require(Shared:WaitForChild("VariantConfig"))
local CosmeticsConfig = require(Shared:WaitForChild("CosmeticsConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)
local SquishyModelFactory = require(script.Parent.SquishyModelFactory)
local MonetizationService = require(script.Parent.MonetizationService)

local BuddyService = {}

-- World friends are ~4 studs; a buddy is the same shape at companion size.
local BUDDY_SCALE = 0.62
local EYE_COLOR = Color3.fromRGB(64, 48, 64)

-- up to two companions per player (slot 2 = the Extra Buddy Slot pass)
local buddies: { [Player]: { [number]: Model } } = {}
local buddyFolder: Folder

local function roundFrame(parent: Instance, radius: number): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = f
	f.Parent = parent
	return f
end

-- A cute, always-happy face (eyes + shine, rosy cheeks, a smile).
local function addFace(body: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Face"
	gui.Size = UDim2.fromOffset(66, 56)
	gui.StudsOffset = Vector3.new(0, 0.1, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Parent = body

	local function eye(px: number)
		local e = roundFrame(gui, 6)
		e.AnchorPoint = Vector2.new(0.5, 0.5)
		e.Position = UDim2.fromScale(px, 0.42)
		e.Size = UDim2.fromOffset(13, 15)
		e.BackgroundColor3 = EYE_COLOR
		local shine = roundFrame(e, 3)
		shine.AnchorPoint = Vector2.new(0.5, 0.5)
		shine.Position = UDim2.fromScale(0.35, 0.3)
		shine.Size = UDim2.fromOffset(4, 4)
		shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	end
	eye(0.3)
	eye(0.7)

	local function cheek(px: number)
		local c = roundFrame(gui, 5)
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Position = UDim2.fromScale(px, 0.58)
		c.Size = UDim2.fromOffset(11, 8)
		c.BackgroundColor3 = Color3.fromRGB(255, 150, 175)
		c.BackgroundTransparency = 0.35
	end
	cheek(0.15)
	cheek(0.85)

	local mouth = roundFrame(gui, 5)
	mouth.AnchorPoint = Vector2.new(0.5, 0.5)
	mouth.Position = UDim2.fromScale(0.5, 0.64)
	mouth.Size = UDim2.fromOffset(17, 10)
	mouth.BackgroundColor3 = EYE_COLOR
end

-- A soft particle aura for Sparkly/Rainbow variant buddies, so an upgraded
-- friend is something the other kids can SEE.
local function addVariantAura(body: BasePart, variantLevel: number)
	if variantLevel < 1 then
		return
	end
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "VariantAura"
	aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	aura.LightEmission = 0.9
	if variantLevel >= 2 then
		-- Rainbow: the sparkles drift through the whole candy rainbow.
		aura.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 160)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 220, 130)),
			ColorSequenceKeypoint.new(0.65, Color3.fromRGB(150, 230, 180)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 180, 255)),
		})
	else
		aura.Color = ColorSequence.new(VariantConfig.colorFor(variantLevel), Color3.fromRGB(255, 255, 255))
	end
	aura.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.9), NumberSequenceKeypoint.new(1, 0),
	})
	aura.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.25), NumberSequenceKeypoint.new(1, 1),
	})
	aura.Lifetime = NumberRange.new(0.9, 1.5)
	aura.Rate = 7
	aura.Speed = NumberRange.new(1, 2.5)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Parent = body
end

-- The Sparkle Club VIP aura: a steady drift of golden sparkles, distinct from
-- the variant auras so a VIP buddy reads at a glance.
local function addVipAura(body: BasePart)
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "VipAura"
	aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	aura.LightEmission = 1
	aura.Color = ColorSequence.new(Color3.fromRGB(255, 214, 90), Color3.fromRGB(255, 245, 200))
	aura.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.8), NumberSequenceKeypoint.new(1, 0),
	})
	aura.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(1, 1),
	})
	aura.Lifetime = NumberRange.new(1.1, 1.7)
	aura.Rate = 6
	aura.Speed = NumberRange.new(0.6, 1.6)
	aura.Acceleration = Vector3.new(0, 1.2, 0) -- VIP gold drifts gently upward
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Parent = body
end

-- ── Boutique cosmetics, built from soft little parts ────────────────────────
-- Every prop is anchored and positioned relative to the body at build time;
-- the per-frame model:PivotTo() then carries the whole outfit rigidly, so hats
-- bob along with the buddy for free.

local function prop(parent: Model, props): Part
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
	p.Parent = parent
	return p
end

-- Each hat builder gets the model and the CFrame of the top of the head.
local HAT_BUILDERS: { [string]: (Model, CFrame, any) -> () } = {
	hat_party = function(model, top, item)
		-- a striped cone of shrinking cylinders with a pompom
		local radii = { 0.95, 0.7, 0.45 }
		for i, r in ipairs(radii) do
			local stripe = prop(model, {
				Name = "PartyStripe", Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.34, r * 2, r * 2),
				Color = (i % 2 == 1) and item.color or item.color2,
			})
			stripe.CFrame = top * CFrame.new(0, (i - 1) * 0.32 + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
		end
		local pom = prop(model, {
			Name = "Pompom", Shape = Enum.PartType.Ball, Size = Vector3.new(0.42, 0.42, 0.42),
			Color = Color3.fromRGB(255, 255, 255),
		})
		pom.CFrame = top * CFrame.new(0, 1.12, 0)
	end,
	hat_star = function(model, top, item)
		-- two crossed gold slivers + a shiny centre, clipped at a cute angle
		local at = top * CFrame.new(0.55, 0.05, 0) * CFrame.Angles(0, 0, math.rad(-18))
		for _, ang in ipairs({ 0, 90 }) do
			local arm = prop(model, {
				Name = "StarArm", Size = Vector3.new(1.05, 0.22, 0.34),
				Color = item.color, Reflectance = 0.15,
			})
			arm.CFrame = at * CFrame.Angles(0, 0, math.rad(45 + ang))
		end
		local mid = prop(model, {
			Name = "StarHeart", Shape = Enum.PartType.Ball, Size = Vector3.new(0.34, 0.34, 0.34),
			Color = Color3.fromRGB(255, 245, 220), Reflectance = 0.2,
		})
		mid.CFrame = at
	end,
	hat_bow = function(model, top, item)
		local knot = prop(model, {
			Name = "BowKnot", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4),
			Color = item.color,
		})
		knot.CFrame = top * CFrame.new(0, 0.18, 0)
		for _, sx in ipairs({ -1, 1 }) do
			local loop = prop(model, {
				Name = "BowLoop", Shape = Enum.PartType.Ball, Size = Vector3.new(0.85, 0.55, 0.4),
				Color = item.color,
			})
			loop.CFrame = top * CFrame.new(sx * 0.5, 0.22, 0) * CFrame.Angles(0, 0, math.rad(sx * 16))
		end
	end,
	hat_flowers = function(model, top, item)
		-- a little ring of alternating blossoms resting on the crown
		for i = 1, 6 do
			local angle = (i / 6) * math.pi * 2
			local blossom = prop(model, {
				Name = "Blossom", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.34, 0.4),
				Color = (i % 2 == 1) and item.color or item.color2,
			})
			blossom.CFrame = top * CFrame.new(math.cos(angle) * 0.85, -0.12, math.sin(angle) * 0.85)
		end
	end,
	hat_mushroom = function(model, top, item)
		local cap = prop(model, {
			Name = "MushroomCap", Shape = Enum.PartType.Ball, Size = Vector3.new(1.7, 1.0, 1.7),
			Color = item.color,
		})
		cap.CFrame = top * CFrame.new(0, 0.3, 0)
		for i, off in ipairs({ Vector3.new(0.45, 0.62, 0.2), Vector3.new(-0.4, 0.58, -0.3), Vector3.new(0.05, 0.72, -0.45) }) do
			local dot = prop(model, {
				Name = "CapDot" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.22, 0.3),
				Color = item.color2,
			})
			dot.CFrame = top * CFrame.new(off.X, off.Y - 0.3, off.Z)
		end
	end,
	-- ── Premium hats (Phase D) ──────────────────────────────────────────────
	hat_strawberry_beret = function(model, top, item)
		-- a tilted berry-red beret with golden seeds and a leafy stem
		local tilt = top * CFrame.new(0.16, 0.06, 0) * CFrame.Angles(0, 0, math.rad(-12))
		local cap = prop(model, {
			Name = "BeretCap", Shape = Enum.PartType.Ball, Size = Vector3.new(1.55, 0.72, 1.55),
			Color = item.color,
		})
		cap.CFrame = tilt * CFrame.new(0, 0.16, 0)
		for i, off in ipairs({
			Vector3.new(0.45, 0.3, 0.18), Vector3.new(-0.38, 0.28, -0.3), Vector3.new(0.05, 0.38, -0.42),
			Vector3.new(-0.15, 0.36, 0.4), Vector3.new(0.5, 0.26, -0.35),
		}) do
			local seed = prop(model, {
				Name = "BerrySeed" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(0.13, 0.18, 0.13),
				Color = item.color2,
			})
			seed.CFrame = tilt * CFrame.new(off.X, off.Y, off.Z)
		end
		local stem = prop(model, {
			Name = "BerryStem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.34, 0.12, 0.12),
			Color = Color3.fromRGB(124, 176, 96),
		})
		stem.CFrame = tilt * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
		local leaf = prop(model, {
			Name = "BerryLeaf", Shape = Enum.PartType.Ball, Size = Vector3.new(0.34, 0.12, 0.2),
			Color = Color3.fromRGB(148, 200, 116),
		})
		leaf.CFrame = tilt * CFrame.new(0.18, 0.72, 0)
	end,
	hat_unicorn_horn = function(model, top, item)
		-- a slim golden spiral horn with a glowing tip
		local lean = top * CFrame.Angles(0, 0, math.rad(6))
		local radii = { 0.46, 0.32, 0.18 }
		for i, r in ipairs(radii) do
			local ring = prop(model, {
				Name = "HornRing", Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.34, r * 2, r * 2),
				Color = (i % 2 == 1) and item.color or item.color2,
			})
			ring.CFrame = lean * CFrame.new(0, (i - 1) * 0.32 + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
		end
		local tip = prop(model, {
			Name = "HornTip", Shape = Enum.PartType.Ball, Size = Vector3.new(0.16, 0.3, 0.16),
			Color = Color3.fromRGB(255, 244, 200), Material = Enum.Material.Neon,
		})
		tip.CFrame = lean * CFrame.new(0, 1.12, 0)
	end,
	hat_golden_halo = function(model, top, item)
		-- a floating ring of glowing gold beads
		for i = 1, 8 do
			local angle = (i / 8) * math.pi * 2
			local bead = prop(model, {
				Name = "HaloBead", Shape = Enum.PartType.Ball, Size = Vector3.new(0.22, 0.22, 0.22),
				Color = item.color, Material = Enum.Material.Neon,
			})
			bead.CFrame = top * CFrame.new(math.cos(angle) * 0.66, 0.55, math.sin(angle) * 0.66)
		end
	end,
	hat_crown = function(model, top, item)
		local band = prop(model, {
			Name = "CrownBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.42, 1.5, 1.5),
			Color = item.color, Reflectance = 0.18,
		})
		band.CFrame = top * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90))
		for i = 1, 4 do
			local angle = (i / 4) * math.pi * 2
			local point = prop(model, {
				Name = "CrownPoint", Shape = Enum.PartType.Ball, Size = Vector3.new(0.26, 0.4, 0.26),
				Color = item.color, Reflectance = 0.18,
			})
			point.CFrame = top * CFrame.new(math.cos(angle) * 0.62, 0.42, math.sin(angle) * 0.62)
		end
	end,
	-- The Rainbow Keeper Crown: the full-Rainbow-Book reward (never sold). A
	-- gold band ringed by six glowing points, one per rainbow color.
	hat_rainbow_keeper = function(model, top, item)
		local band = prop(model, {
			Name = "KeeperBand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.42, 1.5, 1.5),
			Color = item.color, Reflectance = 0.25,
		})
		band.CFrame = top * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90))
		local rainbow = {
			Color3.fromRGB(255, 120, 120), Color3.fromRGB(255, 190, 100),
			Color3.fromRGB(255, 240, 140), Color3.fromRGB(150, 230, 160),
			Color3.fromRGB(140, 200, 255), Color3.fromRGB(200, 150, 255),
		}
		for i = 1, 6 do
			local angle = (i / 6) * math.pi * 2
			local point = prop(model, {
				Name = "KeeperPoint", Shape = Enum.PartType.Ball, Size = Vector3.new(0.24, 0.44, 0.24),
				Color = rainbow[i], Material = Enum.Material.Neon,
			})
			point.CFrame = top * CFrame.new(math.cos(angle) * 0.62, 0.45, math.sin(angle) * 0.62)
		end
	end,
}

local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

-- Trail emitters: same soft sparkle, each with its own colour + personality.
local function addTrail(body: BasePart, item)
	local trail = Instance.new("ParticleEmitter")
	trail.Name = "BoutiqueTrail"
	trail.Texture = SPARKLE_TEXTURE
	trail.LightEmission = 0.85
	trail.Lifetime = NumberRange.new(0.7, 1.3)
	trail.Rate = 9
	trail.Speed = NumberRange.new(0.5, 1.5)
	trail.SpreadAngle = Vector2.new(40, 40)
	trail.EmissionDirection = Enum.NormalId.Bottom
	trail.Acceleration = Vector3.new(0, -1, 0)
	trail.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1),
	})
	if item.id == "trail_rainbow" then
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 160)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 224, 130)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(150, 230, 180)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 180, 255)),
		})
		trail.Rate = 14
	elseif item.id == "trail_bubbles" then
		trail.Color = ColorSequence.new(item.color)
		trail.LightEmission = 0.4
		trail.Acceleration = Vector3.new(0, 1.6, 0) -- bubbles drift UP
		trail.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.7, 0.8), NumberSequenceKeypoint.new(1, 0),
		})
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1),
		})
	elseif item.id == "trail_stars" then
		trail.Color = ColorSequence.new(item.color)
		trail.RotSpeed = NumberRange.new(-120, 120)
	elseif item.id == "trail_comet" then
		-- premium: a bright golden streak that races out behind the buddy
		trail.Color = ColorSequence.new(item.color, Color3.fromRGB(255, 250, 230))
		trail.LightEmission = 1
		trail.Rate = 16
		trail.Speed = NumberRange.new(2, 4)
		trail.Lifetime = NumberRange.new(0.45, 0.85)
		trail.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.0), NumberSequenceKeypoint.new(1, 0),
		})
	elseif item.id == "trail_aurora" then
		-- premium: slow northern-lights ribbons drifting upward
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, item.color or Color3.fromRGB(140, 230, 200)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 180, 255)),
			ColorSequenceKeypoint.new(1, item.color2 or Color3.fromRGB(190, 150, 255)),
		})
		trail.Rate = 12
		trail.Lifetime = NumberRange.new(1.2, 1.8)
		trail.Acceleration = Vector3.new(0, 0.8, 0)
		trail.SpreadAngle = Vector2.new(60, 60)
		trail.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.5, 0.95), NumberSequenceKeypoint.new(1, 0),
		})
	else -- hearts (and any future colour trail)
		trail.Color = ColorSequence.new(item.color or Color3.fromRGB(255, 200, 220))
	end
	trail.Parent = body
end

local function addBalloon(model: Model, body: BasePart, item)
	local anchor = body.CFrame * CFrame.new(-1.15, 0, 0)
	local string = prop(model, {
		Name = "BalloonString", Size = Vector3.new(0.08, 2.1, 0.08),
		Color = Color3.fromRGB(250, 245, 240),
	})
	string.CFrame = anchor * CFrame.new(-0.25, 1.05, 0) * CFrame.Angles(0, 0, math.rad(12))

	if item.id == "balloon_rainbow_heart" then
		-- premium: a heart of two lobes + a point, trailing rainbow sparkles
		local at = anchor * CFrame.new(-0.5, 2.3, 0)
		for _, sx in ipairs({ -1, 1 }) do
			local lobe = prop(model, {
				Name = "HeartLobe", Shape = Enum.PartType.Ball, Size = Vector3.new(0.85, 0.85, 0.7),
				Color = item.color, Reflectance = 0.08,
			})
			lobe.CFrame = at * CFrame.new(sx * 0.3, 0.18, 0)
		end
		local point = prop(model, {
			Name = "HeartPoint", Size = Vector3.new(0.95, 0.95, 0.62),
			Color = item.color, Reflectance = 0.08,
		})
		point.CFrame = at * CFrame.new(0, -0.22, 0) * CFrame.Angles(0, 0, math.rad(45))
		local shine = prop(model, {
			Name = "BalloonShine", Shape = Enum.PartType.Ball, Size = Vector3.new(0.26, 0.34, 0.26),
			Color = Color3.fromRGB(255, 255, 255), Transparency = 0.25,
		})
		shine.CFrame = at * CFrame.new(-0.5, 0.42, -0.18)
		local rainbow = Instance.new("ParticleEmitter")
		rainbow.Name = "HeartRainbow"
		rainbow.Texture = SPARKLE_TEXTURE
		rainbow.LightEmission = 0.9
		rainbow.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 150, 160)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 224, 130)),
			ColorSequenceKeypoint.new(0.66, Color3.fromRGB(150, 230, 180)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 180, 255)),
		})
		rainbow.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.5), NumberSequenceKeypoint.new(1, 0),
		})
		rainbow.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.3), NumberSequenceKeypoint.new(1, 1),
		})
		rainbow.Lifetime = NumberRange.new(0.8, 1.3)
		rainbow.Rate = 5
		rainbow.Speed = NumberRange.new(0.5, 1.2)
		rainbow.SpreadAngle = Vector2.new(180, 180)
		rainbow.Parent = point
		return
	end

	local balloon = prop(model, {
		Name = "Balloon", Shape = Enum.PartType.Ball, Size = Vector3.new(1.25, 1.5, 1.25),
		Color = item.color, Reflectance = 0.08,
	})
	balloon.CFrame = anchor * CFrame.new(-0.5, 2.25, 0)
	local shine = prop(model, {
		Name = "BalloonShine", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.4, 0.3),
		Color = Color3.fromRGB(255, 255, 255), Transparency = 0.25,
	})
	shine.CFrame = anchor * CFrame.new(-0.78, 2.55, -0.3)
end

-- Dress a freshly built buddy in everything its owner has equipped.
local function applyCosmetics(model: Model, body: BasePart, equipped: { [string]: string })
	local hat = equipped.hat and CosmeticsConfig.get(equipped.hat)
	if hat then
		local builder = HAT_BUILDERS[hat.id]
		if builder then
			-- each shape says where its hat sits (the factory's HatOffset is
			-- unscaled, relative to the Body centre)
			local hatY = (model:GetAttribute("HatOffset") or 2.0) * model:GetScale()
			builder(model, body.CFrame * CFrame.new(0, hatY, 0), hat)
		end
	end
	local trail = equipped.trail and CosmeticsConfig.get(equipped.trail)
	if trail then
		addTrail(body, trail)
	end
	local balloon = equipped.balloon and CosmeticsConfig.get(equipped.balloon)
	if balloon then
		addBalloon(model, body, balloon)
	end
end

local function buildBuddy(def, owner: Player, variantLevel: number, equipped: { [string]: string }, isVip: boolean, dressUp: boolean): Model
	-- The buddy IS the friend's real shape, just companion-sized.
	local model = SquishyModelFactory.build(def)
	model.Name = "Buddy"
	model:ScaleTo(BUDDY_SCALE)
	-- A buddy must never block clicks, raycasts, or physics (so squishing the
	-- world friends through it still works).
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
		end
	end
	local body = model.PrimaryPart :: BasePart

	-- mesh bodies have card-faithful faces baked in; only the part-built
	-- archetypes need the billboard face
	if model:GetAttribute("BakedFace") ~= true then
		addFace(body)
	end
	addVariantAura(body, variantLevel)
	if isVip then
		addVipAura(body)
	end
	-- the boutique outfit rides the FIRST buddy only (one hat, one owner)
	if dressUp then
		applyCosmetics(model, body, equipped)
	end

	-- The show-off tag: whose buddy it is, plus the VIP crown and the variant
	-- badge (✨/🌈), so kids can spot each other's favourites across the play zone.
	local icon = VariantConfig.iconFor(variantLevel)
	local tagText = (if isVip then "👑 " else "")
		.. (icon ~= "" and icon .. " " or "") .. owner.DisplayName .. "'s " .. def.DisplayName

	local nameGui = Instance.new("BillboardGui")
	nameGui.Name = "BuddyName"
	nameGui.Size = UDim2.fromOffset(220, 24)
	-- sits ABOVE hat height (hats reach ~+2.4), so a Party Hat is never hidden
	-- behind the always-on-top name tag
	nameGui.StudsOffsetWorldSpace = Vector3.new(0, 3.3, 0)
	nameGui.AlwaysOnTop = true
	nameGui.MaxDistance = 80
	nameGui.Parent = body
	local nameLbl = Instance.new("TextLabel")
	nameLbl.BackgroundTransparency = 1
	nameLbl.Size = UDim2.fromScale(1, 1)
	nameLbl.Font = Enum.Font.FredokaOne
	nameLbl.TextSize = 16
	nameLbl.TextColor3 = if variantLevel >= 1 then VariantConfig.colorFor(variantLevel) else Color3.fromRGB(110, 80, 110)
	nameLbl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.TextStrokeTransparency = 0.2
	nameLbl.Text = tagText
	nameLbl.Parent = nameGui

	return model
end

-- Where a buddy wants to be: behind, to one side (slot 1 right, slot 2 left),
-- and a little above the owner.
local function targetPosition(hrp: BasePart, slot: number): Vector3
	local side = if slot == 2 then -2.4 else 2.4
	local cf = hrp.CFrame * CFrame.new(side, 0.6, 4.2)
	return cf.Position
end

local function clearBuddies(player: Player)
	local slots = buddies[player]
	if slots then
		for _, m in pairs(slots) do
			m:Destroy()
		end
		buddies[player] = nil
	end
end

-- Respawn a player's companions from their profile (both slots + VIP flair).
-- The one entry point for every "the buddy changed" moment: equips, cosmetic
-- changes, variant shine-ups, pass purchases.
function BuddyService.refresh(player: Player)
	clearBuddies(player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	local isVip = MonetizationService.ownsPass(player, "VIP")
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local ids: { [number]: string? } = { profile.EquippedBuddyId }
	-- the second companion walks only while the Extra Buddy Slot pass is owned
	-- (the equip itself persists, so it comes right back when the pass does)
	if MonetizationService.ownsPass(player, "BuddySlot") then
		ids[2] = profile.EquippedBuddyId2
	end
	local slots: { [number]: Model } = {}
	for slot, defId in pairs(ids) do
		local def = defId and SquishyData.getById(defId)
		if def then
			local model = buildBuddy(def, player, PlayerDataService.getVariant(player, defId),
				PlayerDataService.getEquippedCosmetics(player), isVip, slot == 1)
			model.Parent = buddyFolder
			slots[slot] = model
			-- Snap it next to the character right away so it doesn't fly in from origin.
			if hrp then
				model:PivotTo(CFrame.new(targetPosition(hrp, slot)))
			end
		end
	end
	if next(slots) then
		buddies[player] = slots
	end
end

local function update(dt: number)
	for player, slots in pairs(buddies) do
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		for slot, model in pairs(slots) do
			if not model.Parent then
				slots[slot] = nil
			elseif hrp then
				local bob = math.sin(os.clock() * 4 + #player.Name + slot * 1.7) * 0.4
				local goal = targetPosition(hrp, slot) + Vector3.new(0, bob, 0)
				local current = model:GetPivot().Position
				-- Snap if we somehow got far away (teleport / respawn), else ease.
				local newPos = if (current - goal).Magnitude > 60
					then goal
					else current:Lerp(goal, math.clamp(dt * 8, 0, 1))
				model:PivotTo(CFrame.new(newPos))
			end
		end
		if next(slots) == nil then
			buddies[player] = nil
		end
	end
end

function BuddyService.init()
	buddyFolder = Instance.new("Folder")
	buddyFolder.Name = "Buddies"
	buddyFolder.Parent = Workspace

	local function spawnFromProfile(player: Player)
		-- The profile loads asynchronously (DataStore) and can lag behind
		-- CharacterAdded, so wait until it's ready — otherwise a returning player's
		-- saved buddy silently won't spawn until they next respawn.
		local deadline = os.clock() + 15
		while not PlayerDataService.isReady(player) and player.Parent ~= nil and os.clock() < deadline do
			task.wait(0.1)
		end
		if player.Parent == nil then
			return
		end
		BuddyService.refresh(player)
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2) -- let the HumanoidRootPart exist
			spawnFromProfile(player)
		end)
		if player.Character then
			task.spawn(spawnFromProfile, player) -- don't block init while waiting for readiness
		end
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(clearBuddies)

	RunService.Heartbeat:Connect(update)
end

return BuddyService
