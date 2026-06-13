-- SquishyModelFactory (SERVER)
-- Builds each Squishy Friend's real 3D body out of soft native parts — no more
-- one-ball-fits-all. ~17 squishy archetypes (dumpling, bun, cube, bunny, bat,
-- ghost...) are parameterized and hand-tuned per friend in the SKINS table, so
-- a Strawberry Dumpling, a Frost Gel Cube, and a Moon Bat Blob each read as
-- themselves at a glance.
--
-- Contract with the rest of the game:
--  * The main mass is a Part named "Body" (the Model's PrimaryPart) centred on
--    the model pivot — SquishFx hangs the face/Joy bar on it, ClickDetectorssit
--    on the MODEL (so ears are squishable), and the base of every shape sits
--    ~2 studs below the Body centre (pads place pivots at y=2).
--  * "HatOffset" attribute = unscaled Y above the Body centre where a boutique
--    hat should sit (BuddyService multiplies by the model's scale).
--  * Parts are clickable (CanQuery on) — BuddyService turns that off for its
--    cosmetic copies.

local SquishyModelFactory = {}

local function C(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local WHITE = C(255, 252, 246)
local SPARKLE_TEX = "rbxasset://textures/particles/sparkles_main.dds"

local function part(parent: Model, props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
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

local function wedgePart(parent: Model, props): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

-- The main mass every archetype starts from. Centred at the origin; the model
-- pivot is the Body centre (shifted with pivotY for short shapes, so every
-- archetype's base lands on the ground when placed at a pad's pivot height).
local function makeBody(m: Model, size: Vector3, color: Color3, extra, pivotY: number?)
	local body = part(m, { Name = "Body", Shape = Enum.PartType.Ball, Size = size, Color = color, CFrame = CFrame.new() })
	if extra then
		for key, value in pairs(extra) do
			(body :: any)[key] = value
		end
	end
	if pivotY and pivotY ~= 0 then
		body.PivotOffset = CFrame.new(0, pivotY, 0)
	end
	m.PrimaryPart = body
	return body
end

local function addSparkle(body: BasePart, color: Color3, rate: number?)
	local em = Instance.new("ParticleEmitter")
	em.Name = "SkinSparkle"
	em.Texture = SPARKLE_TEX
	em.LightEmission = 0.9
	em.Color = ColorSequence.new(color, WHITE)
	em.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.9), NumberSequenceKeypoint.new(1, 0),
	})
	em.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.25), NumberSequenceKeypoint.new(1, 1),
	})
	em.Lifetime = NumberRange.new(0.9, 1.5)
	em.Rate = rate or 5
	em.Speed = NumberRange.new(0.8, 2)
	em.SpreadAngle = Vector2.new(180, 180)
	em.Parent = body
end

local function addGlow(body: BasePart, color: Color3, brightness: number?)
	local light = Instance.new("PointLight")
	light.Name = "SkinGlow"
	light.Color = color
	light.Brightness = brightness or 1.2
	light.Range = 12
	light.Parent = body
end

-- ── Archetype builders ──────────────────────────────────────────────────────
-- Each gets (model, p) where p is that friend's SKINS entry, and must leave the
-- Body centred at the origin with the shape's base near y = -2.

local A = {}

-- a pleated dumpling: squashed body, a little topknot, pleat bumps on the crown
function A.dumpling(m, p)
	local body = makeBody(m, Vector3.new(4.2, 3.6, 4.2), p.body)
	m:SetAttribute("HatOffset", 1.7)
	local knot = part(m, {
		Name = "Knot", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.0, 1.2),
		Color = p.accent or p.body, CFrame = CFrame.new(0, 1.75, 0),
	})
	if p.neonKnot then
		knot.Material = Enum.Material.Neon
	end
	for i = 1, 4 do
		local a = math.rad(i * 70 - 150)
		part(m, {
			Name = "Pleat", Shape = Enum.PartType.Ball, Size = Vector3.new(0.95, 0.7, 0.95),
			Color = p.body, CFrame = CFrame.new(math.cos(a) * 1.25, 1.35, math.sin(a) * 1.25),
		})
	end
	if p.fleck then
		for i = 1, 3 do
			local a = math.rad(i * 110)
			part(m, {
				Name = "Fleck", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3),
				Color = p.fleck, CFrame = CFrame.new(math.cos(a) * 1.7, 0.2 + (i % 2) * 0.7, math.sin(a) * 1.7),
			})
		end
	end
	return body
