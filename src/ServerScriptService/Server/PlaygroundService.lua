--!strict
-- PlaygroundService (SERVER)
-- Wave 1 of the interactive playground (research-backed: swing/spin/slide/
-- bounce are THE things ages 4-9 return to, and together-structures beat
-- solo toys). Five pieces, one per craving:
--   • The Pudding Plunge — twin racing slides down a pastel tower into syrup
--     splash pools (spline-carried ride rings: zero stuck risk, instant re-ride)
--   • The Bounce Bog — a giant jelly trampoline in Goo Coast's dunes; bounce
--     WITHIN A BEAT of a friend and everyone's next launch goes higher
--   • Swing rows — a 3-across orchard swing set (Pudding) + a rope swing off
--     the pier that swings OVER the goo sea (jump off at the top = splash!)
--   • The Giant Spoon Seesaw — picnic-table physics-free rocker for two
--     (occupancy-driven sine, mass-independent, perfectly fair)
--   • The Mushroom Hop Trail — springy glowing caps that boing you cap-to-cap
--     up from the moonpool to the stargazing circle
-- All server-authoritative, anchored/CFramed (the engine-trusted ride
-- pattern), Atomic-streamed so nothing ever half-loads.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))

local PlaygroundService = {}

local CREAM = Color3.fromRGB(255, 250, 240)
local CARAMEL = Color3.fromRGB(240, 196, 138)

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for key, value in pairs(props) do
		(p :: any)[key] = value
	end
	return p
end

local function atomicModel(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	return m
end

-- ── the shared bounce ────────────────────────────────────────────────────────
-- Characters are CLIENT-owned, so the actual launch is applied by the owning
-- client (BouncePads.lua) reading these attributes off the tagged pad. The
-- server's Touched only drives the shared juice (squash, sparkles, and the
-- Bounce Bog's together-bonus window, published as an attribute).
local function makeBouncy(surface: BasePart, velocity: Vector3, juice: ((Model) -> ())?)
	surface.CanTouch = true
	surface:SetAttribute("BounceVelocity", velocity)
	CollectionService:AddTag(surface, "SquishyBouncy")
	surface.Touched:Connect(function(hit)
		local char = hit.Parent
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end
		local now = os.clock()
		local last = char:GetAttribute("LastBounceJuice")
		if last and now - (last :: number) < 0.45 then
			return
		end
		(char :: Model):SetAttribute("LastBounceJuice", now)
		if juice then
			juice(char :: Model)
		end
	end)
end

-- squash-and-stretch for anything bounced on (juice is half the fun)
local function squash(p: BasePart, baseSize: Vector3)
	TweenService:Create(p, TweenInfo.new(0.09, Enum.EasingStyle.Sine), {
		Size = Vector3.new(baseSize.X * 1.12, baseSize.Y * 0.6, baseSize.Z * 1.12),
	}):Play()
	task.delay(0.1, function()
		TweenService:Create(p, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = baseSize,
		}):Play()
	end)
end

local function sparkleBurst(at: BasePart, color: Color3, amount: number)
	local em = Instance.new("ParticleEmitter")
	em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	em.LightEmission = 0.9
	em.Color = ColorSequence.new(color, Color3.fromRGB(255, 250, 240))
	em.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0),
	})
	em.Lifetime = NumberRange.new(0.5, 0.9)
	em.Speed = NumberRange.new(4, 8)
	em.SpreadAngle = Vector2.new(180, 180)
	em.Enabled = false
	em.Parent = at
	em:Emit(amount)
	task.delay(2, function()
		em:Destroy()
	end)
end

-- ── small open-spline helper (slides) ────────────────────────────────────────
local function catmullRom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local a = 2 * p1
	local b = p2 - p0
	local c = 2 * p0 - 5 * p1 + 4 * p2 - p3
	local d = -p0 + 3 * p1 - 3 * p2 + p3
	return 0.5 * (a + b * t + c * (t * t) + d * (t * t * t))
end

