--!strict
-- CoasterService (SERVER)
-- The Sparkle Express — a rideable scenic train circling Pudding Hills' rim.
-- Built the way the serious ride games do it: a CLOSED Catmull-Rom spline
-- through hand-laid waypoints, arc-length parameterized so the train glides
-- at constant speed, anchored cars CFramed every Heartbeat (never physics),
-- and native Seat welds carrying the riders. The caramel ribbon track, its
-- supports, the candy arches, and the station are all generated from the
-- same spline at startup.
--
-- Kid-gentle by the numbers: cruise 16 studs/s, accel 6, bank <= 10 degrees,
-- a 14s doors-open dwell, and a safe-exit rule — anyone who jumps (or falls)
-- off mid-ride is sparkle-poofed back to the station platform, never dropped.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CoasterConfig = require(Shared:WaitForChild("CoasterConfig"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SoundConfig = require(Shared:WaitForChild("SoundConfig"))
local RidePrefs = require(script.Parent.RidePrefs)

local CoasterService = {}

local toastEvent: RemoteEvent

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

-- ── the spline ───────────────────────────────────────────────────────────────
local function catmullRom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local a = 2 * p1
	local b = p2 - p0
	local c = 2 * p0 - 5 * p1 + 4 * p2 - p3
	local d = -p0 + 3 * p1 - 3 * p2 + p3
	return 0.5 * (a + b * t + c * (t * t) + d * (t * t * t))
end

-- Arc-length sample table for the CLOSED loop: ~2-stud spacing, so constant
-- speed and track generation both read from the same honest distances.
local samples: { { pos: Vector3, dist: number } } = {}
local totalLength = 0

local function buildSamples(center: Vector3)
	local wp = {}
	for i, p in ipairs(CoasterConfig.Waypoints) do
		wp[i] = center + p
	end
	local n = #wp
	local STEPS = 16
	local prev: Vector3? = nil
	for seg = 1, n do
		local p0 = wp[(seg - 2) % n + 1]
		local p1 = wp[(seg - 1) % n + 1]
		local p2 = wp[seg % n + 1]
		local p3 = wp[(seg + 1) % n + 1]
		for s = 0, STEPS - 1 do
			local pos = catmullRom(p0, p1, p2, p3, s / STEPS)
			if prev then
				totalLength += (pos - prev).Magnitude
			end
			table.insert(samples, { pos = pos, dist = totalLength })
			prev = pos
		end
	end
	-- close the loop distance back to the first sample
	totalLength += (samples[1].pos - prev :: Vector3).Magnitude
end

-- Position at arc length s (walks forward from a moving cursor — motion is
-- monotonic, so this is O(1) per frame in practice).
local cursor = 1
local function sampleAt(s: number): Vector3
	s = s % totalLength
	local n = #samples
	-- hop the cursor until s sits between cursor and cursor+1
	for _ = 1, n do
		local a = samples[cursor]
		local b = samples[cursor % n + 1]
		local bDist = if cursor == n then totalLength else b.dist
		if s >= a.dist and s <= bDist then
			local span = bDist - a.dist
			local t = if span > 0 then (s - a.dist) / span else 0
			return a.pos:Lerp(b.pos, t)
		end
		cursor = cursor % n + 1
	end
	return samples[1].pos
end

-- A stateless second lookup (for track building, where s jumps around).
local function sampleAtScan(s: number): Vector3
	s = s % totalLength
	local n = #samples
	for i = 1, n do
		local a = samples[i]
		local b = samples[i % n + 1]
		local bDist = if i == n then totalLength else b.dist
		if s >= a.dist and s <= bDist then
			local span = bDist - a.dist
			local t = if span > 0 then (s - a.dist) / span else 0
			return a.pos:Lerp(b.pos, t)
		end
	end
	return samples[1].pos
end

-- ── track + station build ────────────────────────────────────────────────────
local TRACK_COLOR = Color3.fromRGB(240, 196, 138) -- the caramel of the paths
local TRIM_COLOR = Color3.fromRGB(255, 250, 240)
local CAR_COLORS = {
	Color3.fromRGB(255, 170, 195), Color3.fromRGB(255, 210, 120), Color3.fromRGB(170, 200, 255),
}

local function buildTrack(folder: Folder)
	local s = 0
	local boardIndex = 0
	while s < totalLength do
		boardIndex += 1
		local a = sampleAtScan(s)
		local b = sampleAtScan(math.min(s + CoasterConfig.BoardSpacing, s + totalLength - 0.01))
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local board = part({
			Name = "RailBoard",
			Size = Vector3.new(4, 0.5, len + 0.4),
			Color = TRACK_COLOR,
		})
		board.CFrame = CFrame.lookAt(mid, b, Vector3.yAxis)
		board.Parent = folder
		-- a cream trim stripe every few boards keeps it toy-train cheerful
		if boardIndex % 4 == 0 then
			local trim = part({
				Name = "RailTrim",
				Size = Vector3.new(4.4, 0.55, 1.2),
				Color = TRIM_COLOR,
			})
			trim.CFrame = CFrame.lookAt(mid, b, Vector3.yAxis)
			trim.Parent = folder
		end
		s += CoasterConfig.BoardSpacing
	end

	-- supports down to the ground
	s = 0
	while s < totalLength do
		local at = sampleAtScan(s)
		local h = at.Y - 0.2
		if h > 2.5 then
			local post = part({
				Name = "SupportPost",
				Size = Vector3.new(1.1, h, 1.1),
				Color = TRIM_COLOR,
			})
			post.Position = Vector3.new(at.X, h / 2, at.Z)
			post.Parent = folder
			local foot = part({
				Name = "SupportFoot",
				Size = Vector3.new(2.4, 0.6, 2.4),
				Color = TRACK_COLOR,
			})
			foot.Position = Vector3.new(at.X, 0.3, at.Z)
			foot.Parent = folder
		end
		s += CoasterConfig.SupportSpacing
	end

	-- candy arches the train rushes under (passing beneath things = the fun)
	for _, archS in ipairs({ totalLength * 0.2, totalLength * 0.45, totalLength * 0.7, totalLength * 0.9 }) do
		local at = sampleAtScan(archS)
		local ahead = sampleAtScan(archS + 2)
		local cf = CFrame.lookAt(at, ahead, Vector3.yAxis)
		for _, sx in ipairs({ -1, 1 }) do
			local postH = at.Y + 8
			local post = part({
				Name = "ArchPost",
				Size = Vector3.new(1.2, postH, 1.2),
				Color = (sx < 0) and Color3.fromRGB(255, 150, 170) or TRIM_COLOR,
			})
			post.CFrame = cf * CFrame.new(sx * 4.4, 0, 0)
			post.Position = Vector3.new(post.Position.X, postH / 2, post.Position.Z)
			post.Parent = folder
		end
		local bar = part({
			Name = "ArchBar",
			Size = Vector3.new(10.4, 1.2, 1.2),
			Color = Color3.fromRGB(255, 210, 120),
		})
		bar.CFrame = cf * CFrame.new(0, 0, 0)
		bar.Position = Vector3.new(bar.Position.X, at.Y + 7.6, bar.Position.Z)
		bar.Parent = folder
	end
end

local stationPos: Vector3
local exitPad: BasePart

local function buildStation(folder: Folder)
	stationPos = sampleAtScan(0)
	local ahead = sampleAtScan(6)
	local cf = CFrame.lookAt(stationPos, ahead, Vector3.yAxis)

	-- platform beside the track (inland side), flush with the car floor
	local platform = part({
		Name = "StationPlatform",
		Size = Vector3.new(10, 1.2, 26),
		Color = TRIM_COLOR,
		CanCollide = true,
		CanQuery = true,
	})
	platform.CFrame = cf * CFrame.new(-7.2, 0, 0)
	platform.Position = Vector3.new(platform.Position.X, stationPos.Y - 1.4, platform.Position.Z)
	platform.Parent = folder
	exitPad = platform

	-- steps up from the grass
	for i = 1, 3 do
		local step = part({
			Name = "StationStep",
			Size = Vector3.new(6, 0.5, 3),
			Color = TRACK_COLOR,
			CanCollide = true,
			CanQuery = true,
		})
		step.CFrame = cf * CFrame.new(-12 - i * 1.4, 0, 0)
		step.Position = Vector3.new(step.Position.X, (stationPos.Y - 1.4) - i * 0.55, step.Position.Z)
		step.Parent = folder
	end

	-- a candy-striped canopy on poles
	for _, dz in ipairs({ -9, 9 }) do
		local pole = part({
			Name = "StationPole",
			Size = Vector3.new(0.8, 8, 0.8),
			Color = TRIM_COLOR,
		})
		pole.CFrame = cf * CFrame.new(-7.2, 0, dz)
		pole.Position = Vector3.new(pole.Position.X, stationPos.Y + 2.6, pole.Position.Z)
		pole.Parent = folder
	end
	for i = 0, 4 do
		local slat = part({
			Name = "StationAwning",
			Size = Vector3.new(11, 0.4, 4.4),
			Color = (i % 2 == 0) and Color3.fromRGB(255, 150, 170) or TRIM_COLOR,
		})
		slat.CFrame = cf * CFrame.new(-7.2, 0, -8.8 + i * 4.4)
		slat.Position = Vector3.new(slat.Position.X, stationPos.Y + 6.8, slat.Position.Z)
		slat.Parent = folder
	end

	-- the sign
	local gui = Instance.new("BillboardGui")
	gui.Name = "StationSign"
	gui.Size = UDim2.fromOffset(260, 48)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 9.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 110
	gui.Parent = platform
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 24
	label.TextColor3 = Color3.fromRGB(225, 90, 150)
	label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.Text = "🚂 The Sparkle Express"
	label.Parent = gui
end

-- ── the train ────────────────────────────────────────────────────────────────
local train: Model
local cars: { { model: Model, seats: { Seat }, bank: number } } = {}
local whistle: Sound
local chug: Sound

local function buildTrain(folder: Folder)
	train = Instance.new("Model")
	train.Name = "SparkleExpress"
	-- the train travels the whole land: replicate it to everyone, always
	train.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	for i = 1, CoasterConfig.Cars do
		local car = Instance.new("Model")
		car.Name = "Car" .. i
		local color = CAR_COLORS[((i - 1) % #CAR_COLORS) + 1]

		local body = part({
			Name = "Body",
			Size = Vector3.new(4, 1.6, 7),
			Color = color,
			CanCollide = true,
			CanQuery = true,
		})
		body.Parent = car
		car.PrimaryPart = body

		-- high sides: the "seatbelt illusion" (the weld is what really holds you)
		for _, sx in ipairs({ -1, 1 }) do
			local side = part({
				Name = "Side",
				Size = Vector3.new(0.5, 2.4, 7),
				Color = color,
			})
			side.CFrame = body.CFrame * CFrame.new(sx * 1.95, 1.6, 0)
			side.Parent = car
		end
		local back = part({
			Name = "Back",
			Size = Vector3.new(4, 2.4, 0.5),
			Color = color,
		})
		back.CFrame = body.CFrame * CFrame.new(0, 1.6, 3.4)
		back.Parent = car
		local front = part({
			Name = "Front",
			Size = Vector3.new(4, 1.8, 0.5),
			Color = color,
		})
		front.CFrame = body.CFrame * CFrame.new(0, 1.3, -3.4)
		front.Parent = car
		local trim = part({
			Name = "Trim",
			Size = Vector3.new(4.3, 0.4, 7.3),
			Color = TRIM_COLOR,
		})
		trim.CFrame = body.CFrame * CFrame.new(0, 0.9, 0)
		trim.Parent = car

		-- two seats per car
		local seats = {}
		for si, dz in ipairs({ -1.4, 1.6 }) do
			local seat = Instance.new("Seat")
			seat.Name = "RideSeat" .. si
			seat.Size = Vector3.new(3, 0.4, 2.4)
			seat.Color = TRIM_COLOR
			seat.Material = Enum.Material.SmoothPlastic
			seat.Anchored = true
			seat.CanQuery = true
			seat.CFrame = body.CFrame * CFrame.new(0, 1.2, dz)
			seat.Parent = car
			seats[si] = seat
		end

		-- the lead car gets a cheery face + cherry stack
		if i == 1 then
			local stack = part({
				Name = "Stack", Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.8, 1.1, 1.1),
				Color = TRIM_COLOR,
			})
			stack.CFrame = body.CFrame * CFrame.new(0, 1.7, -2.6) * CFrame.Angles(0, 0, math.rad(90))
			stack.Parent = car
			local cherry = part({
				Name = "StackCherry", Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.3, 1.3, 1.3),
				Color = Color3.fromRGB(214, 40, 70),
			})
			cherry.CFrame = body.CFrame * CFrame.new(0, 2.8, -2.6)
			cherry.Parent = car
			local puff = Instance.new("ParticleEmitter")
			puff.Name = "SparklePuff"
			puff.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			puff.LightEmission = 0.8
			puff.Color = ColorSequence.new(Color3.fromRGB(255, 244, 222), Color3.fromRGB(255, 214, 232))
			puff.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0),
			})
			puff.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1),
			})
			puff.Lifetime = NumberRange.new(0.8, 1.4)
			puff.Rate = 6
			puff.Speed = NumberRange.new(2, 4)
			puff.EmissionDirection = Enum.NormalId.Top
			puff.Parent = cherry
		end

		car.Parent = train
		cars[i] = { model = car, seats = seats, bank = 0 }
	end
	train.Parent = folder

	-- the lead car sings: a friendly toot at departure, a soft chug while rolling
	local leadBody = cars[1].model.PrimaryPart :: BasePart
	whistle = Instance.new("Sound")
	whistle.SoundId = SoundConfig.TrainWhistle
	whistle.Volume = 0.5
	whistle.RollOffMaxDistance = 160
	whistle.Parent = leadBody
	chug = Instance.new("Sound")
	chug.SoundId = SoundConfig.TrainChug
	chug.Looped = true
	chug.Volume = 0.28
	chug.RollOffMaxDistance = 120
	chug.Parent = leadBody