end

-- a soft bun: dome + a seam band around the middle (or rainbow stripes)
function A.bun(m, p)
	local body = makeBody(m, Vector3.new(4.3, 3.7, 4.3), p.body)
	m:SetAttribute("HatOffset", 1.7)
	local stripes = p.stripes or { p.accent }
	for i, color in ipairs(stripes) do
		part(m, {
			Name = "Seam" .. i, Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.34, 4.05 - (i - 1) * 0.5, 4.05 - (i - 1) * 0.5),
			Color = color, CFrame = CFrame.new(0, -0.2 + (i - 1) * 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)),
		})
	end
	if p.swirl then
		part(m, {
			Name = "Swirl", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 0.8, 1.5),
			Color = p.swirl, CFrame = CFrame.new(0, 1.75, 0),
		})
	end
	return body
end

-- mochi: extra-squashed and pillowy, with a soft dimple knot
function A.mochi(m, p)
	local body = makeBody(m, Vector3.new(4.4, 3.2, 4.4), p.body, p.glass and {
		Material = Enum.Material.Glass, Transparency = 0.18, Reflectance = 0.12,
	} or nil, 0.35)
	m:SetAttribute("HatOffset", 1.5)
	part(m, {
		Name = "Dimple", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 0.7, 1.1),
		Color = p.accent or p.body, CFrame = CFrame.new(0, 1.5, 0),
	})
	return body
end

-- a rounded cube (syrup, gel, stretch...) — optionally glassy with a neon core
function A.cube(m, p)
	local h = p.tall and 4.3 or 3.6
	local body = makeBody(m, Vector3.new(3.6, h, 3.6), p.body, {
		Shape = Enum.PartType.Block,
		Material = p.glass and Enum.Material.Glass or Enum.Material.SmoothPlastic,
		Transparency = p.glass and 0.25 or 0,
		Reflectance = p.glass and 0.1 or 0,
	})
	m:SetAttribute("HatOffset", h / 2 + 0.2)
	if p.core then
		part(m, {
			Name = "Core", Shape = Enum.PartType.Block, Size = Vector3.new(1.6, 1.6, 1.6),
			Color = p.core, Material = Enum.Material.Neon, CFrame = CFrame.new(),
		})
	end
	if p.ribbon then
		part(m, {
			Name = "Ribbon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 4.4, 4.4),
			Color = p.ribbon, Material = Enum.Material.Neon, Transparency = 0.35,
			CFrame = CFrame.new(0, 0.3, 0) * CFrame.Angles(math.rad(18), 0, math.rad(90)),
		})
	end
	if p.frost then
		part(m, {
			Name = "Frost", Shape = Enum.PartType.Ball, Size = Vector3.new(3.3, 1.0, 3.3),
			Color = p.frost, CFrame = CFrame.new(0, h / 2, 0),
		})
	end
	return body
end

-- a puff: a cloud of overlapping cream balls
function A.puff(m, p)
	local body = makeBody(m, Vector3.new(3.4, 3.4, 3.4), p.body)
	m:SetAttribute("HatOffset", 1.8)
	local puffs = {
		{ Vector3.new(-1.4, -0.5, 0.6), 2.4 }, { Vector3.new(1.4, -0.5, 0.5), 2.4 },
		{ Vector3.new(0, -0.7, -1.3), 2.5 }, { Vector3.new(0, 1.4, 0), 2.2 },
	}
	for i, q in ipairs(puffs) do
		part(m, {
			Name = "Puff" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(q[2], q[2], q[2]),
			Color = p.accent or p.body, CFrame = CFrame.new(q[1]),
		})
	end
	return body
end

-- onigiri: a flattened ball with a seaweed band low on the front
function A.riceball(m, p)
	local body = makeBody(m, Vector3.new(4.2, 3.8, 3.4), p.body)
	m:SetAttribute("HatOffset", 1.8)
	part(m, {
		Name = "Nori", Shape = Enum.PartType.Block, Size = Vector3.new(1.9, 1.5, 3.5),
		Color = p.accent, CFrame = CFrame.new(0, -1.25, 0),
	})
	return body