-- Samples an OPEN spline (ends clamped) into ~2-stud arc-length points.
local function sampleOpenSpline(waypoints: { Vector3 }): ({ Vector3 }, number)
	local pts = { waypoints[1] }
	for i = 2, #waypoints do
		pts[i] = waypoints[i]
	end
	table.insert(pts, 1, waypoints[1])
	table.insert(pts, waypoints[#waypoints])
	local out: { Vector3 } = {}
	local total = 0
	local prev: Vector3? = nil
	for seg = 2, #pts - 2 do
		for s = 0, 15 do
			local pos = catmullRom(pts[seg - 1], pts[seg], pts[seg + 1], pts[seg + 2], s / 16)
			if prev then
				total += (pos - prev).Magnitude
			end
			table.insert(out, pos)
			prev = pos
		end
	end
	table.insert(out, pts[#pts - 1])
	total += (out[#out] - out[#out - 1]).Magnitude
	return out, total
end

-- a little floating sign helper (matches the world's billboard style)
local function floatingSign(onPart: BasePart, text: string)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(240, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Parent = onPart
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 22
	label.TextColor3 = Color3.fromRGB(225, 90, 150)
	label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
end

-- ═════════════════════════════════════════════════════════════════════════════
-- THE PUDDING PLUNGE — twin racing slides (Pudding Hills, south-east meadow;
-- the chutes run NORTH toward the picnic so they never cross the coaster track)
-- ═════════════════════════════════════════════════════════════════════════════
local function buildPuddingPlunge()
	local zone = ZoneConfig.get("Pudding Hills")
	if not zone then return end
	local center = zone.center
	local model = atomicModel("PuddingPlunge", Workspace)
	local base = center + Vector3.new(78, 0, 104)

	-- the tower: a pastel layer-cake column with a stair ramp wrapping up
	for i, layer in ipairs({
		{ w = 18, h = 7, c = Color3.fromRGB(255, 214, 150) },
		{ w = 14, h = 7, c = Color3.fromRGB(255, 196, 212) },
		{ w = 10, h = 7, c = CREAM },
	}) do
		local tier = part({
			Name = "TowerTier" .. i, Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(layer.h, layer.w, layer.w), Color = layer.c,
			CanCollide = true, CanQuery = true,
		})
		tier.CFrame = CFrame.new(base + Vector3.new(0, (i - 1) * 7 + 3.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		tier.Parent = model
	end
	-- top deck + cherry
	local deck = part({
		Name = "TowerDeck", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 13, 13),
		Color = CARAMEL, CanCollide = true, CanQuery = true,
	})
	deck.CFrame = CFrame.new(base + Vector3.new(0, 21.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	deck.Parent = model
	local cherry = part({
		Name = "TowerCherry", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4),
		Color = Color3.fromRGB(214, 40, 70), Reflectance = 0.12,
	})
	cherry.Position = base + Vector3.new(0, 26, 0)
	cherry.Parent = model
	-- stairs: straight flight on the south side (the chutes own the north)
	for s = 0, 13 do
		local step = part({
			Name = "TowerStep", Size = Vector3.new(5, 0.6, 2.6),
			Color = (s % 2 == 0) and CREAM or Color3.fromRGB(255, 214, 150),
			CanCollide = true, CanQuery = true,
		})
		step.Position = base + Vector3.new(0, 1 + s * 1.55, 22 - s * 1.55)
		step.Parent = model
	end
	local rail = part({
		Name = "StairRail", Size = Vector3.new(0.6, 2, 24),
		Color = CREAM, CanCollide = false,
	})
	rail.Position = base + Vector3.new(2.8, 12, 11.5)
	rail.CFrame = CFrame.new(rail.Position) * CFrame.Angles(math.rad(45), 0, 0)
	rail.Parent = model

	floatingSign(deck, "🍮 The Pudding Plunge")

	-- the two chutes: mirrored S-curves from deck height down to splash pools
	local chuteSpecs = {
		{ sign = -1, color = Color3.fromRGB(255, 170, 195) },
		{ sign = 1, color = Color3.fromRGB(170, 200, 255) },
	}
	for _, spec in ipairs(chuteSpecs) do
		local sx = spec.sign
		local waypoints = {
			base + Vector3.new(sx * 6, 21.6, -1),
			base + Vector3.new(sx * 14, 17, -8),
			base + Vector3.new(sx * 19, 12, -18),
			base + Vector3.new(sx * 14, 7, -28),
			base + Vector3.new(sx * 10, 2.6, -36),
			base + Vector3.new(sx * 10, 1.6, -44),
		}
		local samples, total = sampleOpenSpline(waypoints)

		-- ribbon trough + low rails
		for i = 1, #samples - 3, 2 do
			local a, b = samples[i], samples[i + 2]
			local mid = (a + b) / 2
			local len = (b - a).Magnitude
			local boardCF = CFrame.lookAt(mid, b, Vector3.yAxis)
			local board = part({
				Name = "ChuteBoard", Size = Vector3.new(4.4, 0.5, len + 0.5),
				Color = spec.color,
			})
			board.CFrame = boardCF
			board.Parent = model
			for _, rs in ipairs({ -1, 1 }) do
				local lip = part({
					Name = "ChuteLip", Size = Vector3.new(0.5, 1.4, len + 0.5),
					Color = CREAM,
				})
				lip.CFrame = boardCF * CFrame.new(rs * 2.2, 0.8, 0)
				lip.Parent = model
			end
		end

		-- splash pool at the bottom
		local poolAt = base + Vector3.new(sx * 10, 0, -47)
		local pool = part({
			Name = "SplashPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 13, 13),
			Color = Color3.fromRGB(255, 226, 160), Material = Enum.Material.Glass,
			Transparency = 0.25, Reflectance = 0.1,
		})
		pool.CFrame = CFrame.new(poolAt + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
		pool.Parent = model

		-- the ride ring: a jelly inner-tube with a Seat, carried down the spline
		local ring = atomicModel("PlungeRing", model)
		local tube = part({
			Name = "Tube", Shape = Enum.PartType.Ball, Size = Vector3.new(3.6, 1.4, 3.6),
			Color = spec.color, Material = Enum.Material.Glass, Transparency = 0.2,
		})
		tube.Parent = ring
		ring.PrimaryPart = tube
		local seat = Instance.new("Seat")
		seat.Name = "RingSeat"
		seat.Size = Vector3.new(2, 0.4, 2)
		seat.Color = CREAM
		seat.Material = Enum.Material.SmoothPlastic
		seat.Anchored = true
		seat.CanQuery = true
		seat.Parent = ring

		local topCF = CFrame.lookAt(samples[1], samples[3], Vector3.yAxis)
		local function parkAtTop()
			ring:PivotTo(topCF + Vector3.new(0, 1, 0))
			seat.CFrame = (topCF + Vector3.new(0, 1.6, 0))
		end
		parkAtTop()

		-- riding: when someone sits, glide the ring down, splash, hop them out,
		-- then zip the empty ring back up for the next racer
		local busy = false
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			local occupant = seat.Occupant
			if not occupant or busy then
				return
			end
			busy = true
			task.spawn(function()
				task.wait(0.5)
				-- accelerate down the arc-length samples (slide feel: fast middle)
				local dist = 0
				local speed = 8
				local idx = 1
				while idx < #samples - 1 and seat.Occupant ~= nil do
					local dt = task.wait()
					speed = math.min(speed + 26 * dt, 30)
					dist += speed * dt
					-- advance to the sample at this distance
					local walked = 0
					idx = 1
					for i = 2, #samples do
						walked += (samples[i] - samples[i - 1]).Magnitude
						if walked >= dist then
							idx = i
							break
						end
						idx = i
					end
					local pos = samples[math.min(idx, #samples - 1)]
					local nxt = samples[math.min(idx + 1, #samples)]
					local cf = CFrame.lookAt(pos, nxt, Vector3.yAxis)
					ring:PivotTo(cf + Vector3.new(0, 1, 0))
					seat.CFrame = cf + Vector3.new(0, 1.6, 0)
				end
				-- splash!
				local rider = seat.Occupant
				sparkleBurst(pool, spec.color, 18)
				if rider then
					rider.Sit = false
					local t0 = os.clock()
					while rider:GetState() == Enum.HumanoidStateType.Seated and os.clock() - t0 < 1 do
						task.wait(0.05)
					end
					local char = rider.Parent :: Model?
					if char then
						char:PivotTo(CFrame.new(poolAt + Vector3.new(0, 4, -4)))
					end
				end
				-- the empty ring zips back up
				task.wait(0.4)
				parkAtTop()
				busy = false
			end)
		end)
	end
end

-- ═════════════════════════════════════════════════════════════════════════════
-- THE BOUNCE BOG — a giant jelly trampoline (Goo Coast, southern dunes)
-- ═════════════════════════════════════════════════════════════════════════════
local recentBounces: { number } = {}

local function buildBounceBog()
	local zone = ZoneConfig.get("Goo Coast")
	if not zone then return end
	local center = zone.center
	local model = atomicModel("BounceBog", Workspace)
	local at = center + Vector3.new(30, 0, 96)

	local rim = part({
		Name = "BogRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 24, 24),
		Color = Color3.fromRGB(150, 220, 224), CanCollide = true, CanQuery = true,
	})
	rim.CFrame = CFrame.new(at + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	rim.Parent = model

	local drumSize = Vector3.new(3, 20, 20)
	local drum = part({
		Name = "BogDrum", Shape = Enum.PartType.Cylinder, Size = drumSize,
		Color = Color3.fromRGB(140, 230, 214), Material = Enum.Material.Glass,
		Transparency = 0.2, Reflectance = 0.08, CanCollide = true, CanQuery = true,
	})
	drum.CFrame = CFrame.new(at + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	drum.Parent = model
	floatingSign(drum, "🫧 The Bounce Bog")

	-- normal bounce ~17 studs; the together-bonus (~26) opens for everyone when
	-- two friends bounce within the same beat (published via PartyUntil)
	drum:SetAttribute("PartyVelocity", Vector3.new(0, 102, 0))
	makeBouncy(drum, Vector3.new(0, 82, 0), function()
		squash(drum, drumSize)
		local now = os.clock()
		table.insert(recentBounces, now)
		for i = #recentBounces, 1, -1 do
			if now - recentBounces[i] > 0.6 then
				table.remove(recentBounces, i)
			end
		end
		if #recentBounces >= 2 then
			drum:SetAttribute("PartyUntil", workspace:GetServerTimeNow() + 4)
			sparkleBurst(drum, Color3.fromRGB(255, 226, 150), 26)
		end
	end)
end

-- ═════════════════════════════════════════════════════════════════════════════
-- SWING ROWS — scale the proven hit (orchard 3-across + pier swing over the goo)
-- ═════════════════════════════════════════════════════════════════════════════
local function buildSwingSet(parent: Instance, at: Vector3, faceToward: Vector3, seatCount: number, opts: { frame: Color3, seatColors: { Color3 }, ropeLen: number, amplitude: number, period: number, name: string })
	local model = atomicModel(opts.name, parent)
	local face = CFrame.lookAt(Vector3.new(at.X, 0, at.Z), Vector3.new(faceToward.X, 0, faceToward.Z))
	local width = seatCount * 5.4 + 2
	local beamY = opts.ropeLen + 4.6

	for _, sx in ipairs({ -1, 1 }) do
		local leg = part({
			Name = "SwingLeg", Size = Vector3.new(1, beamY + 0.6, 1),
			Color = opts.frame, CanCollide = true, CanQuery = true,
		})
		leg.CFrame = face * CFrame.new(sx * width / 2, (beamY + 0.6) / 2, 0)
		leg.Parent = model
	end
	local beam = part({
		Name = "SwingBeam", Size = Vector3.new(width + 1.4, 1, 1),
		Color = opts.frame,
	})
	beam.CFrame = face * CFrame.new(0, beamY, 0)
	beam.Parent = model

	for si = 1, seatCount do
		local sxOff = (si - (seatCount + 1) / 2) * 5.4
		local swing = Instance.new("Model")
		swing.Name = "SwingSeat" .. si
		local pivotCF = face * CFrame.new(sxOff, beamY, 0)
		local pivotPart = part({
			Name = "Pivot", Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1,
		})
		pivotPart.CFrame = pivotCF
		pivotPart.Parent = swing
		swing.PrimaryPart = pivotPart
		for _, rs in ipairs({ -1, 1 }) do
			local rope = part({
				Name = "Rope", Size = Vector3.new(0.2, opts.ropeLen, 0.2),
				Color = Color3.fromRGB(236, 228, 244),
			})
			rope.CFrame = pivotCF * CFrame.new(rs * 1.5, -opts.ropeLen / 2, 0)
			rope.Parent = swing
		end
		local seat = Instance.new("Seat")
		seat.Name = "Seat"
		seat.Size = Vector3.new(3, 0.4, 1.6)
		seat.Color = opts.seatColors[((si - 1) % #opts.seatColors) + 1]
		seat.Material = Enum.Material.SmoothPlastic
		seat.Anchored = true
		seat.CanQuery = true
		seat.CFrame = pivotCF * CFrame.new(0, -opts.ropeLen, 0)
		seat.Parent = swing
		swing.Parent = model

		-- each seat is its own gentle pendulum, phase-offset from its neighbors
		task.spawn(function()
			local t = si * 0.9
			RunService.Heartbeat:Connect(function(dt)
				t += dt
				local a = math.sin(t * math.pi * 2 / opts.period) * opts.amplitude
				swing:PivotTo(pivotCF * CFrame.Angles(a, 0, 0))
			end)
		end)
	end
	return model
end

local function buildSwingRows()
	local pudding = ZoneConfig.get("Pudding Hills")
	if pudding then
		-- a licorice swing set at the orchard's southern edge, facing the wheel
		buildSwingSet(Workspace, pudding.center + Vector3.new(64, 0, -14), pudding.center + Vector3.new(67, 0, 30), 3, {
			frame = Color3.fromRGB(255, 150, 170),
			seatColors = { Color3.fromRGB(255, 210, 120), Color3.fromRGB(170, 200, 255), Color3.fromRGB(180, 230, 200) },
			ropeLen = 7,
			amplitude = math.rad(9),
			period = 4.6,
			name = "OrchardSwings",
		})
	end
	local goo = ZoneConfig.get("Goo Coast")
	if goo then
		-- a rope swing hanging out over the goo sea beside the pier: bail at the
		-- top of the arc and SPLASH (no damage; swimming back is part of the fun)
		buildSwingSet(Workspace, goo.center + Vector3.new(10, 0, -38), goo.center + Vector3.new(60, 0, -60), 1, {
			frame = Color3.fromRGB(206, 170, 120),
			seatColors = { Color3.fromRGB(255, 190, 200) },
			ropeLen = 9,
			amplitude = math.rad(16),
			period = 5.2,
			name = "PierSwing",
		})
	end
end

-- ═════════════════════════════════════════════════════════════════════════════
-- THE GIANT SPOON SEESAW — picnic clearing, two riders, perfectly fair
-- ═════════════════════════════════════════════════════════════════════════════
local function buildSpoonSeesaw()
	local zone = ZoneConfig.get("Pudding Hills")
	if not zone then return end
	local center = zone.center
	local model = atomicModel("SpoonSeesaw", Workspace)
	local at = center + Vector3.new(100, 0, 54)
	local face = CFrame.lookAt(Vector3.new(at.X, 0, at.Z), Vector3.new(center.X + 90, 0, center.Z + 43))

	-- the strawberry fulcrum
	local berry = part({
		Name = "BerryFulcrum", Shape = Enum.PartType.Ball, Size = Vector3.new(4.4, 4, 4.4),
		Color = Color3.fromRGB(232, 64, 92), CanCollide = true, CanQuery = true,
	})
	berry.CFrame = face * CFrame.new(0, 1.6, 0)
	berry.Parent = model
	for s = 1, 5 do
		local seed = part({
			Name = "BerrySeed", Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.45, 0.3),
			Color = Color3.fromRGB(255, 226, 150),
		})
		local a = math.rad(s * 72)
		seed.CFrame = face * CFrame.new(math.cos(a) * 1.8, 1.6 + math.sin(a) * 1.4, -1.2)
		seed.Parent = model
	end

	-- the spoon: handle + bowl, with a seat near each end
	local rocker = Instance.new("Model")
	rocker.Name = "Spoon"
	local pivotCF = face * CFrame.new(0, 3.8, 0)
	local pivotPart = part({ Name = "Pivot", Size = Vector3.new(0.5, 0.5, 0.5), Transparency = 1 })
	pivotPart.CFrame = pivotCF
	pivotPart.Parent = rocker
	rocker.PrimaryPart = pivotPart
	local handle = part({
		Name = "SpoonHandle", Size = Vector3.new(1.6, 0.6, 13),
		Color = Color3.fromRGB(206, 170, 120), CanCollide = true, CanQuery = true,
	})
	handle.CFrame = pivotCF
	handle.Parent = rocker
	local bowl = part({
		Name = "SpoonBowl", Shape = Enum.PartType.Ball, Size = Vector3.new(4.6, 1.2, 5.4),
		Color = Color3.fromRGB(214, 178, 130), CanCollide = true, CanQuery = true,
	})
	bowl.CFrame = pivotCF * CFrame.new(0, -0.1, -8)
	bowl.Parent = rocker
	local seats: { Seat } = {}
	for i, dz in ipairs({ -7.6, 5.6 }) do
		local seat = Instance.new("Seat")
		seat.Name = "SeesawSeat" .. i
		seat.Size = Vector3.new(2.2, 0.4, 2)
		seat.Color = CREAM
		seat.Material = Enum.Material.SmoothPlastic
		seat.Anchored = true
		seat.CanQuery = true
		seat.CFrame = pivotCF * CFrame.new(0, 0.5, dz)
		seat.Parent = rocker
		seats[i] = seat
	end
	rocker.Parent = model
	floatingSign(berry, "🥄 Spoon Seesaw")

	-- occupancy-driven rocking: empty = level, one = tilt toward them,
	-- two = a smooth happy rock (mass-independent, nobody gets pinned)
	task.spawn(function()
		local angle = 0
		local t = 0
		RunService.Heartbeat:Connect(function(dt)
			t += dt
			local a1 = seats[1].Occupant ~= nil
			local a2 = seats[2].Occupant ~= nil
			local target
			if a1 and a2 then
				target = math.sin(t * math.pi * 2 / 2.4) * math.rad(13)
			elseif a1 then
				target = -math.rad(15)
			elseif a2 then
				target = math.rad(15)
			else
				target = 0
			end
			angle += (target - angle) * math.min(1, dt * 4)
			rocker:PivotTo(pivotCF * CFrame.Angles(angle, 0, 0))
		end)
	end)
end

-- ═════════════════════════════════════════════════════════════════════════════
-- THE MUSHROOM HOP TRAIL — springy caps from the moonpool up to the stargazers
-- ═════════════════════════════════════════════════════════════════════════════
local function buildMushroomHops()
	local zone = ZoneConfig.get("Moonlit Hollow")
	if not zone then return end
	local center = zone.center
	local model = atomicModel("MushroomHopTrail", Workspace)
	local capColors = { Color3.fromRGB(190, 130, 255), Color3.fromRGB(130, 200, 255), Color3.fromRGB(255, 150, 220), Color3.fromRGB(160, 255, 220) }

	local hops = {
		center + Vector3.new(24, 0, -42),
		center + Vector3.new(36, 1, -56),
		center + Vector3.new(30, 2, -72),
		center + Vector3.new(44, 3, -84),
		center + Vector3.new(64, 2, -88), -- clear of the travel pads
		center + Vector3.new(72, 0, -97), -- lands at the stargazing circle
	}
	for i = 1, #hops - 1 do
		local at = hops[i]
		local nxt = hops[i + 1]
		local stem = part({
			Name = "HopStem", Size = Vector3.new(1.6, 2.4 + at.Y, 1.6),
			Color = Color3.fromRGB(236, 228, 244), CanCollide = true, CanQuery = true,
		})
		stem.Position = Vector3.new(at.X, (2.4 + at.Y) / 2, at.Z)
		stem.Parent = model
		local capSize = Vector3.new(6, 2.2, 6)
		local cap = part({
			Name = "HopCap", Shape = Enum.PartType.Ball, Size = capSize,
			Color = capColors[((i - 1) % #capColors) + 1], Material = Enum.Material.Neon,
			Transparency = 0.1, CanCollide = true, CanQuery = true,
		})
		cap.Position = Vector3.new(at.X, 2.4 + at.Y + 0.8, at.Z)
		cap.Parent = model
		local glow = Instance.new("PointLight")
		glow.Color = cap.Color
		glow.Brightness = 1.2
		glow.Range = 12
		glow.Parent = cap

		-- each cap boings you TOWARD the next one (missing just lands you on
		-- soft grass — walk back on, no fail state)
		local dir = Vector3.new(nxt.X - at.X, 0, nxt.Z - at.Z)
		local flat = dir.Magnitude > 0.01 and dir.Unit or Vector3.zAxis
		makeBouncy(cap, flat * 24 + Vector3.new(0, 62 + (nxt.Y - at.Y) * 6, 0), function()
			squash(cap, capSize)
			sparkleBurst(cap, cap.Color, 8)
		end)
	end
end

function PlaygroundService.init()
	task.spawn(buildPuddingPlunge)
	task.spawn(buildBounceBog)
	task.spawn(buildSwingRows)
	task.spawn(buildSpoonSeesaw)
	task.spawn(buildMushroomHops)
end

return PlaygroundService