end

-- ── the ride loop ────────────────────────────────────────────────────────────
local dist = 0 -- arc length of the LEAD car (wrapped to the loop)
local rideDist = 0 -- unwrapped distance since the station (for lap counting)
local speed = 0
local state: "dwell" | "running" = "dwell"
local dwellRemaining = CoasterConfig.DwellSeconds

local function setSeatsEnabled(enabled: boolean)
	for _, car in ipairs(cars) do
		for _, seat in ipairs(car.seats) do
			seat.Disabled = not enabled
		end
	end
end

-- Gently put a humanoid's character on the platform (used for jump-offs and
-- end-of-ride). Never CFrame a still-seated character.
local function placeOnPlatform(humanoid: Humanoid)
	task.spawn(function()
		if humanoid.Sit or humanoid:GetState() == Enum.HumanoidStateType.Seated then
			humanoid.Sit = false
			local t0 = os.clock()
			while humanoid:GetState() == Enum.HumanoidStateType.Seated and os.clock() - t0 < 1 do
				task.wait(0.05)
			end
		end
		local char = humanoid.Parent :: Model?
		if char and char.Parent and exitPad then
			char:PivotTo(CFrame.new(exitPad.Position + Vector3.new(0, 3.2, 0)))
		end
	end)
end

local function dismountAll(message: string?)
	for _, car in ipairs(cars) do
		for _, seat in ipairs(car.seats) do
			local occupant = seat.Occupant
			if occupant then
				local char = occupant.Parent
				local player = char and Players:GetPlayerFromCharacter(char :: Model)
				if player and message then
					toastEvent:FireClient(player, message)
				end
				placeOnPlatform(occupant)
			end
		end
	end