end

-- a wobbly flan: squashed-ball tiers with a caramel cap (balls, not rotated
-- cylinders — the model pivot keeps identity rotation that way)
function A.pudding(m, p)
	local body = makeBody(m, Vector3.new(4.4, 2.7, 4.4), p.body, nil, 0.65)
	m:SetAttribute("HatOffset", 2.2)
	part(m, {
		Name = "Tier", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 2.2, 3.4),
		Color = p.body, CFrame = CFrame.new(0, 1.1, 0),
	})
	part(m, {
		Name = "Caramel", Shape = Enum.PartType.Ball, Size = Vector3.new(3.0, 1.1, 3.0),
		Color = p.accent, CFrame = CFrame.new(0, 1.95, 0),
	})
	return body
end

-- a melty blob: dome + drips at the base (+ optional nub horns)
function A.blob(m, p)
	local body = makeBody(m, Vector3.new(4.4, 3.4, 4.4), p.body, p.glass and {
		Material = Enum.Material.Glass, Transparency = 0.22, Reflectance = 0.08,
	} or (p.neon and { Material = Enum.Material.Neon } or nil))
	m:SetAttribute("HatOffset", 1.6)
	local drips = { { -1.7, 0.4 }, { 1.5, 0.8 }, { 0.2, -1.8 } }
	for i, d in ipairs(drips) do
		part(m, {
			Name = "Drip" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.5, 1.1),
			Color = p.accent or p.body, Material = body.Material, Transparency = body.Transparency,
			CFrame = CFrame.new(d[1], -1.55, d[2]),
		})
	end
	if p.horns then
		for _, sx in ipairs({ -1, 1 }) do
			part(m, {
				Name = "Nub", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 1.1, 0.8),
				Color = p.horns, CFrame = CFrame.new(sx * 1.1, 1.75, 0) * CFrame.Angles(0, 0, math.rad(-sx * 14)),
			})
		end
	end
	if p.swirlHorn then
		for i = 1, 3 do
			local s = 1.0 - i * 0.22
			part(m, {
				Name = "Swirl" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(s, s * 0.8, s),
				Color = p.swirlHorn, Material = Enum.Material.Neon,
				CFrame = CFrame.new(0.25 * (i - 1), 1.5 + i * 0.42, 0),
			})
		end
	end
	return body
end

-- a squeeze orb: sphere with an equatorial band (stress-ball pinch)
function A.orb(m, p)
	local body = makeBody(m, Vector3.new(4.1, 4.1, 4.1), p.body, p.glass and {
		Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = p.shine or 0.15,
	} or nil)
	m:SetAttribute("HatOffset", 1.9)
	part(m, {
		Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 4.35, 4.35),
		Color = p.accent, Material = p.neonBand and Enum.Material.Neon or Enum.Material.SmoothPlastic,
		Transparency = p.neonBand and 0.2 or 0,
		CFrame = CFrame.new() * CFrame.Angles(0, 0, math.rad(90)),
	})
	if p.core then
		part(m, {
			Name = "Core", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8),
			Color = p.core, Material = Enum.Material.Neon, CFrame = CFrame.new(),
		})
	end
	return body
end

-- a jelly pad: low, wide, and proud of it
function A.pad(m, p)
	local body = makeBody(m, Vector3.new(5.2, 2.0, 5.2), p.body, p.glass and {
		Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.08,
	} or nil, 1.0)
	m:SetAttribute("HatOffset", 0.9)
	part(m, {
		Name = "PadTop", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 1.2, 3.4),
		Color = p.accent or p.body, Material = body.Material, Transparency = body.Transparency,
		CFrame = CFrame.new(0, 0.85, 0),
	})
	return body
end

