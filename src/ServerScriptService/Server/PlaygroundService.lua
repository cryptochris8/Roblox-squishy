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
local SoundConfig = require(Shared:WaitForChild("SoundConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Players = game:GetService("Players")
local PlayerDataService = require(script.Parent.PlayerDataService)

-- set in init() (remotes exist by then); reused by the Bounce Bog toast + Picnic
local toastEvent: RemoteEvent

local PlaygroundService = {}

-- a one-shot 3D sound at a part (server-side, so everyone nearby hears it)
local function playAt(at: BasePart, soundId: string, volume: number, speed: number?)
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume
	s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = 90
	s.Parent = at
	s:Play()
	task.delay(6, function()
		s:Destroy()
	end)
end

local CREAM = Color3.fromRGB(255, 250, 240)
local CARAMEL = Color3.fromRGB(240, 196, 138)

-- Race tunables (WO-2.5). RACE_COINS is a new coin SOURCE — capped + cooldowned.
local RACE_SOLO_GRACE = 2.5
local RACE_COINS = 20
local RACE_COIN_COOLDOWN = 25
local RACE_COUNTDOWN_HOLD = 0.7
local RACE_PHOTO_GAP = 1.5

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
	local chutes = {}
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

		-- record this chute; the shared race controller (after the loop) drives the ride
		chutes[#chutes + 1] = { spec = spec, seat = seat, ring = ring, samples = samples, pool = pool, poolAt = poolAt, topCF = topCF, parkAtTop = parkAtTop }
	end

	-- ── Race controller (WO-2.5) ──────────────────────────────────────────────
	-- Both rings occupied -> a 3-2-1 race; a lone rider auto-slides solo after a
	-- short grace. Coins are ALWAYS equal; the titles are pure flavour (shuffled,
	-- so the 6yo wins a fun one ~half the time). No loser, ever.
	local lastRaceAward: { [number]: number } = {}
	local AWARD_TITLES = { "Fastest Splash", "Bounciest Splash", "Sparkliest Style" }
	local function awardRider(rider, title: string)
		local char = rider and rider.Parent
		local player = char and Players:GetPlayerFromCharacter(char)
		if not player then
			return
		end
		local now = os.clock()
		local pay = RACE_COINS
		if now - (lastRaceAward[player.UserId] or 0) < RACE_COIN_COOLDOWN then
			pay = 0
		else
			lastRaceAward[player.UserId] = now
		end
		if pay > 0 then
			PlayerDataService.addCoins(player, pay)
			PlayerDataService.sync(player)
		end
		toastEvent:FireClient(player, "🏁 " .. title .. (pay > 0 and (" +" .. pay .. " Sparkle Coins!") or "!"), "celebration")
	end
	local function descend(chute)
		local seat, samples, ring, pool, spec = chute.seat, chute.samples, chute.ring, chute.pool, chute.spec
		local dist, speed = 0, 8
		local accel = 24 + math.random() * 4 -- a hair of variance so mirrored slides don't always tie
		local cap = 28 + math.random() * 4
		local idx = 1
		while idx < #samples - 1 and seat.Occupant ~= nil do
			local dt = task.wait()
			speed = math.min(speed + accel * dt, cap)
			dist += speed * dt
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
		sparkleBurst(pool, spec.color, 18)
		playAt(pool, SoundConfig.Splash, 0.55)
		return os.clock(), seat.Occupant
	end
	local function hopOut(chute, rider)
		if not rider then
			return
		end
		rider.Sit = false
		local t0 = os.clock()
		while rider:GetState() == Enum.HumanoidStateType.Seated and os.clock() - t0 < 1 do
			task.wait(0.05)
		end
		local char = rider.Parent
		if char then
			(char :: Model):PivotTo(CFrame.new(chute.poolAt + Vector3.new(0, 4, -4)))
		end
	end
	local function bothIn(): boolean
		return chutes[1].seat.Occupant ~= nil and chutes[2].seat.Occupant ~= nil
	end
	local raceBusy = false
	local soloToken = 0
	local function runSolo(chute)
		task.wait(0.5)
		local _, rider = descend(chute)
		awardRider(rider, "Sparkly Splash")
		hopOut(chute, rider)
		task.wait(0.4)
		chute.parkAtTop()
	end
	local function runRace()
		if not countdownOn(deck, 10, { "3", "2", "1", "SPLASH!" }, RACE_COUNTDOWN_HOLD, bothIn) then
			-- a rider hopped off mid-countdown: just slide whoever is still in (no loser copy)
			for _, c in ipairs(chutes) do
				if c.seat.Occupant then
					local _, r = descend(c)
					awardRider(r, "Sparkly Splash")
					hopOut(c, r)
					task.wait(0.4)
					c.parkAtTop()
				end
			end
			return
		end
		local res = {}
		local done = 0
		for i, c in ipairs(chutes) do
			task.spawn(function()
				local f, r = descend(c)
				res[i] = { finish = f, rider = r, chute = c }
				done += 1
			end)
		end
		local deadline = os.clock() + 12
		while done < 2 and os.clock() < deadline do
			task.wait(0.05)
		end
		local fin = {}
		for _, r in ipairs(res) do
			if r.rider then
				fin[#fin + 1] = r
			end
		end
		if #fin == 2 and math.abs(fin[1].finish - fin[2].finish) <= RACE_PHOTO_GAP then
			for _, f in ipairs(fin) do
				awardRider(f.rider, "📸 Photo finish!")
				sparkleBurst(f.chute.pool, f.chute.spec.color, 34)
			end
		else
			local titles = { AWARD_TITLES[1], AWARD_TITLES[2], AWARD_TITLES[3] }
			for i = #titles, 2, -1 do
				local j = math.random(1, i)
				titles[i], titles[j] = titles[j], titles[i]
			end
			for i, f in ipairs(fin) do
				awardRider(f.rider, titles[i] or "Sparkly Splash")
			end
		end
		for _, r in ipairs(res) do
			hopOut(r.chute, r.rider)
		end
		task.wait(0.4)
		for _, c in ipairs(chutes) do
			c.parkAtTop()
		end
	end
	local function onSit(which: number)
		local chute = chutes[which]
		if raceBusy or not chute.seat.Occupant then
			return
		end
		if bothIn() then
			raceBusy = true
			soloToken += 1
			task.spawn(function()
				runRace()
				raceBusy = false
			end)
		else
			soloToken += 1
			local tok = soloToken
			task.spawn(function()
				task.wait(RACE_SOLO_GRACE)
				if raceBusy or soloToken ~= tok then
					return
				end
				if chute.seat.Occupant and not chutes[3 - which].seat.Occupant then
					raceBusy = true
					runSolo(chute)
					raceBusy = false
				end
			end)
		end
	end
	chutes[1].seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		onSit(1)
	end)
	chutes[2].seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		onSit(2)
	end)
end

-- ═════════════════════════════════════════════════════════════════════════════
-- THE BOUNCE BOG — a giant jelly trampoline (Goo Coast, southern dunes)
-- ═════════════════════════════════════════════════════════════════════════════
-- A shared 3-2-1 countdown billboard on a part; aborts (returns false) if stillOk
-- goes false partway (a rider/kid wandered off) — no failure copy, ever.
local function countdownOn(onPart: BasePart, offsetY: number, steps: { string }, hold: number, stillOk: (() -> boolean)?): boolean
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 90)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Parent = onPart
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextSize = 54
	lbl.TextColor3 = Color3.fromRGB(255, 210, 120)
	lbl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.2
	lbl.Parent = gui
	for _, n in ipairs(steps) do
		if stillOk and not stillOk() then
			gui:Destroy()
			return false
		end
		lbl.Text = n
		task.wait(hold)
	end
	gui:Destroy()
	return true
end

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
	-- WO-2.6: the together-bonus already works (PartyUntil below) but was invisible.
	-- A why-sign, plus a gold glow + "SUPER BOUNCE!" banner while the window is open.
	local tip = Instance.new("BillboardGui")
	tip.Size = UDim2.fromOffset(260, 40)
	tip.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	tip.AlwaysOnTop = true
	tip.MaxDistance = 80
	tip.Parent = rim
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Font = Enum.Font.FredokaOne
	tl.TextSize = 18
	tl.TextColor3 = Color3.fromRGB(90, 150, 180)
	tl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	tl.TextStrokeTransparency = 0.25
	tl.Text = "Bounce TOGETHER for a SUPER bounce!"
	tl.Parent = tip

	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 224, 140)
	glow.Brightness = 0
	glow.Range = 26
	glow.Enabled = false
	glow.Parent = drum
	local superGui = Instance.new("BillboardGui")
	superGui.Size = UDim2.fromOffset(230, 70)
	superGui.StudsOffsetWorldSpace = Vector3.new(0, 11, 0)
	superGui.AlwaysOnTop = true
	superGui.MaxDistance = 110
	superGui.Enabled = false
	superGui.Parent = drum
	local sl = Instance.new("TextLabel")
	sl.BackgroundTransparency = 1
	sl.Size = UDim2.fromScale(1, 1)
	sl.Font = Enum.Font.FredokaOne
	sl.TextSize = 40
	sl.TextColor3 = Color3.fromRGB(255, 210, 120)
	sl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	sl.TextStrokeTransparency = 0.15
	sl.Text = "SUPER BOUNCE!"
	sl.Parent = superGui
	local partyToken = 0
	local function showSuper(untilTime: number)
		-- latest party window wins, so overlapping bounces never flicker it off early
		partyToken += 1
		local tok = partyToken
		glow.Enabled = true
		glow.Brightness = 4
		superGui.Enabled = true
		task.delay(math.max(0, untilTime - workspace:GetServerTimeNow()), function()
			if partyToken == tok then
				glow.Enabled = false
				glow.Brightness = 0
				superGui.Enabled = false
			end
		end)
	end
	local superSeen: { [number]: boolean } = {} -- one gentle intro toast per player/session

	-- normal bounce ~17 studs; the together-bonus (~26) opens for everyone when
	-- two friends bounce within the same beat (published via PartyUntil)
	drum:SetAttribute("PartyVelocity", Vector3.new(0, 102, 0))
	makeBouncy(drum, Vector3.new(0, 82, 0), function(char)
		squash(drum, drumSize)
		playAt(drum, SoundConfig.Boing, 0.5, 0.95 + math.random() * 0.15)
		local now = os.clock()
		table.insert(recentBounces, now)
		for i = #recentBounces, 1, -1 do
			if now - recentBounces[i] > 0.6 then
				table.remove(recentBounces, i)
			end
		end
		if #recentBounces >= 2 then
			local untilTime = workspace:GetServerTimeNow() + 4
			drum:SetAttribute("PartyUntil", untilTime)
			sparkleBurst(drum, Color3.fromRGB(255, 226, 150), 26)
			showSuper(untilTime)
			local player = char and Players:GetPlayerFromCharacter(char)
			if player and not superSeen[player.UserId] then
				superSeen[player.UserId] = true
				toastEvent:FireClient(player, "✨ SUPER BOUNCE! Bounce together for an even bigger boing! 🌈", "celebration")
			end
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
			-- the pitch rises cap by cap up the trail (the delight is in the scale)
			playAt(cap, SoundConfig.Boing, 0.45, 0.9 + i * 0.08)
		end)
	end