end

local function update(dt: number)
	if state == "dwell" then
		dwellRemaining -= dt
		if dwellRemaining <= 0 then
			state = "running"
			setSeatsEnabled(false)
			rideDist = 0
			if whistle then
				whistle:Play()
			end
			if chug then
				chug:Play()
			end
		end
	else
		-- ease toward cruise, then brake so we stop exactly back at the station
		local rideLength = totalLength * CoasterConfig.LapsPerRide
		local lapRemaining = rideLength - rideDist
		-- Faster Rides: a shared, gentle boost — fast if anyone aboard wants it.
		-- Only the cruise TARGET scales; the brake math below still stops us exactly
		-- back at the station (it computes from actual speed, not this target).
		local riders = {}
		for _, car in ipairs(cars) do
			for _, seat in ipairs(car.seats) do
				if seat.Occupant then
					riders[#riders + 1] = seat.Occupant
				end
			end
		end
		local target = CoasterConfig.CruiseSpeed * RidePrefs.maxSpeedFor(riders, true)
		local brakeDist = (speed * speed) / (2 * CoasterConfig.Accel) + 2
		if lapRemaining <= brakeDist then
			target = math.max(2, math.sqrt(2 * CoasterConfig.Accel * math.max(lapRemaining, 0)))
		end
		if lapRemaining <= 0.5 then
			-- back at the station: doors open
			speed = 0
			state = "dwell"
			dwellRemaining = CoasterConfig.DwellSeconds
			setSeatsEnabled(true)
			dismountAll("🚂 Thanks for riding the Sparkle Express! Come back soon! 💝")
			rideDist = 0
			dist = 0
			if chug then
				chug:Stop()
			end
			return
		end
		speed += math.clamp(target - speed, -CoasterConfig.Accel * dt * 2, CoasterConfig.Accel * dt)
		rideDist += speed * dt
		dist = rideDist % totalLength
	end

	-- place every car along the spline (cars trail behind the lead)
	for i, car in ipairs(cars) do
		local s = (dist - (i - 1) * CoasterConfig.CarSpacing) % totalLength
		local pos = sampleAt(s)
		local aheadPos = sampleAt((s + CoasterConfig.LookAhead) % totalLength)
		-- gentle banking from the horizontal turn rate
		local flatA = Vector3.new(aheadPos.X - pos.X, 0, aheadPos.Z - pos.Z)
		local further = sampleAt((s + CoasterConfig.LookAhead * 3) % totalLength)
		local flatB = Vector3.new(further.X - aheadPos.X, 0, further.Z - aheadPos.Z)
		local targetBank = 0
		if flatA.Magnitude > 0.01 and flatB.Magnitude > 0.01 then
			local cross = flatA.Unit:Cross(flatB.Unit).Y
			targetBank = math.clamp(cross * 2.2, -CoasterConfig.MaxBank, CoasterConfig.MaxBank)
		end
		car.bank += (targetBank - car.bank) * math.min(dt * 4, 1)
		local cf = CFrame.lookAt(pos + Vector3.new(0, 1.4, 0), aheadPos + Vector3.new(0, 1.4, 0), Vector3.yAxis)
			* CFrame.Angles(0, 0, car.bank)
		car.model:PivotTo(cf)
	end
end

function CoasterService.init()
	toastEvent = Remotes.get(Remotes.Toast)

	local zone = ZoneConfig.get("Pudding Hills")
	if not zone then
		return
	end
	buildSamples(zone.center)

	local folder = Instance.new("Folder")
	folder.Name = "SparkleExpressRide"
	folder.Parent = Workspace

	buildTrack(folder)
	buildStation(folder)
	buildTrain(folder)

	-- jumping off mid-ride is the universal Roblox "I want out" — make it safe:
	-- whoever leaves a seat while the train is moving lands on the platform
	for _, car in ipairs(cars) do
		for _, seat in ipairs(car.seats) do
			local lastOccupant: Humanoid? = nil
			seat:GetPropertyChangedSignal("Occupant"):Connect(function()
				local now = seat.Occupant
				if now then
					lastOccupant = now
				elseif lastOccupant and state == "running" and speed > 2 then
					local leaver = lastOccupant
					lastOccupant = nil
					placeOnPlatform(leaver)
					local char = leaver.Parent
					local player = char and Players:GetPlayerFromCharacter(char :: Model)
					if player then
						toastEvent:FireClient(player, "✨ Poof — back at the station, safe and sound!")
					end
				else
					lastOccupant = nil
				end
			end)
		end
	end

	-- park the train at the station, doors open
	setSeatsEnabled(true)
	for i, car in ipairs(cars) do
		local s = (0 - (i - 1) * CoasterConfig.CarSpacing) % totalLength
		local pos = sampleAt(s)
		local aheadPos = sampleAt((s + CoasterConfig.LookAhead) % totalLength)
		car.model:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 1.4, 0), aheadPos + Vector3.new(0, 1.4, 0), Vector3.yAxis))
	end

	RunService.Heartbeat:Connect(update)
end

return CoasterService