-- a pill capsule lying on its side, two-tone
function A.capsule(m, p)
	local body = makeBody(m, Vector3.new(2.6, 3.0, 3.0), p.body, {
		Shape = Enum.PartType.Cylinder, Material = p.glass and Enum.Material.Glass or Enum.Material.SmoothPlastic,
		Transparency = p.glass and 0.2 or 0,
	}, 0.5)
	m:SetAttribute("HatOffset", 1.5)
	for i, sx in ipairs({ -1, 1 }) do
		part(m, {
			Name = "Cap" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(3.0, 3.0, 3.0),
			Color = (i == 1) and (p.accent or p.body) or p.body,
			Material = body.Material, Transparency = body.Transparency,
			CFrame = CFrame.new(sx * 1.3, 0, 0),
		})
	end
	return body
end

-- a happy teardrop
function A.drop(m, p)
	local body = makeBody(m, Vector3.new(4.0, 4.0, 4.0), p.body, p.glass and {
		Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.1,
	} or nil)
	m:SetAttribute("HatOffset", 2.4)
	for i = 1, 3 do
		local s = 2.4 - i * 0.6
		part(m, {
			Name = "Tip" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(s, s, s),
			Color = p.body, Material = body.Material, Transparency = body.Transparency,
			CFrame = CFrame.new(0, 1.4 + i * 0.5, 0),
		})
	end
	return body
end

-- ball with sucker dots (sticky pop fidget)
function A.popball(m, p)
	local body = makeBody(m, Vector3.new(4.2, 4.2, 4.2), p.body)
	m:SetAttribute("HatOffset", 2.0)
	for i = 1, 8 do
		local a = math.rad(i * 45)
		local y = (i % 2 == 0) and 0.9 or -0.4
		local r = (i % 2 == 0) and 1.75 or 2.0
		part(m, {
			Name = "Dot" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(0.85, 0.5, 0.85),
			Color = p.accent, CFrame = CFrame.new(math.cos(a) * r, y, math.sin(a) * r),
		})
	end
	return body
end

-- bunny: tall soft ears + a cotton tail
function A.bunny(m, p)
	local body = makeBody(m, Vector3.new(4.0, 3.6, 4.0), p.body)
	m:SetAttribute("HatOffset", 1.5)
	for _, sx in ipairs({ -1, 1 }) do
		local tilt = math.rad(sx * (p.floppy and 26 or 10))
		part(m, {
			Name = "Ear", Shape = Enum.PartType.Ball, Size = Vector3.new(1.05, 2.6, 0.8),
			Color = p.body, CFrame = CFrame.new(sx * 0.95, 2.5, 0) * CFrame.Angles(0, 0, tilt),
		})
		part(m, {
			Name = "InnerEar", Shape = Enum.PartType.Ball, Size = Vector3.new(0.55, 1.6, 0.5),
			Color = p.accent, CFrame = CFrame.new(sx * 0.95, 2.5, -0.18) * CFrame.Angles(0, 0, tilt),
		})
	end
	part(m, {
		Name = "Tail", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2),
		Color = WHITE, CFrame = CFrame.new(0, -0.7, 1.95),
	})
	if p.star then
		part(m, {
			Name = "EarStar", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.3),
			Color = p.star, Material = Enum.Material.Neon, CFrame = CFrame.new(1.25, 3.4, 0),
		})
	end
	return body
end

-- bat: pointy wedge ears + little wings
function A.bat(m, p)
	local body = makeBody(m, Vector3.new(4.1, 3.5, 4.1), p.body)
	m:SetAttribute("HatOffset", 1.6)
	for _, sx in ipairs({ -1, 1 }) do
		wedgePart(m, {
			Name = "Ear", Size = Vector3.new(0.7, 1.5, 1.1),
			Color = p.body, CFrame = CFrame.new(sx * 1.1, 2.1, 0) * CFrame.Angles(0, math.rad(sx * 90 + 90), 0),
		})
		wedgePart(m, {
			Name = "Wing", Size = Vector3.new(0.5, 1.7, 2.3),
			Color = p.accent, CFrame = CFrame.new(sx * 2.25, 0.2, 0.4) * CFrame.Angles(math.rad(14), math.rad(sx * 90 - 90), 0),
		})
	end
	if p.moon then
		part(m, {
			Name = "Moon", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.35),
			Color = p.moon, Material = Enum.Material.Neon, CFrame = CFrame.new(-1.5, 2.9, 0),
		})
	end
	return body
end