end

-- ═════════════════════════════════════════════════════════════════════════════
-- THE SPARKLE-POP CANNON — climb in, 3-2-1, FLY over the goo sea (Goo Coast)
-- ═════════════════════════════════════════════════════════════════════════════
local function buildSparklePopCannon()
	local zone = ZoneConfig.get("Goo Coast")
	if not zone then return end
	local center = zone.center

	local model = atomicModel("SparklePopCannon", Workspace)
	local at = center + Vector3.new(14, 0, 2) -- beside the pier's base
	local aimAt = center + Vector3.new(-40, 0, -90) -- splash down in open sea
	local flat = Vector3.new(aimAt.X - at.X, 0, aimAt.Z - at.Z)
	local dir = flat.Unit
	local face = CFrame.lookAt(Vector3.new(at.X, 0, at.Z), Vector3.new(aimAt.X, 0, aimAt.Z))

	-- base + tilted barrel
	local pedestal = part({
		Name = "CannonBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 9, 9),
		Color = Color3.fromRGB(150, 220, 224), CanCollide = true, CanQuery = true,
	})
	pedestal.CFrame = CFrame.new(at + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pedestal.Parent = model
	local barrel = part({
		Name = "CannonBarrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, 5.4, 5.4),
		Color = Color3.fromRGB(255, 190, 200), CanCollide = true, CanQuery = true,
	})
	barrel.CFrame = face * CFrame.new(0, 4.6, -1.6) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(40))
	barrel.Parent = model
	local rim = part({
		Name = "CannonRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 6.2, 6.2),
		Color = CREAM,
	})
	rim.CFrame = barrel.CFrame * CFrame.new(4.6, 0, 0)
	rim.Parent = model
	floatingSign(barrel, "🎉 Sparkle-Pop Cannon")

	-- the loading seat, tucked inside the barrel mouth
	local seat = Instance.new("Seat")
	seat.Name = "CannonSeat"
	seat.Size = Vector3.new(2.4, 0.4, 2.4)
	seat.Color = CREAM
	seat.Material = Enum.Material.SmoothPlastic
	seat.Anchored = true
	seat.CanQuery = true
	seat.CFrame = barrel.CFrame * CFrame.new(1.2, 0, 0) * CFrame.Angles(0, 0, math.rad(-40)) * CFrame.Angles(0, math.rad(-90), 0)
	seat.Parent = model

	-- floating bullseye rafts where the arc lands (visual targets, pure delight)
	for i, ringSpec in ipairs({ { 10, Color3.fromRGB(255, 170, 195) }, { 6.4, CREAM }, { 3, Color3.fromRGB(255, 210, 120) } }) do
		local ring = part({
			Name = "Bullseye" .. i, Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.4 + i * 0.1, ringSpec[1], ringSpec[1]),
			Color = ringSpec[2],
		})
		ring.CFrame = CFrame.new(aimAt + Vector3.new(0, 0.5 + i * 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = model
	end

	-- countdown sign above the barrel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 70
	gui.Parent = rim
	local count = Instance.new("TextLabel")
	count.BackgroundTransparency = 1
	count.Size = UDim2.fromScale(1, 1)
	count.Font = Enum.Font.FredokaOne
	count.TextSize = 44
	count.TextColor3 = Color3.fromRGB(255, 210, 120)
	count.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	count.TextStrokeTransparency = 0.2
	count.Text = ""
	count.Parent = gui

	-- the flight: the rider STAYS SEATED and the seat itself is flown along a
	-- big sparkle parabola to the bullseye (the same engine-trusted carry that
	-- runs the coaster — nothing to ragdoll, clip, or fizzle), then they're
	-- set down on the rafts and the seat zips home for the next astronaut
	local seatHome = seat.CFrame
	local mouth = rim.Position + Vector3.new(0, 2, 0)
	local landAt = aimAt + Vector3.new(0, 2.4, 0)
	local firing = false
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		if not occupant or firing then
			return
		end
		firing = true
		task.spawn(function()
			for _, n in ipairs({ "3", "2", "1", "POP!" }) do
				count.Text = n
				task.wait(0.8)
				if seat.Occupant ~= occupant then -- they hopped out; stand down
					count.Text = ""
					firing = false
					return
				end
			end
			count.Text = ""
			sparkleBurst(rim, Color3.fromRGB(255, 226, 150), 30)
			squash(barrel, barrel.Size)
			playAt(rim, SoundConfig.Pop, 0.65, 0.9)
			-- sparkle contrail on the flyer
			local char = occupant.Parent :: Model?
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local trail
			if root then
				trail = Instance.new("ParticleEmitter")
				trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				trail.LightEmission = 0.9
				trail.Color = ColorSequence.new(Color3.fromRGB(255, 226, 150), Color3.fromRGB(255, 190, 200))
				trail.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0),
				})
				trail.Lifetime = NumberRange.new(0.6, 1)
				trail.Rate = 40
				trail.Speed = NumberRange.new(1, 2)
				trail.Parent = root
			end
			-- fly the seat (and its welded rider) along the parabola: ~1.5s,
			-- apex ~22 studs over the midpoint
			local FLIGHT = 1.5
			local APEX = 22
			local t = 0
			while t < FLIGHT do
				local dt = task.wait()
				t = math.min(t + dt, FLIGHT)
				local k = t / FLIGHT
				local pos = mouth:Lerp(landAt, k) + Vector3.new(0, APEX * 4 * k * (1 - k), 0)
				local aheadK = math.min(k + 0.06, 1)
				local ahead = mouth:Lerp(landAt, aheadK) + Vector3.new(0, APEX * 4 * aheadK * (1 - aheadK), 0)
				seat.CFrame = if (ahead - pos).Magnitude > 0.05
					then CFrame.lookAt(pos, ahead, Vector3.yAxis)
					else CFrame.new(pos)
				if not seat.Occupant then
					break -- bailed mid-air: they're over soft goo, let them drop
				end
			end
			if trail then
				task.delay(1, function()
					trail:Destroy()
				end)
			end
			-- set the rider down on the bullseye
			local rider = seat.Occupant
			if rider then
				rider.Sit = false
				local t0 = os.clock()
				while rider:GetState() == Enum.HumanoidStateType.Seated and os.clock() - t0 < 1 do
					task.wait(0.05)
				end
				local rchar = rider.Parent :: Model?
				if rchar and rchar.Parent then
					rchar:PivotTo(CFrame.new(landAt + Vector3.new(0, 2, 0)))
				end
				local bullseye = model:FindFirstChild("Bullseye1") :: BasePart?
				if bullseye then
					playAt(bullseye, SoundConfig.Splash, 0.6)
				end
				sparkleBurst(rim, Color3.fromRGB(255, 190, 200), 8)
			end
			-- the seat zips home
			task.wait(0.4)
			seat.CFrame = seatHome
			task.wait(0.8)
			firing = false
		end)
	end)
