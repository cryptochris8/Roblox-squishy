-- SparkleTrail (CLIENT)
-- "Follow the sparkles": a little path of glowing footprints on the ground
-- leading to whatever this player's CURRENT objective is, plus a soft calling
-- beam and halo over the destination itself.
--
-- This is the storybook version of the arrow trail Chris spotted in the
-- competitor's tutorial, and it is the answer to the measured D1 problem: a
-- six-year-old does not read toasts. She follows sparkles.
--
-- THE NEVER-NAG RULES (doc 14 §1 — no pressure, no FOMO, no countdowns):
--   * While a First Day step is unpaid it runs continuously — that IS the
--     tutorial.
--   * After that it appears for a short while when the objective CHANGES ("here
--     is where that is"), then fades and does not come back for that objective.
--   * It stops drawing within 25 studs. You can see it now; get out of the way.
--   * No text, no counter, no timer, no sound, no arrow yelling.
--   * A toggle in Today's Quests. An escape hatch is what separates an
--     invitation from a nag.
--
-- Grown out of CapsuleTrail, which was this system pointed at exactly one
-- destination. The measured weaknesses of that version are all fixed here: the
-- beam was 2.2 studs wide (1.4 degrees at 88 studs — a thread), the crumbs were
-- screen-space pixels that stopped 12.5 studs short of the target and blanked
-- out for a fifth of every refresh.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local SparkleTrail = {}

local localPlayer = Players.LocalPlayer

local STOP_WITHIN = 25 -- close enough: stop drawing and let her look
local REFRESH = 1.6 -- seconds between crumb waves
local CRUMB_LIFE = 2.4 -- > REFRESH, so waves overlap and never blank
local STEP_STUDS = 6 -- one footprint every ~6 studs
local MAX_STEPS = 14
local FLASH_SECONDS = 60 -- how long a non-tutorial objective shows its trail

local active = false
local currentKey = nil -- identifies the objective, so we only flash on CHANGE
local flashDone = false -- this objective has HAD its one flash; never re-arm
local flashUntil = 0
local sticky = false -- tutorial mode: run continuously
local target: BasePart? = nil
local targetPos: Vector3? = nil
local color = Color3.fromRGB(255, 190, 215)
local beacon: Model? = nil
local loopToken = 0

local function enabled(): boolean
	return localPlayer:GetAttribute("FollowSparkles") ~= false
end

local function resolvePos(): Vector3?
	if target and target.Parent then
		return target.Position
	end
	return targetPos
end

local function clearBeacon()
	if beacon then
		beacon:Destroy()
		beacon = nil
	end
end

-- Crumbs and halos have to sit ON TOP of whatever she is walking on, or they
-- are simply inside it and invisible. Two classes of surface, and they need
-- different handling:
--   * decorative ground skins are CanQuery = false, so a raycast cannot see
--     them AT ALL (the same landmine that made the Landmark ribbons spear the
--     Express canopy): the caramel/boardwalk ribbons fill y 0.005-0.255,
--     Moonlit's stepping stones 0.015-0.265, and the widest of them, Pudding's
--     syrup river, -0.04 to 0.36 — she wades through that one, so it counts;
--   * real walkable props ARE queryable: the syrup bridge deck tops out at 0.8
--     and the spawn pad at 1.0.
-- So: ray for the solid surface, then never sit below the ground-skin ceiling.
-- The first version drew every crumb at a flat y = 0.12 (spanning 0.06-0.18),
-- which put it inside all of them — the trail vanished exactly where the path
-- network is densest, which is precisely where a six-year-old walks.
local PATH_SKIN_TOP = 0.4 -- clears the tallest CanQuery=false skin (the river)
local SURFACE_LIFT = 0.09 -- and ride this far proud of it
local surfaceParams = RaycastParams.new()
surfaceParams.FilterType = Enum.RaycastFilterType.Exclude
surfaceParams.IgnoreWater = true

-- Refresh the ray's exclude list. Characters and the sleepy friends are
-- CanQuery = ON (a friend has to stay clickable — SquishyModelFactory), so
-- without this the ray lands on a friend's head or a sibling's shoulder and the
-- footprint pops several studs into the air and back down again. Buddies and
-- the trail's own parts are already CanQuery = false. Called once per wave
-- rather than once per crumb.
local function setSurfaceFilter(alsoIgnore: Instance?)
	local filter = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			filter[#filter + 1] = plr.Character
		end
	end
	local squishies = Workspace:FindFirstChild("Squishies")
	if squishies then
		filter[#filter + 1] = squishies
	end
	if alsoIgnore then
		filter[#filter + 1] = alsoIgnore
	end
	surfaceParams.FilterDescendantsInstances = filter
end

local function surfaceY(x: number, z: number, nearY: number): number
	local hit = Workspace:Raycast(Vector3.new(x, nearY + 4, z), Vector3.new(0, -30, 0), surfaceParams)
	local solid = if hit then hit.Position.Y else 0
	return math.max(solid, PATH_SKIN_TOP) + SURFACE_LIFT
end

-- The calling beam + ground halo over the destination. The vertical beam is
-- badly foreshortened from a kid's ground-level camera, so the halo is what she
-- actually reads when she is standing near it.
local function buildBeacon(pos: Vector3)
	clearBeacon()
	local model = Instance.new("Model")
	model.Name = "SparkleTrailBeacon"

	local beam = Instance.new("Part")
	beam.Name = "Beam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.55
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(46, 4.5, 4.5) -- wide enough to read at 90 studs
	beam.CFrame = CFrame.new(pos + Vector3.new(0, 24, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = model

	-- Ground halos. They PULSE outward rather than spin: a disc rotating about
	-- its own axis of symmetry is visually identical every frame (the first
	-- version span invisibly), and a ripple reads better from a kid's low camera
	-- anyway — it's the part of the beacon she actually sees when standing near.
	-- The destination itself is excluded from the ray: this is a GROUND halo, and
	-- an objective that sits up off the floor (a capsule Base, a shard pedestal)
	-- would otherwise catch the ray and wear the rings like a hat.
	setSurfaceFilter(if target then (target:FindFirstAncestorOfClass("Model") or target) else nil)
	local haloY = surfaceY(pos.X, pos.Z, pos.Y)
	for i = 1, 3 do
		local ring = Instance.new("Part")
		ring.Name = "Halo" .. i
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		ring.Material = Enum.Material.Neon
		ring.Color = color
		ring.Transparency = 0.55
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.2, 4, 4)
		-- same surface rule as the crumbs: a halo at a flat 0.2 is swallowed by
		-- the very path that leads to the destination it is marking.
		ring.CFrame = CFrame.new(pos.X, haloY + i * 0.02, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = model
		local info = TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, false, (i - 1) * 0.8)
		TweenService:Create(ring, info, { Size = Vector3.new(0.2, 22, 22) }):Play()
		TweenService:Create(ring, info, { Transparency = 1 }):Play()
	end

	model.Parent = Workspace
	beacon = model

	task.spawn(function()
		while beacon == model and beam.Parent do
			local a = TweenService:Create(beam, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.8 })
			a:Play()
			a.Completed:Wait()
			if beacon ~= model or not beam.Parent then
				break
			end
			local b = TweenService:Create(beam, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Transparency = 0.5 })
			b:Play()
			b.Completed:Wait()
		end
	end)
end

-- One wave of footprints from the player toward the destination. These are real
-- PARTS, not screen-space pixels: they scale correctly with distance and read
-- as a path lying on the ground, which is the thing a small child follows.
local function dropWave(from: Vector3, to: Vector3)
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local dist = flat.Magnitude
	if dist < STOP_WITHIN then
		return
	end
	-- The lands sit 600 studs apart on X. A trail toward a target in ANOTHER
	-- land would draw a line of footprints out across the void, which is both
	-- nonsense and a long row of parts nobody can follow.
	if math.abs(to.X - from.X) > 260 then
		return
	end
	local steps = math.clamp(math.floor(dist / STEP_STUDS), 3, MAX_STEPS)
	setSurfaceFilter(nil)
	for i = 1, steps do
		-- i/steps, not i/(steps+1): the old trail stopped ~14% short of where
		-- it was pointing, which is exactly where a kid stops looking.
		local at = from:Lerp(to, i / steps)
		local print_ = Instance.new("Part")
		print_.Name = "SparkleStep"
		print_.Anchored = true
		print_.CanCollide = false
		print_.CanQuery = false
		print_.CanTouch = false
		print_.CastShadow = false
		print_.Material = Enum.Material.Neon
		print_.Color = color
		print_.Transparency = 0.35
		print_.Shape = Enum.PartType.Cylinder
		print_.Size = Vector3.new(0.12, 1.8, 1.8)
		print_.CFrame = CFrame.new(at.X, surfaceY(at.X, at.Z, from.Y), at.Z) * CFrame.Angles(0, 0, math.rad(90))
		print_.Parent = Workspace
		Debris:AddItem(print_, CRUMB_LIFE)
		-- a staggered little hop, so the line reads as footsteps walking AWAY
		task.delay(i * 0.06, function()
			if print_.Parent then
				TweenService:Create(print_, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
					Size = Vector3.new(0.12, 2.3, 2.3),
				}):Play()
			end
		end)
		TweenService:Create(print_, TweenInfo.new(CRUMB_LIFE, Enum.EasingStyle.Quad), {
			Transparency = 1,
		}):Play()
	end
end

local function stop()
	active = false
	loopToken += 1
	clearBeacon()
end

local function start()
	if active then
		return
	end
	active = true
	loopToken += 1
	local token = loopToken
	task.spawn(function()
		local lastBeaconAt: Vector3? = nil
		while active and loopToken == token do
			if not enabled() then
				break -- toggled off: do NOT spend the flash, so it can resume
			end
			if not sticky and os.clock() > flashUntil then
				flashDone = true -- spent. This objective never flashes again.
				break
			end
			local pos = resolvePos()
			local char = localPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if pos and hrp then
				local here = (hrp :: BasePart).Position
				-- The same 260-stud cross-land guard dropWave already applies:
				-- the lands sit 600 apart on X, and an objective in another one
				-- (Pudding is always open, so she can walk away from a ready
				-- shard) hangs a neon pillar over the far land's sky.
				if math.abs(pos.X - here.X) <= 260 then
					if not lastBeaconAt or (lastBeaconAt - pos).Magnitude > 2 then
						buildBeacon(pos)
						lastBeaconAt = pos
					end
				elseif beacon then
					clearBeacon()
					lastBeaconAt = nil
				end
				dropWave(here, pos)
			end
			task.wait(REFRESH)
		end
		if loopToken == token then
			stop()
		end
	end)
end

-- Point the trail somewhere. `key` identifies the objective: re-setting the
-- SAME key does not restart the flash (that would make it a nag).
function SparkleTrail.setTarget(key: string, part: BasePart?, pos: Vector3?, opts)
	opts = opts or {}
	if key == currentKey then
		-- SAME objective: keep the aim fresh, but NEVER re-arm the flash. This
		-- guard used to also require `active`, which meant that the moment a
		-- flash expired the next StateSync (there are ~44 server sync sites —
		-- every Happy Pop is one) restarted it. The trail relayed forever in
		-- 60-second segments: precisely the nag the Law forbids.
		target = part
		targetPos = pos
		if not active and not flashDone and enabled() and (sticky or os.clock() < flashUntil) then
			start()
		end
		return
	end
	currentKey = key
	flashDone = false
	target = part
	targetPos = pos
	color = opts.color or Color3.fromRGB(255, 190, 215)
	sticky = opts.sticky == true
	flashUntil = os.clock() + (opts.flash or FLASH_SECONDS)
	stop()
	if enabled() then
		start()
	end
end

function SparkleTrail.clear()
	currentKey = nil
	flashDone = false -- a genuinely NEW objective later deserves its own flash
	target = nil
	targetPos = nil
	stop()
end

-- Photo Mode / a Photo Spot: step out of the shot, like the beacons do.
function SparkleTrail.setSuppressed(on: boolean)
	if on then
		stop()
	elseif currentKey and enabled() and not flashDone and (sticky or os.clock() < flashUntil) then
		start()
	end
end

-- The toggle flipped: honour it immediately, either way.
function SparkleTrail.refreshPreference()
	if not enabled() then
		stop()
	elseif currentKey and (sticky or os.clock() < flashUntil) then
		start()
	end
end

return SparkleTrail