-- ghost: a dome with a wavy skirt and stubby arms (cozy, never scary)
function A.ghost(m, p)
	local body = makeBody(m, Vector3.new(4.0, 3.9, 4.0), p.body, p.neon and { Material = Enum.Material.Neon } or nil, -0.3)
	m:SetAttribute("HatOffset", 1.8)
	for i = 1, 5 do
		local a = math.rad(i * 72)
		part(m, {
			Name = "Skirt" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.7, 1.5),
			Color = p.body, Material = body.Material,
			CFrame = CFrame.new(math.cos(a) * 1.35, -1.65, math.sin(a) * 1.35),
		})
	end
	for _, sx in ipairs({ -1, 1 }) do
		part(m, {
			Name = "Arm", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 1.4, 0.9),
			Color = p.body, Material = body.Material,
			CFrame = CFrame.new(sx * 2.0, -0.1, -0.4) * CFrame.Angles(0, 0, math.rad(sx * 30)),
		})
	end
	return body
end

-- kitty: wedge ears + a curled tail (+ optional glowing collar)
function A.kitty(m, p)
	local body = makeBody(m, Vector3.new(4.0, 3.6, 4.0), p.body)
	m:SetAttribute("HatOffset", 1.6)
	for _, sx in ipairs({ -1, 1 }) do
		wedgePart(m, {
			Name = "Ear", Size = Vector3.new(0.8, 1.3, 1.2),
			Color = p.body, CFrame = CFrame.new(sx * 1.15, 2.05, 0) * CFrame.Angles(0, math.rad(sx * 90 + 90), 0),
		})
		part(m, {
			Name = "InnerEar", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.6, 0.4),
			Color = p.accent, CFrame = CFrame.new(sx * 1.12, 1.95, -0.1),
		})
	end
	part(m, {
		Name = "Tail1", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9),
		Color = p.body, CFrame = CFrame.new(0.8, -0.9, 2.0),
	})
	part(m, {
		Name = "Tail2", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7),
		Color = p.accent, CFrame = CFrame.new(1.35, -0.3, 2.35),
	})
	if p.collar then
		part(m, {
			Name = "Collar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 3.6, 3.6),
			Color = p.collar, Material = Enum.Material.Neon, Transparency = 0.25,
			CFrame = CFrame.new(0, -0.9, 0) * CFrame.Angles(0, 0, math.rad(90)),
		})
	end
	return body
end

-- critter: round ears, optional tiny fangs / stitched patch / head star
function A.critter(m, p)
	local body = makeBody(m, Vector3.new(4.1, 3.7, 4.1), p.body)
	m:SetAttribute("HatOffset", 1.6)
	for _, sx in ipairs({ -1, 1 }) do
		part(m, {
			Name = "Ear", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 0.7),
			Color = p.ears or p.body, CFrame = CFrame.new(sx * 1.35, 2.0, 0),
		})
		part(m, {
			Name = "InnerEar", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.4),
			Color = p.accent, CFrame = CFrame.new(sx * 1.35, 2.0, -0.25),
		})
	end
	if p.fangs then
		for _, sx in ipairs({ -1, 1 }) do
			wedgePart(m, {
				Name = "Fang", Size = Vector3.new(0.3, 0.5, 0.3),
				Color = WHITE, CFrame = CFrame.new(sx * 0.5, -1.0, -1.85) * CFrame.Angles(math.rad(180), 0, 0),
			})
		end
	end
	if p.patch then
		part(m, {
			Name = "Patch", Shape = Enum.PartType.Block, Size = Vector3.new(0.9, 0.9, 0.2),
			Color = p.patch, CFrame = CFrame.new(1.1, 0.5, -1.75) * CFrame.Angles(0, math.rad(-24), math.rad(10)),
		})
	end
	if p.star then
		part(m, {
			Name = "HeadStar", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.35),
			Color = p.star, Material = Enum.Material.Neon, CFrame = CFrame.new(0, 2.15, 0),
		})
	end
	return body
end

-- ── The 48 launch friends (+ the weekly 8), hand-tuned ─────────────────────
-- a = archetype; body/accent = its palette; spark/glow add magic for the fancy
-- tiers. Palettes follow each friend's NAME, not its rarity.