end

-- ═════════════════════════════════════════════════════════════════════════════
-- THE PUDDING-CUP SPINNER — teacups with a kid-worked speed lever (Pudding)
-- ═════════════════════════════════════════════════════════════════════════════
local function buildPuddingCupSpinner()
	local zone = ZoneConfig.get("Pudding Hills")
	if not zone then return end
	local center = zone.center
	local model = atomicModel("PuddingCupSpinner", Workspace)
	local at = center + Vector3.new(36, 0, 16)

	local tray = part({
		Name = "SpinnerTray", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 22, 22),
		Color = Color3.fromRGB(255, 214, 150), CanCollide = true, CanQuery = true,
	})
	tray.CFrame = CFrame.new(at + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	tray.Parent = model
	local hubPost = part({
		Name = "SpinnerHub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 2.4, 2.4),
		Color = CREAM, CanCollide = true, CanQuery = true,
	})
	hubPost.CFrame = CFrame.new(at + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	hubPost.Parent = model
	floatingSign(hubPost, "🍵 Pudding-Cup Spinner")

	local cupColors = { Color3.fromRGB(255, 170, 195), Color3.fromRGB(170, 200, 255), Color3.fromRGB(180, 230, 200) }
	local cups = {}
	for i = 1, 3 do
		local cup = Instance.new("Model")
		cup.Name = "Cup" .. i
		local body = part({
			Name = "CupBody", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 6.4, 6.4),
			Color = cupColors[i], CanCollide = true, CanQuery = true,
		})
		body.CFrame = CFrame.new(at) -- placed by the spin loop
		body.Parent = cup
		cup.PrimaryPart = body
		local handleArc = part({
			Name = "CupHandle", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 1, 0.8),
			Color = cupColors[i],
		})
		handleArc.CFrame = body.CFrame * CFrame.new(0, 0, 3.6)
		handleArc.Parent = cup
		local seats = {}
		for si, ang in ipairs({ 0, math.pi }) do
			local s = Instance.new("Seat")
			s.Name = "CupSeat" .. si
			s.Size = Vector3.new(2, 0.4, 2)
			s.Color = CREAM
			s.Material = Enum.Material.SmoothPlastic
			s.Anchored = true
			s.CanQuery = true
			s.CFrame = body.CFrame * CFrame.new(math.cos(ang) * 1.4, 2, math.sin(ang) * 1.4)
			s.Parent = cup
			seats[si] = s
		end
		cup.Parent = model
		cups[i] = cup
	end

	-- the lever: a kid cycles speed 0 → 1 → 2 → 3 → 0 (one drives, sisters ride)
	local leverPost = part({
		Name = "LeverPost", Size = Vector3.new(0.8, 3.4, 0.8),
		Color = Color3.fromRGB(206, 170, 120), CanCollide = true, CanQuery = true,
	})
	leverPost.Position = at + Vector3.new(13.5, 1.7, 0)
	leverPost.Parent = model
	local leverBall = part({
		Name = "LeverBall", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4),
		Color = Color3.fromRGB(214, 40, 70),
	})
	leverBall.Position = at + Vector3.new(13.5, 3.8, 0)
	leverBall.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Spinner Lever"
	prompt.ActionText = "Spin faster!"
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = leverPost

	local SPEEDS = { 0, 0.35, 0.7, 1.1 } -- tray rad/s (rim <= ~12 studs/s)
	local level = 2
	prompt.Triggered:Connect(function()
		level = (level % #SPEEDS) + 1
		prompt.ActionText = if SPEEDS[level] == 0 then "Start it up!" else "Spin faster!"
		sparkleBurst(leverBall, Color3.fromRGB(255, 210, 120), 6)
	end)

	task.spawn(function()
		local trayA = 0
		local cupA = 0
		local speed = SPEEDS[level]
		RunService.Heartbeat:Connect(function(dt)
			speed += (SPEEDS[level] - speed) * math.min(1, dt * 1.2) -- soft ramps
			trayA = (trayA + speed * dt) % (math.pi * 2)
			cupA = (cupA + speed * 1.6 * dt) % (math.pi * 2)
			for i, cup in ipairs(cups) do
				local a = trayA + (i / 3) * math.pi * 2
				local cupCF = CFrame.new(at + Vector3.new(math.cos(a) * 6.5, 1.4, math.sin(a) * 6.5))
					* CFrame.Angles(0, -cupA, 0)
				cup:PivotTo(cupCF)
			end
		end)
	end)
end

-- ═════════════════════════════════════════════════════════════════════════════
-- THE FIREFLY ZIP LINE — grove deck across the moonpool to the stargazers
-- ═════════════════════════════════════════════════════════════════════════════
local function buildFireflyZipLine()
	local zone = ZoneConfig.get("Moonlit Hollow")
	if not zone then return end
	local center = zone.center
	local model = atomicModel("FireflyZipLine", Workspace)

	local startAt = center + Vector3.new(-50, 16, 8)
	local endAt = center + Vector3.new(68, 2.4, -99)
	local waypoints = {
		startAt,
		center + Vector3.new(-10, 9, -30),
		center + Vector3.new(35, 5, -70),
		endAt,
	}
	local samples = sampleOpenSpline(waypoints)

	-- the boarding tower: a giant zip-mushroom with wrap steps + deck
	local stem = part({
		Name = "ZipStem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(15, 5, 5),
		Color = Color3.fromRGB(236, 228, 244), CanCollide = true, CanQuery = true,
	})
	stem.CFrame = CFrame.new(startAt + Vector3.new(0, -8.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	stem.Parent = model
	local capTop = part({
		Name = "ZipCap", Shape = Enum.PartType.Ball, Size = Vector3.new(13, 6, 13),
		Color = Color3.fromRGB(190, 130, 255), Material = Enum.Material.Neon, Transparency = 0.1,
		CanCollide = true, CanQuery = true,
	})
	capTop.Position = startAt + Vector3.new(0, -1.4, 0)
	capTop.Parent = model
	for s = 0, 9 do
		local a = math.rad(s * 52)
		local step = part({
			Name = "ZipStep", Size = Vector3.new(3.4, 0.5, 2),
			Color = (s % 2 == 0) and Color3.fromRGB(236, 228, 244) or Color3.fromRGB(186, 164, 230),
			CanCollide = true, CanQuery = true,
		})
		step.CFrame = CFrame.new(startAt + Vector3.new(math.cos(a) * 4.6, -14.4 + s * 1.5, math.sin(a) * 4.6))
			* CFrame.Angles(0, -a, 0)
		step.Parent = model
	end
	floatingSign(capTop, "🪰 Firefly Zip Line")

	-- the sagging cable
	for i = 1, #samples - 4, 4 do
		local a, b = samples[i], samples[i + 4]
		local cable = part({
			Name = "ZipCable", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new((b - a).Magnitude + 0.2, 0.22, 0.22),
			Color = Color3.fromRGB(186, 164, 230), Material = Enum.Material.Neon, Transparency = 0.25,
		})
		cable.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
		cable.Parent = model
	end
	-- the landing pad
	local pad = part({
		Name = "ZipLanding", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 9, 9),
		Color = Color3.fromRGB(186, 164, 230), Material = Enum.Material.Neon, Transparency = 0.5,
		CanCollide = true, CanQuery = true,
	})
	pad.CFrame = CFrame.new(endAt + Vector3.new(0, -1.9, 2)) * CFrame.Angles(0, 0, math.rad(90))
	pad.Parent = model

	-- the lantern trolley
	local trolley = Instance.new("Model")
	trolley.Name = "ZipTrolley"
	local lantern = part({
		Name = "TrolleyLantern", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2.4, 2),
		Color = Color3.fromRGB(255, 226, 150), Material = Enum.Material.Neon,
	})
	lantern.Parent = trolley
	trolley.PrimaryPart = lantern
	local ropeDown = part({
		Name = "TrolleyRope", Size = Vector3.new(0.2, 3.4, 0.2),
		Color = Color3.fromRGB(236, 228, 244),
	})
	ropeDown.Parent = trolley
	local seat = Instance.new("Seat")
	seat.Name = "ZipSeat"
	seat.Size = Vector3.new(2.2, 0.4, 1.8)
	seat.Color = CREAM
	seat.Material = Enum.Material.SmoothPlastic
	seat.Anchored = true
	seat.CanQuery = true
	seat.Parent = trolley
	local flies = Instance.new("ParticleEmitter")
	flies.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	flies.LightEmission = 1
	flies.Color = ColorSequence.new(Color3.fromRGB(200, 170, 255), Color3.fromRGB(170, 230, 255))
	flies.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0),
	})
	flies.Lifetime = NumberRange.new(1, 1.8)
	flies.Rate = 0
	flies.Speed = NumberRange.new(0.5, 1.5)
	flies.SpreadAngle = Vector2.new(180, 180)
	flies.Parent = lantern
	trolley.Parent = model

	local function placeTrolley(idx: number)
		local pos = samples[math.min(idx, #samples - 1)]
		local nxt = samples[math.min(idx + 1, #samples)]
		local cf = CFrame.lookAt(pos, nxt, Vector3.yAxis)
		lantern.CFrame = cf
		ropeDown.CFrame = cf * CFrame.new(0, -2.4, 0)
		seat.CFrame = cf * CFrame.new(0, -4.2, 0)
	end
	placeTrolley(1)

	local riding = false
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		if not occupant or riding then
			return
		end
		riding = true
		flies.Rate = 22
		playAt(lantern, SoundConfig.Whoosh, 0.5)
		task.spawn(function()
			task.wait(0.4)
			-- glide down the samples at ~20 studs/s
			local dist = 0
			local idx = 1
			while idx < #samples - 1 do
				local dt = task.wait()
				dist += 20 * dt
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
				placeTrolley(idx)
				if not seat.Occupant then
					break -- they bailed; no damage, soft grass below
				end
			end
			-- arrive: set the rider down by the stargazing circle
			local rider = seat.Occupant
			if rider then
				rider.Sit = false
				local t0 = os.clock()
				while rider:GetState() == Enum.HumanoidStateType.Seated and os.clock() - t0 < 1 do
					task.wait(0.05)
				end
				local char = rider.Parent :: Model?
				if char and char.Parent then
					char:PivotTo(CFrame.new(endAt + Vector3.new(0, 2, 4)))
				end
				sparkleBurst(pad, Color3.fromRGB(200, 170, 255), 14)
			end
			flies.Rate = 0
			-- the empty lantern drifts back up at double speed
			task.wait(0.6)
			for i = #samples - 1, 1, -8 do
				placeTrolley(i)
				task.wait(0.05)
			end
			placeTrolley(1)
			riding = false
		end)
	end)

	-- Ground-level boarding (kid-friendly): walk to the tower foot + hold E, no
	-- climbing the spiral. Seats you on the trolley when it's parked + free —
	-- the same one-button pattern as the Lazy Goo River dock.
	local boardPad = part({
		Name = "ZipBoardPad", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 9, 9),
		Color = Color3.fromRGB(186, 164, 230), Material = Enum.Material.Neon, Transparency = 0.45,
		CanCollide = false, CanQuery = true,
	})
	boardPad.CFrame = CFrame.new(Vector3.new(startAt.X, center.Y + 0.4, startAt.Z + 9)) * CFrame.Angles(0, 0, math.rad(90))
	boardPad.Parent = model
	local boardSign = Instance.new("BillboardGui")
	boardSign.Size = UDim2.fromOffset(190, 38)
	boardSign.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	boardSign.AlwaysOnTop = true
	boardSign.MaxDistance = 70
	boardSign.Parent = boardPad
	local boardLbl = Instance.new("TextLabel")
	boardLbl.BackgroundTransparency = 1
	boardLbl.Size = UDim2.fromScale(1, 1)
	boardLbl.Font = Enum.Font.FredokaOne
	boardLbl.TextSize = 18
	boardLbl.TextColor3 = Color3.fromRGB(170, 140, 230)
	boardLbl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	boardLbl.TextStrokeTransparency = 0.2
	boardLbl.Text = "🪰 Ride the Zip Line!"
	boardLbl.Parent = boardSign
	local boardPrompt = Instance.new("ProximityPrompt")
	boardPrompt.ObjectText = "Firefly Zip Line"
	boardPrompt.ActionText = "Ride it!"
	boardPrompt.HoldDuration = 0.2
	boardPrompt.MaxActivationDistance = 14
	boardPrompt.RequiresLineOfSight = false
	boardPrompt.Parent = boardPad
	boardPrompt.Triggered:Connect(function(player)
		if riding or seat.Occupant then
			return
		end
		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Sit then
			return
		end
		char:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
		task.wait(0.1)
		seat:Sit(humanoid)
	end)
end

-- ═════════════════════════════════════════════════════════════════════════════
-- THE LAZY GOO RIVER — a drifting convoy of jelly rings (Goo Coast, east bay)
-- ═════════════════════════════════════════════════════════════════════════════
local function buildLazyGooRiver()
	local zone = ZoneConfig.get("Goo Coast")
	if not zone then return end
	local center = zone.center
	local model = atomicModel("LazyGooRiver", Workspace)

	-- a closed loop east of the pier, clear of the rope swing
	local waypoints = {
		center + Vector3.new(20, 1.6, -15),
		center + Vector3.new(58, 1.6, -25),
		center + Vector3.new(76, 1.6, -55),
		center + Vector3.new(60, 1.6, -85),
		center + Vector3.new(28, 1.6, -88),
		center + Vector3.new(18, 1.6, -52),
	}
	-- closed-loop samples: run the open-spline helper around the wrap, then
	-- trim the duplicated final segment so dist % total wraps seamlessly back
	-- to the first sample (no teleport seam)
	local looped = {}
	for i = 1, #waypoints do
		looped[i] = waypoints[i]
	end
	looped[#looped + 1] = waypoints[1]
	looped[#looped + 1] = waypoints[2]
	local samples = sampleOpenSpline(looped)
	local keep = #waypoints * 16 + 1 -- one sample run per real segment, ending back at waypoint 1
	while #samples > keep do
		table.remove(samples)
	end

	-- glowing current markers so the loop reads from the shore
	for i = 1, #samples, 12 do
		local glow = part({
			Name = "CurrentGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 2.4, 2.4),
			Color = Color3.fromRGB(170, 240, 230), Material = Enum.Material.Neon, Transparency = 0.55,
		})
		glow.CFrame = CFrame.new(samples[i] + Vector3.new(0, -0.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
		glow.Parent = model
	end

	-- the boarding dock
	local dock = part({
		Name = "RiverDock", Size = Vector3.new(8, 1, 6),
		Color = Color3.fromRGB(206, 170, 120), CanCollide = true, CanQuery = true,
	})
	dock.Position = center + Vector3.new(22, 0.9, -10)
	dock.Parent = model
	floatingSign(dock, "🛟 Lazy Goo River")
	local dockPrompt = Instance.new("ProximityPrompt")
	dockPrompt.ObjectText = "Lazy Goo River"
	dockPrompt.ActionText = "Hop in a ring"
	dockPrompt.HoldDuration = 0.15
	dockPrompt.MaxActivationDistance = 12
	dockPrompt.RequiresLineOfSight = false
	dockPrompt.Parent = dock

	-- six drifting rings, evenly spaced around the loop
	local ringColors = { Color3.fromRGB(255, 190, 200), Color3.fromRGB(150, 220, 224), Color3.fromRGB(255, 226, 150) }
	local totalLen = 0
	for i = 2, #samples do
		totalLen += (samples[i] - samples[i - 1]).Magnitude
	end
	local rings = {}
	for r = 1, 6 do
		local ring = Instance.new("Model")
		ring.Name = "RiverRing" .. r
		local tube = part({
			Name = "Tube", Shape = Enum.PartType.Ball, Size = Vector3.new(4.2, 1.6, 4.2),
			Color = ringColors[((r - 1) % #ringColors) + 1], Material = Enum.Material.Glass, Transparency = 0.2,
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
		ring.Parent = model
		rings[r] = { model = ring, seat = seat, dist = totalLen * (r - 1) / 6, spin = r * 1.1 }
	end

	local function posAt(s: number): (Vector3, Vector3)
		s = s % totalLen
		local walked = 0
		for i = 2, #samples do
			local seg = (samples[i] - samples[i - 1]).Magnitude
			if walked + seg >= s then
				local t = (s - walked) / seg
				return samples[i - 1]:Lerp(samples[i], t), samples[i]
			end
			walked += seg
		end
		return samples[1], samples[2]
	end

	task.spawn(function()
		local t = 0
		RunService.Heartbeat:Connect(function(dt)
			t += dt
			for _, ring in ipairs(rings) do
				ring.dist = (ring.dist + 5 * dt) % totalLen
				local pos, ahead = posAt(ring.dist)
				ring.spin += dt * 0.3
				local bob = math.sin(t * 1.8 + ring.spin * 4) * 0.25
				local cf = CFrame.lookAt(pos + Vector3.new(0, bob, 0), ahead + Vector3.new(0, bob, 0), Vector3.yAxis)
					* CFrame.Angles(0, ring.spin, 0)
				ring.model:PivotTo(cf)
				ring.seat.CFrame = cf * CFrame.new(0, 0.6, 0)
			end
		end)
	end)

	-- the dock seats you in the nearest empty ring
	dockPrompt.Triggered:Connect(function(player)
		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Sit then
			return
		end
		local best, bestD = nil, math.huge
		for _, ring in ipairs(rings) do
			if ring.seat.Occupant == nil then
				local d = (ring.seat.Position - dock.Position).Magnitude
				if d < bestD then
					best, bestD = ring, d
				end
			end
		end
		if best then
			(char :: Model):PivotTo(best.seat.CFrame + Vector3.new(0, 3, 0))
			task.wait(0.1)
			best.seat:Sit(humanoid)
		end
	end)
end

-- ── WO-2.8 Friendship Picnic (per-land co-op pad circle) ─────────────────────
-- 2-4 kids STAND on a blanket -> gentle 3-2-1 -> confetti + EQUAL small coins.
-- Presence-based (no prompt), server-authoritative, no-loser.
local PICNIC_COINS = 15
local PICNIC_RADIUS = 9
local PICNIC_PLAYER_COOLDOWN = 90 -- re-standing pays 0 (a cozy toast) until this passes
local PICNIC_REARM = 18
local PICNIC_HOLD = 0.8

local function playersOnPad(center: Vector3, radius: number): { Player }
	local out = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local ch = pl.Character
		local root = ch and ch:FindFirstChild("HumanoidRootPart")
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local flat = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude
			if flat <= radius and math.abs(root.Position.Y - center.Y) < 8 then
				out[#out + 1] = pl
			end
		end
	end
	return out
end

local picnicRewardAt: { [number]: number } = {}
local function awardPicnic(pl: Player)
	local now = os.clock()
	local pay = PICNIC_COINS
	if now - (picnicRewardAt[pl.UserId] or 0) < PICNIC_PLAYER_COOLDOWN then
		pay = 0
	else
		picnicRewardAt[pl.UserId] = now
	end
	if pay > 0 then
		PlayerDataService.addCoins(pl, pay)
		PlayerDataService.sync(pl)
		toastEvent:FireClient(pl, "🧺 Friendship Picnic! +" .. pay .. " Sparkle Coins! 💖", "celebration")
	else
		toastEvent:FireClient(pl, "🧺 So cozy together! 💖", "celebration")
	end
end

local function buildFriendshipPicnic(zoneName: string, offset: Vector3, blanketColor: Color3)
	local zone = ZoneConfig.get(zoneName)
	if not zone then
		return
	end
	local center = zone.center + offset
	local model = atomicModel("FriendshipPicnic_" .. string.gsub(zoneName, " ", ""), Workspace)
	local blanket = part({
		Name = "PicnicBlanket", Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, PICNIC_RADIUS * 2, PICNIC_RADIUS * 2),
		Color = blanketColor, CanCollide = true, CanQuery = true,
	})
	blanket.CFrame = CFrame.new(center + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	blanket.Parent = model
	for i, deg in ipairs({ 0, 90, 180, 270 }) do
		local a = math.rad(deg)
		local cu = part({
			Name = "PicnicCushion" .. i, Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 1.3, 3), Color = Color3.fromRGB(255, 236, 205),
		})
		cu.Position = center + Vector3.new(math.cos(a) * 6, 0.9, math.sin(a) * 6)
		cu.Parent = model
	end
	local basket = part({
		Name = "PicnicBasket", Size = Vector3.new(3, 2.4, 3),
		Color = Color3.fromRGB(206, 150, 96), CanCollide = true, CanQuery = true,
	})
	basket.Position = center + Vector3.new(0, 1.5, 0)
	basket.Parent = model
	floatingSign(basket, "🧺 Friendship Picnic")

	local celebrating = false
	local lastAt = 0
	task.spawn(function()
		while true do
			task.wait(0.4)
			if not celebrating and os.clock() - lastAt >= PICNIC_REARM then
				if #playersOnPad(center, PICNIC_RADIUS) >= 2 then
					celebrating = true
					local ok = countdownOn(basket, 5, { "3", "2", "1" }, PICNIC_HOLD, function()
						return #playersOnPad(center, PICNIC_RADIUS) >= 2
					end)
					if ok then
						local present = playersOnPad(center, PICNIC_RADIUS)
						if #present >= 2 then
							sparkleBurst(blanket, Color3.fromRGB(255, 200, 120), 40)
							task.delay(0.06, function()
								sparkleBurst(blanket, Color3.fromRGB(150, 200, 255), 26)
							end)
							playAt(basket, SoundConfig.Pop, 0.5)
							for _, pl in ipairs(present) do
								awardPicnic(pl)
							end
						end
						lastAt = os.clock()
					end
					celebrating = false
				end
			end
		end
	end)
end

function PlaygroundService.init()
	toastEvent = Remotes.get(Remotes.Toast)
	task.spawn(buildPuddingPlunge)
	task.spawn(buildBounceBog)
	task.spawn(buildSwingRows)
	task.spawn(buildSpoonSeesaw)
	task.spawn(buildMushroomHops)
	-- Wave 2
	task.spawn(buildSparklePopCannon)
	task.spawn(buildPuddingCupSpinner)
	task.spawn(buildFireflyZipLine)
	task.spawn(buildLazyGooRiver)
	-- WO-2.8 Friendship Picnic, one per land (final post-spread offsets; eyeballed
	-- in Studio to sit in open meadow clear of pads/coaster/plunge)
	task.spawn(buildFriendshipPicnic, "Pudding Hills", Vector3.new(-80, 0, -40), Color3.fromRGB(255, 190, 200))
	task.spawn(buildFriendshipPicnic, "Goo Coast", Vector3.new(-90, 0, 40), Color3.fromRGB(160, 220, 220))
	task.spawn(buildFriendshipPicnic, "Moonlit Hollow", Vector3.new(-80, 0, -40), Color3.fromRGB(190, 160, 255))
end

return PlaygroundService