local SKINS = {
	-- Pudding Hills — squishy foods
	soft_dumpling = { a = "dumpling", body = C(255, 238, 214), accent = C(255, 208, 170) },
	jelly_bun = { a = "bun", body = C(255, 205, 190), accent = C(244, 150, 150), swirl = C(228, 90, 110) },
	peach_mochi = { a = "mochi", body = C(255, 200, 170), accent = C(248, 158, 130) },
	syrup_cube = { a = "cube", body = C(232, 168, 80), glass = true },
	cream_puff = { a = "puff", body = C(255, 244, 226), accent = C(255, 228, 196) },
	rice_ball_squish = { a = "riceball", body = C(252, 250, 244), accent = C(64, 90, 70) },
	marshmallow_puff = { a = "puff", body = C(255, 240, 244), accent = C(255, 222, 232) },
	pudding_pop = { a = "pudding", body = C(250, 222, 150), accent = C(196, 120, 60) },
	strawberry_dumpling = { a = "dumpling", body = C(248, 130, 150), accent = C(150, 208, 130), fleck = C(255, 244, 220) },
	rainbow_jelly_bun = { a = "bun", body = C(255, 248, 240), stripes = { C(248, 130, 140), C(255, 210, 120), C(140, 200, 235) } },
	sparkle_mochi = { a = "mochi", body = C(250, 244, 252), accent = C(222, 208, 245), spark = C(230, 215, 255) },
	golden_syrup_cube = { a = "cube", body = C(245, 190, 85), glass = true, core = C(255, 222, 120), spark = C(255, 226, 140) },
	galaxy_dumpling = { a = "dumpling", body = C(92, 78, 150), accent = C(150, 120, 220), neonKnot = true, spark = C(180, 160, 255), glow = C(150, 130, 235) },
	crystal_mochi = { a = "mochi", body = C(214, 240, 250), glass = true, accent = C(170, 220, 240), spark = C(210, 240, 255) },
	neon_dessert_blob = { a = "blob", body = C(255, 95, 180), neon = true, accent = C(255, 150, 210), glow = C(255, 120, 195) },
	celestial_dumpling_core = { a = "dumpling", body = C(255, 244, 222), accent = C(255, 214, 120), neonKnot = true, spark = C(255, 230, 160), glow = C(255, 226, 160) },

	-- Goo Coast — goo fidgets
	goo_ball = { a = "blob", body = C(110, 218, 195), glass = true, accent = C(90, 200, 180) },
	bubble_blob = { a = "popball", body = C(150, 220, 240), accent = C(210, 242, 252) },
	stretch_cube = { a = "cube", body = C(150, 230, 190), tall = true },
	soft_stress_orb = { a = "orb", body = C(202, 178, 240), accent = C(170, 140, 225) },
	jelly_pad = { a = "pad", body = C(176, 230, 120), glass = true, accent = C(200, 240, 150) },
	sticky_pop_ball = { a = "popball", body = C(248, 150, 130), accent = C(255, 200, 180) },
	wobble_drop = { a = "drop", body = C(135, 200, 245), glass = true },
	squish_capsule = { a = "capsule", body = C(255, 250, 245), accent = C(248, 150, 170), glass = true },
	glitter_goo_ball = { a = "blob", body = C(216, 130, 220), glass = true, accent = C(190, 110, 200), spark = C(240, 180, 250) },
	shockwave_blob = { a = "blob", body = C(110, 170, 250), accent = C(150, 200, 255), horns = C(170, 215, 255), glow = C(140, 190, 255) },
	frost_gel_cube = { a = "cube", body = C(180, 226, 245), glass = true, frost = C(240, 250, 255) },
	prism_stress_orb = { a = "orb", body = C(244, 248, 252), glass = true, shine = 0.35, accent = C(200, 160, 240), neonBand = true, spark = C(220, 230, 255) },
	plasma_goo_ball = { a = "orb", body = C(150, 110, 235), glass = true, accent = C(120, 90, 210), core = C(200, 160, 255), glow = C(170, 130, 255) },
	aurora_stretch_cube = { a = "cube", body = C(120, 210, 210), glass = true, tall = true, ribbon = C(170, 250, 220), spark = C(180, 250, 230) },
	cosmic_jelly_pad = { a = "pad", body = C(110, 95, 175), glass = true, accent = C(160, 140, 230), spark = C(190, 170, 255) },
	singularity_goo_core = { a = "orb", body = C(70, 60, 105), accent = C(170, 120, 255), neonBand = true, core = C(200, 160, 255), spark = C(190, 150, 255), glow = C(170, 130, 255) },

	-- Moonlit Hollow — creepy-cute (soft-spooky, never scary)
	blushy_bun_bunny = { a = "bunny", body = C(255, 214, 224), accent = C(255, 170, 195), floppy = true },
	squish_bat = { a = "bat", body = C(170, 150, 200), accent = C(140, 120, 175) },
	puff_ghost = { a = "ghost", body = C(238, 234, 248) },
	wobble_kitty = { a = "kitty", body = C(200, 190, 220), accent = C(255, 180, 200) },
	tiny_blob_monster = { a = "blob", body = C(160, 220, 190), accent = C(140, 200, 170), horns = C(120, 180, 160) },
	soft_fang_critter = { a = "critter", body = C(190, 150, 190), accent = C(225, 180, 215), fangs = true },
	sleepy_slime_pet = { a = "blob", body = C(150, 180, 235), glass = true, accent = C(130, 160, 220) },
	round_eared_creature = { a = "critter", body = C(222, 192, 178), accent = C(250, 215, 205) },
	star_eyed_bunny = { a = "bunny", body = C(235, 225, 250), accent = C(200, 180, 240), star = C(255, 224, 130), spark = C(240, 230, 160) },
	moon_bat_blob = { a = "bat", body = C(120, 110, 170), accent = C(95, 88, 140), moon = C(255, 230, 150), glow = C(180, 170, 230) },
	glow_ghost_puff = { a = "ghost", body = C(200, 245, 230), neon = true, glow = C(170, 240, 210) },
	candy_fang_creature = { a = "critter", body = C(255, 170, 195), ears = C(150, 230, 200), accent = C(255, 214, 230), fangs = true },
	dream_eater_squish = { a = "blob", body = C(80, 75, 130), accent = C(110, 100, 170), swirlHorn = C(190, 170, 255), spark = C(180, 160, 250), glow = C(160, 140, 235) },
	arcane_wobble_kitty = { a = "kitty", body = C(120, 95, 170), accent = C(190, 150, 235), collar = C(200, 160, 255), spark = C(200, 170, 255), glow = C(180, 140, 250) },
	phantom_jelly_beast = { a = "blob", body = C(150, 130, 200), glass = true, accent = C(130, 110, 185), horns = C(180, 160, 225), glow = C(170, 150, 230) },
	mythic_plush_familiar = { a = "critter", body = C(250, 238, 218), ears = C(235, 210, 185), accent = C(255, 200, 185), patch = C(190, 150, 130), star = C(255, 214, 110), spark = C(255, 230, 160) },

	-- Weekly event friends (simple, name-true takes on the archetypes)
	boblet = { a = "blob", body = C(170, 215, 245), accent = C(140, 195, 235) },
	dimpa = { a = "dumpling", body = C(250, 230, 205), accent = C(235, 200, 165) },
	gobble_puff = { a = "puff", body = C(255, 220, 185), accent = C(255, 200, 160) },
	gold_dumplio = { a = "dumpling", body = C(248, 205, 110), accent = C(255, 226, 150), spark = C(255, 230, 150) },
	moshi = { a = "mochi", body = C(255, 235, 240), accent = C(255, 205, 220) },
	puffkin = { a = "puff", body = C(225, 240, 220), accent = C(205, 230, 200) },
	soupy_blob = { a = "blob", body = C(255, 205, 150), glass = true, accent = C(245, 185, 130) },
	steamy = { a = "pudding", body = C(245, 240, 235), accent = C(220, 210, 205) },

	-- The Family Three (interim hand-built shapes — Meshy bodies swap in later,
	-- one carefully at a time). Each glows in her land's colour.
	apple_addy = { a = "orb", body = C(235, 92, 120), accent = C(132, 196, 112), glow = C(255, 150, 180), spark = C(255, 196, 214) },
	eggy_ellie = { a = "pudding", body = C(250, 248, 242), accent = C(120, 182, 246), glow = C(150, 200, 255), spark = C(196, 224, 255) },
	hot_dog_heidi = { a = "capsule", body = C(214, 150, 110), accent = C(192, 150, 236), glow = C(202, 162, 246), spark = C(224, 188, 250) },
}

-- A friend with no hand-tuned skin still gets a sensible shape from its name.
local KEYWORD_ARCHETYPES = {
	{ "dumpling", "dumpling" }, { "bun", "bun" }, { "mochi", "mochi" },
	{ "cube", "cube" }, { "puff", "puff" }, { "pudding", "pudding" },
	{ "ghost", "ghost" }, { "kitty", "kitty" }, { "bat", "bat" },
	{ "bunny", "bunny" }, { "pad", "pad" }, { "capsule", "capsule" },
	{ "drop", "drop" }, { "orb", "orb" }, { "blob", "blob" },
}

local FALLBACK_BODY = C(255, 196, 212)

-- Card-faithful mesh bodies (Meshy image-to-3D from the actual trading cards)
-- live in ServerStorage.MeshBodies, one MeshPart per friend id, prepared by
-- tools/mesh_pipeline (scaled to ~4 studs, face yawed to +Z via PivotOffset,
-- textures in a SurfaceAppearance). When a friend has one, it wins; the
-- part-built archetypes below remain the fallback for friends without.
local meshBodies = game:GetService("ServerStorage"):FindFirstChild("MeshBodies")

-- Build a friend's body. Always returns a Model whose PrimaryPart is "Body".
function SquishyModelFactory.build(def): Model
	local m = Instance.new("Model")
	m.Name = (def and def.DisplayName) or "Squishy Friend"

	local meshTemplate = meshBodies and def and meshBodies:FindFirstChild(def.Id)
	if meshTemplate then
		local body = meshTemplate:Clone()
		body.Name = "Body"
		-- These are hero collectibles kids look at from across a spread-out
		-- land. RenderFidelity.Automatic drops a distant mesh to a crude box
		-- approximation (it reads as "just an outline" — most visible against
		-- Moonlit Hollow's dark ground). Precise keeps the real shape at every
		-- distance; the meshes are small + simple so the cost is negligible.
		if body:IsA("MeshPart") then
			body.RenderFidelity = Enum.RenderFidelity.Precise
		end
		body.Parent = m
		m.PrimaryPart = body
		m:SetAttribute("HatOffset", body.Size.Y / 2 + 0.2)
		-- the card art bakes the face into the texture; SquishFx/BuddyService
		-- skip their billboard faces when they see this
		m:SetAttribute("BakedFace", true)
		return m
	end

	local skin = def and SKINS[def.Id]
	if not skin and def then
		local id = string.lower(def.Id or "")
		for _, kw in ipairs(KEYWORD_ARCHETYPES) do
			if string.find(id, kw[1], 1, true) then
				skin = { a = kw[2], body = FALLBACK_BODY, accent = C(255, 170, 195) }
				break
			end
		end
	end

	local body
	if skin and A[skin.a] then
		body = A[skin.a](m, skin)
	else
		-- the classic squishy ball, as a last resort
		body = makeBody(m, Vector3.new(4, 4, 4), FALLBACK_BODY)
		m:SetAttribute("HatOffset", 1.9)
	end

	if skin and skin.spark then
		addSparkle(body, skin.spark)
	end
	if skin and skin.glow then
		addGlow(body, skin.glow)
	end
	return m
end

-- Dress a friend in event GOLD: every part glimmers gold (keeping glassy/neon
-- materials so shapes stay readable), plus the golden sparkle. Mesh bodies drop
-- their SurfaceAppearance first — a texture would hide the gold tint.
function SquishyModelFactory.applyGolden(model: Model)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("SurfaceAppearance") then
			p:Destroy()
		elseif p:IsA("BasePart") then
			if p:IsA("MeshPart") then
				p.TextureID = ""
			end
			p.Color = C(255, 213, 110)
			p.Reflectance = math.max(p.Reflectance, 0.12)
		end
	end
	local body = model.PrimaryPart
	if body then
		addSparkle(body, C(255, 226, 140), 10)
	end
end

return SquishyModelFactory
