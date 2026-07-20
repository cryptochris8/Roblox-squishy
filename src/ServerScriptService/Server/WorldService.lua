-- WorldService (SERVER)
-- Builds a simple, cozy Pudding Hills starter zone out of placeholder parts:
-- a pastel ground, soft hill mounds, a Sparkle Capsule machine, a Soft Dumpling
-- guide, a player spawn, and the pads where sleepy squishy friends appear.
-- Returns the things Main needs to wire up (spawn pad CFrames + the two prompts).

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ZoneConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ZoneConfig"))
local SquishyData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SquishyData"))
local SquishyModelFactory = require(script.Parent.SquishyModelFactory)
local RidePrefs = require(script.Parent.RidePrefs)

local WorldService = {}

-- "Use the WHOLE land": every placement offset stretches away from the land
-- centre by ZoneConfig.Spread, so the districts reach the plate edges instead
-- of huddling in the middle. SP stretches one offset; SPL stretches a list of
-- path waypoints in place.
local SP = ZoneConfig.spread
local function SPL(pts: { Vector3 }): { Vector3 }
	for i, p in ipairs(pts) do
		pts[i] = SP(p)
	end
	return pts
end

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
	gui.MaxDistance = 60 -- labels announce what's NEAR; distant ones just stack into word soup
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

-- A soft walking path: flat ribbon segments through the waypoints. These guide
-- little explorers from the spawn out to the far pockets of each land (the
-- 6-year-old should always have a trail to follow).
local function ribbonPath(folder: Instance, pts: { Vector3 }, width: number, color: Color3)
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local dir = b - a
		local seg = part({
			Name = "Path",
			Size = Vector3.new(dir.Magnitude + width, 0.25, width),
			Color = color,
			CanCollide = false,
			CanQuery = false,
		})
		seg.CFrame = CFrame.new((a + b) / 2 + Vector3.new(0, 0.13, 0)) * CFrame.Angles(0, math.atan2(-dir.Z, dir.X), 0)
		seg.Parent = folder
	end
end

-- Glowing stepping stones (Moonlit's night-friendly version of a path).
local function steppingStones(folder: Instance, pts: { Vector3 }, colors: { Color3 })
	local idx = 0
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local dist = (b - a).Magnitude
		local steps = math.max(1, math.floor(dist / 4.5))
		for s = 0, steps do
			idx += 1
			local stone = part({
				Name = "Stone",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.25, 1.9, 1.9),
				Color = colors[(idx % #colors) + 1],
				Material = Enum.Material.Neon,
				Transparency = 0.35,
				CanCollide = false,
				CanQuery = false,
			})
			stone.CFrame = CFrame.new(a:Lerp(b, s / steps) + Vector3.new(0, 0.14, 0)) * CFrame.Angles(0, 0, math.rad(90))
			stone.Parent = folder
		end
	end
end

-- A fluffy cloud-bush (the book's white ground-clouds with flowers peeking out).
local function cloudBush(folder: Instance, at: Vector3, tint: Color3, flowerColor: Color3)
	for i, off in ipairs({ Vector3.new(0, 0, 0), Vector3.new(2.6, -0.4, 1), Vector3.new(-2.2, -0.5, -0.8) }) do
		local puff = part({
			Name = "CloudBush", Shape = Enum.PartType.Ball,
			Size = Vector3.new(5 - i, 3.4 - i * 0.5, 5 - i),
			Position = at + off + Vector3.new(0, 1.2, 0),
			Color = tint, CanCollide = false,
		})
		puff.Parent = folder
	end
	local stem = part({
		Name = "CloudStem", Size = Vector3.new(0.25, 1.8, 0.25),
		Position = at + Vector3.new(1, 3.2, 0.6), Color = Color3.fromRGB(150, 208, 130), CanCollide = false,
	})
	stem.Parent = folder
	local bloom = part({
		Name = "CloudBloom", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1.2, 1),
		Position = at + Vector3.new(1, 4.4, 0.6), Color = flowerColor, CanCollide = false,
	})
	bloom.Parent = folder
end

-- ── Beauty-pass builders (2026-06-12: candy/dessert props from the theme
-- research — skyline silhouettes, gentle offset-phase motion, night glow) ───

-- Chain-tweens a part around a loop of points forever (sky drifters).
local function driftLoop(p: BasePart, points: { Vector3 }, secsPerLeg: number, startIndex: number)
	local idx = startIndex
	local function nextLeg()
		idx = (idx % #points) + 1
		local tween = TweenService:Create(p, TweenInfo.new(secsPerLeg, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			Position = points[idx],
		})
		tween.Completed:Connect(nextLeg)
		tween:Play()
	end
	p.Position = points[(startIndex % #points) + 1]
	nextLeg()
end

-- A macaron hot-air balloon drifting a slow, wide circuit overhead.
local function macaronBalloon(folder: Instance, center: Vector3, radius: number, altitude: number, c1: Color3, c2: Color3, phase: number)
	local rig = Instance.new("Model")
	rig.Name = "MacaronBalloon"
	local shellTop = part({
		Name = "ShellTop", Shape = Enum.PartType.Ball, Size = Vector3.new(15, 9, 15),
		Color = c1, CanCollide = false, CanQuery = false,
	})
	shellTop.Parent = rig
	rig.PrimaryPart = shellTop
	local cream = part({
		Name = "Cream", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 14.4, 14.4),
		Color = Color3.fromRGB(255, 250, 240), CanCollide = false, CanQuery = false,
	})
	cream.Parent = rig
	local shellBot = part({
		Name = "ShellBot", Shape = Enum.PartType.Ball, Size = Vector3.new(15, 9, 15),
		Color = c2, CanCollide = false, CanQuery = false,
	})
	shellBot.Parent = rig
	local basket = part({
		Name = "Basket", Size = Vector3.new(3.4, 2.6, 3.4),
		Color = Color3.fromRGB(196, 154, 116), CanCollide = false, CanQuery = false,
	})
	basket.Parent = rig
	rig.Parent = folder

	-- the rig follows an invisible anchor part so one tween moves the lot
	local anchor = part({
		Name = "BalloonAnchor", Size = Vector3.new(1, 1, 1), Transparency = 1,
		CanCollide = false, CanQuery = false,
	})
	anchor.Parent = folder
	local points = {}
	for i = 1, 4 do
		local a = phase + (i / 4) * math.pi * 2
		points[i] = center + Vector3.new(math.cos(a) * radius, altitude + (i % 2) * 4, math.sin(a) * radius)
	end
	driftLoop(anchor, points, 34, 1)
	RunService.Heartbeat:Connect(function()
		local at = anchor.Position
		shellTop.Position = at + Vector3.new(0, 4, 0)
		cream.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
		shellBot.Position = at - Vector3.new(0, 4, 0)
		basket.Position = at - Vector3.new(0, 11, 0)
	end)
end

-- The Soda-Falls Spring: the storybook SOURCE of the syrup river — a cream
-- cliff with translucent honey falls and fizzing foam at the base.
local function sodaFalls(folder: Instance, at: Vector3, faceToward: Vector3)
	local face = CFrame.lookAt(Vector3.new(at.X, 0, at.Z), Vector3.new(faceToward.X, 0, faceToward.Z))
	for i = 1, 3 do
		local block = part({
			Name = "FallsCliff" .. i, Size = Vector3.new(20 - i * 3, 7, 9 - i * 1.6),
			Color = Color3.fromRGB(255, 238, 214),
		})
		block.CFrame = face * CFrame.new(0, i * 6 - 3, -(i - 1) * 2.4)
		block.Parent = folder
	end
	for li, off in ipairs({ Vector3.new(-2.4, 0, 0), Vector3.new(2.6, 0, 0.6) }) do
		local sheet = part({
			Name = "FallsSheet" .. li, Size = Vector3.new(5.4, 14, 0.5),
			Color = Color3.fromRGB(255, 226, 160), Material = Enum.Material.Glass,
			Transparency = 0.35, CanCollide = false,
		})
		sheet.CFrame = face * CFrame.new(off.X, 8.4, 3.6 + off.Z)
		sheet.Parent = folder
	end
	for f = 1, 6 do
		local foam = part({
			Name = "FallsFoam", Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.2 + (f % 3), 1.6, 2.2 + (f % 2)),
			Color = Color3.fromRGB(255, 250, 240), CanCollide = false,
		})
		local fx = -4 + f * 1.6
		foam.CFrame = face * CFrame.new(fx, 0.8, 4.6)
		foam.Parent = folder
		TweenService:Create(foam, TweenInfo.new(2 + f * 0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Position = foam.Position + Vector3.new(0, 0.7, 0),
		}):Play()
	end
end

-- A walk-through donut arch (ring of fat cylinders, pink icing on top half).
local function donutArch(folder: Instance, at: Vector3, faceToward: Vector3)
	local face = CFrame.lookAt(Vector3.new(at.X, 0, at.Z), Vector3.new(faceToward.X, 0, faceToward.Z))
	local R = 9
	local segs = 12
	for i = 1, segs do
		local a = (i / segs) * math.pi * 2
		local y = R + math.sin(a) * R
		local isTop = math.sin(a) > 0.15
		local seg = part({
			Name = "DonutSeg", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3.4, 4.2, 4.2),
			Color = isTop and Color3.fromRGB(255, 170, 195) or Color3.fromRGB(243, 196, 138),
			CanCollide = false,
		})
		seg.CFrame = face * CFrame.new(math.cos(a) * R, y + 1.2, 0) * CFrame.Angles(0, math.rad(90), 0)
		seg.Parent = folder
		if isTop and i % 2 == 0 then
			local sprinkle = part({
				Name = "DonutSprinkle", Size = Vector3.new(0.5, 1.6, 0.5),
				Color = ({ Color3.fromRGB(150, 226, 234), Color3.fromRGB(255, 226, 130), Color3.fromRGB(190, 160, 240) })[(i / 2) % 3 + 1],
				Material = Enum.Material.Neon, CanCollide = false,
			})
			sprinkle.CFrame = face * CFrame.new(math.cos(a) * R, y + 3.4, 0) * CFrame.Angles(0, 0, math.rad(30 * i))
			sprinkle.Parent = folder
		end
	end
end

-- Candy-cane arch pairs along a path (Peppermint-Forest rhythm).
local function candyCaneArch(folder: Instance, at: Vector3, faceToward: Vector3)
	local face = CFrame.lookAt(Vector3.new(at.X, 0, at.Z), Vector3.new(faceToward.X, 0, faceToward.Z))
	for _, sx in ipairs({ -1, 1 }) do
		for seg = 0, 6 do
			local cane = part({
				Name = "CaneSeg", Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.5, 1.3, 1.3),
				Color = (seg % 2 == 0) and Color3.fromRGB(255, 120, 140) or Color3.fromRGB(255, 250, 240),
				CanCollide = false,
			})
			cane.CFrame = face * CFrame.new(sx * 4.2, 0.75 + seg * 1.4, 0) * CFrame.Angles(0, 0, math.rad(90))
			cane.Parent = folder
		end
		-- the hook curls inward over the path
		for h = 1, 4 do
			local a = math.rad(h * 36)
			local hook = part({
				Name = "CaneHook", Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.4, 1.2, 1.2),
				Color = (h % 2 == 0) and Color3.fromRGB(255, 120, 140) or Color3.fromRGB(255, 250, 240),
				CanCollide = false,
			})
			hook.CFrame = face * CFrame.new(sx * (4.2 - math.sin(a) * 2.4), 9.8 + math.sin(a + math.rad(50)) * 1.4, 0)
				* CFrame.Angles(0, 0, math.rad(90) + math.rad(sx * h * 24))
			hook.Parent = folder
		end
	end
end

-- A gumball lamp post: a glass globe of mini gumballs, one Neon so it glows.
local function gumballLamp(folder: Instance, at: Vector3)
	local post = part({
		Name = "GumballPost", Size = Vector3.new(0.7, 6, 0.7),
		Color = Color3.fromRGB(255, 250, 240),
	})
	post.Position = at + Vector3.new(0, 3, 0)
	post.Parent = folder
	local globe = part({
		Name = "GumballGlobe", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4),
		Color = Color3.fromRGB(235, 245, 250), Material = Enum.Material.Glass,
		Transparency = 0.45, CanCollide = false,
	})
	globe.Position = at + Vector3.new(0, 7.4, 0)
	globe.Parent = folder
	local gumColors = { Color3.fromRGB(255, 150, 170), Color3.fromRGB(255, 210, 120), Color3.fromRGB(150, 220, 224), Color3.fromRGB(190, 160, 240) }
	for g = 1, 7 do
		local a = g * 0.9
		local gum = part({
			Name = "Gumball", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1),
			Color = gumColors[(g % #gumColors) + 1],
			Material = (g == 1) and Enum.Material.Neon or Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		gum.Position = at + Vector3.new(math.cos(a) * 0.9, 6.8 + (g % 3) * 0.8, math.sin(a) * 0.9)
		gum.Parent = folder
		if g == 1 then
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 220, 180)
			glow.Brightness = 1
			glow.Range = 14
			glow.Parent = gum
		end
	end
end

-- A glowing goo-fish: a translucent bell hovering over the sea, breathing.
local function gooFish(folder: Instance, at: Vector3, tint: Color3, phase: number)
	local bell = part({
		Name = "GooFishBell", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 6, 7),
		Color = tint, Material = Enum.Material.Glass, Transparency = 0.35,
		CanCollide = false, CanQuery = false, CastShadow = false,
	})
	bell.Position = at
	bell.Parent = folder
	local core = part({
		Name = "GooFishCore", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4),
		Color = Color3.fromRGB(255, 250, 240), Material = Enum.Material.Neon,
		Transparency = 0.2, CanCollide = false, CanQuery = false, CastShadow = false,
	})
	core.Position = at
	core.Parent = folder
	for tIdx = 1, 5 do
		local a = (tIdx / 5) * math.pi * 2
		local tendril = part({
			Name = "GooFishTendril", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(5, 0.35, 0.35),
			Color = tint, Material = Enum.Material.Neon, Transparency = 0.4,
			CanCollide = false, CanQuery = false, CastShadow = false,
		})
		tendril.CFrame = CFrame.new(at + Vector3.new(math.cos(a) * 1.8, -4.2, math.sin(a) * 1.8))
			* CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(math.rad(10), 0, 0)
		tendril.Parent = folder
		TweenService:Create(tendril, TweenInfo.new(3 + phase, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Position = tendril.Position + Vector3.new(0, 1.6, 0),
		}):Play()
	end
	local info = TweenInfo.new(3.4 + phase, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	TweenService:Create(bell, info, { Position = at + Vector3.new(0, 2.2, 0), Size = Vector3.new(7.5, 5.6, 7.5) }):Play()
	TweenService:Create(core, info, { Position = at + Vector3.new(0, 2.2, 0) }):Play()
end

-- A distant sherbet isle: a stacked ice-cream peak (borrowed scenery).
local function sherbetIsle(folder: Instance, at: Vector3, scoopColor: Color3)
	local widths = { 20, 16, 12, 8 }
	for i, w in ipairs(widths) do
		local tier = part({
			Name = "IsleCone" .. i, Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(5, w, w),
			Color = Color3.fromRGB(236, 200, 150),
		})
		tier.CFrame = CFrame.new(at + Vector3.new(0, i * 4.4 - 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		tier.Parent = folder
	end
	local scoop = part({
		Name = "IsleScoop", Shape = Enum.PartType.Ball, Size = Vector3.new(15, 12, 15),
		Color = scoopColor,
	})
	scoop.Position = at + Vector3.new(0, 22, 0)
	scoop.Parent = folder
	for d = 1, 5 do
		local a = math.rad(d * 72)
		local drip = part({
			Name = "IsleDrip", Shape = Enum.PartType.Ball, Size = Vector3.new(3.4, 5, 3.4),
			Color = Color3.fromRGB(255, 250, 240), CanCollide = false,
		})
		drip.Position = at + Vector3.new(math.cos(a) * 6.4, 18.5, math.sin(a) * 6.4)
		drip.Parent = folder
	end
	local cherry = part({
		Name = "IsleCherry", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4),
		Color = Color3.fromRGB(214, 40, 70), Reflectance = 0.12,
	})
	cherry.Position = at + Vector3.new(0, 29.5, 0)
	cherry.Parent = folder
end

-- Rock-candy sea stacks: boulder clusters bristling with glass crystals.
local function rockCandyStack(folder: Instance, at: Vector3)
	for b = 1, 3 do
		local d = 7 - b * 1.4
		local rock = part({
			Name = "CandyRock", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d * 0.8, d),
			Color = Color3.fromRGB(196, 186, 210),
		})
		rock.Position = at + Vector3.new((b - 2) * 2.6, d * 0.3, (b % 2) * 2)
		rock.Parent = folder
	end
	local crystalColors = { Color3.fromRGB(140, 230, 214), Color3.fromRGB(255, 170, 200) }
	for c = 1, 6 do
		local h = 2.5 + (c % 3) * 1.8
		local crystal = part({
			Name = "CandyCrystal", Size = Vector3.new(1, h, 1),
			Color = crystalColors[(c % 2) + 1], Material = Enum.Material.Glass,
			Transparency = 0.25, CanCollide = false,
		})
		crystal.CFrame = CFrame.new(at + Vector3.new(math.cos(c * 1.1) * 3, h / 2 + 1.4, math.sin(c * 1.1) * 3))
			* CFrame.Angles(math.rad(math.sin(c) * 16), 0, math.rad(math.cos(c) * 16))
		crystal.Parent = folder
	end
	local heart = part({
		Name = "CandyHeart", Size = Vector3.new(1.4, 2, 1.4),
		Color = Color3.fromRGB(255, 226, 150), Material = Enum.Material.Neon,
		Transparency = 0.3, CanCollide = false,
	})
	heart.Position = at + Vector3.new(0, 2.4, 0)
	heart.Parent = folder
end

-- The saltwater-taffy fountain: pastel ball-arcs leaping from a basin,
-- slowly rotating — every plaza deserves a weenie.
local function taffyFountain(folder: Instance, at: Vector3)
	local basin = part({
		Name = "TaffyBasin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4, 13, 13),
		Color = Color3.fromRGB(255, 250, 240),
	})
	basin.CFrame = CFrame.new(at + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90))
	basin.Parent = folder
	local pool = part({
		Name = "TaffyPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 11.4, 11.4),
		Color = Color3.fromRGB(120, 224, 220), Material = Enum.Material.Glass,
		Transparency = 0.25, Reflectance = 0.15, CanCollide = false,
	})
	pool.CFrame = CFrame.new(at + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pool.Parent = folder
	local pedestal = part({
		Name = "TaffyPedestal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 2.4, 2.4),
		Color = Color3.fromRGB(255, 250, 240),
	})
	pedestal.CFrame = CFrame.new(at + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pedestal.Parent = folder

	local arcModel = Instance.new("Model")
	arcModel.Name = "TaffyArcs"
	local pivot = part({
		Name = "ArcPivot", Size = Vector3.new(1, 1, 1), Transparency = 1,
		CanCollide = false, CanQuery = false,
	})
	pivot.Position = at + Vector3.new(0, 4.6, 0)
	pivot.Parent = arcModel
	arcModel.PrimaryPart = pivot
	local taffyColors = { Color3.fromRGB(255, 170, 195), Color3.fromRGB(255, 226, 150), Color3.fromRGB(170, 200, 255) }
	for arm = 1, 3 do
		local armA = math.rad(arm * 120)
		for b = 1, 5 do
			local t = b / 5
			local ball = part({
				Name = "TaffyBall", Shape = Enum.PartType.Ball,
				Size = Vector3.new(2 - t, 2 - t, 2 - t),
				Color = taffyColors[arm], CanCollide = false, CanQuery = false,
			})
			ball.Position = at + Vector3.new(
				math.cos(armA) * t * 4.4,
				4.6 + math.sin(t * math.pi) * 3.4,
				math.sin(armA) * t * 4.4
			)
			ball.Parent = arcModel
		end
	end
	arcModel.Parent = folder
	task.spawn(function()
		local angle = 0
		RunService.Heartbeat:Connect(function(dt)
			angle += dt * math.pi * 2 / 22
			arcModel:PivotTo(CFrame.new(at + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, angle, 0))
		end)
	end)
end

-- The crescent-moon swing: a sittable glowing crescent on ropes (book canon —
-- the Hollow's moon is a crescent, and Candytopia says swings win photo ops).
local function crescentSwing(folder: Instance, at: Vector3, faceToward: Vector3)
	local face = CFrame.lookAt(Vector3.new(at.X, 0, at.Z), Vector3.new(faceToward.X, 0, faceToward.Z))
	for _, sx in ipairs({ -1, 1 }) do
		local post = part({
			Name = "SwingPost", Size = Vector3.new(1, 14, 1),
			Color = Color3.fromRGB(150, 132, 205),
		})
		post.CFrame = face * CFrame.new(sx * 6, 7, 0)
		post.Parent = folder
	end
	local beam = part({
		Name = "SwingBeam", Size = Vector3.new(13.4, 1, 1),
		Color = Color3.fromRGB(150, 132, 205),
	})
	beam.CFrame = face * CFrame.new(0, 14.2, 0)
	beam.Parent = folder

	local swing = Instance.new("Model")
	swing.Name = "CrescentSwing"
	local pivotPart = part({
		Name = "SwingPivot", Size = Vector3.new(1, 1, 1), Transparency = 1,
		CanCollide = false, CanQuery = false,
	})
	pivotPart.CFrame = face * CFrame.new(0, 14.2, 0)
	pivotPart.Parent = swing
	swing.PrimaryPart = pivotPart
	-- the crescent: an arc of glowing beads, fattest at the bottom
	for i = 0, 8 do
		local a = math.rad(200 + i * 17.5)
		local d = 2.2 - math.abs(i - 4) * 0.3
		local bead = part({
			Name = "CrescentBead", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d),
			Color = Color3.fromRGB(255, 234, 170), Material = Enum.Material.Neon,
			CanCollide = false, CanQuery = false,
		})
		bead.CFrame = face * CFrame.new(math.cos(a) * 4.4, 8.6 + math.sin(a) * 4.4, 0)
		bead.Parent = swing
	end
	local seat = Instance.new("Seat")
	seat.Name = "SwingSeat"
	seat.Size = Vector3.new(3, 0.4, 1.8)
	seat.Color = Color3.fromRGB(255, 250, 240)
	seat.Material = Enum.Material.SmoothPlastic
	seat.Anchored = true
	seat.CFrame = face * CFrame.new(0, 4.6, 0)
	seat.Parent = swing
	for _, sx in ipairs({ -1, 1 }) do
		local rope = part({
			Name = "SwingRope", Size = Vector3.new(0.22, 9.4, 0.22),
			Color = Color3.fromRGB(236, 228, 244), CanCollide = false, CanQuery = false,
		})
		rope.CFrame = face * CFrame.new(sx * 3.4, 9.4, 0)
		rope.Parent = swing
	end
	swing.Parent = folder
	-- gentle pendulum around the beam. Phase accumulator (not sin of absolute t)
	-- so Faster Rides speeds the swing up smoothly instead of teleporting the seat.
	task.spawn(function()
		local phase = 0
		local pivotCF = face * CFrame.new(0, 14.2, 0)
		RunService.Heartbeat:Connect(function(dt)
			local mult = RidePrefs.speedFor(seat.Occupant)
			phase += dt * (math.pi * 2 / 5) * mult
			local a = math.sin(phase) * math.rad(6)
			swing:PivotTo(pivotCF * CFrame.Angles(0, 0, a) * CFrame.new(0, 0, 0))
		end)
	end)
end

-- Sagging starlight lantern strings between two posts (the village pulse).
local function lanternString(folder: Instance, a: Vector3, b: Vector3, phase: number)
	local span = (b - a).Magnitude
	local count = math.max(5, math.floor(span / 6))
	for i = 0, count do
		local t = i / count
		local sag = math.sin(t * math.pi) * -math.min(4, span * 0.08)
		local pos = a:Lerp(b, t) + Vector3.new(0, sag, 0)
		if i < count then
			local nt = (i + 1) / count
			local nsag = math.sin(nt * math.pi) * -math.min(4, span * 0.08)
			local npos = a:Lerp(b, nt) + Vector3.new(0, nsag, 0)
			local dir = npos - pos
			local cable = part({
				Name = "LanternCable", Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(dir.Magnitude + 0.2, 0.16, 0.16),
				Color = Color3.fromRGB(120, 100, 110), CanCollide = false, CanQuery = false,
			})
			cable.CFrame = CFrame.lookAt((pos + npos) / 2, npos) * CFrame.Angles(0, math.rad(90), 0)
			cable.Parent = folder
		end
		if i % 2 == 1 then
			local bulb = part({
				Name = "StringLantern", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 1.1, 0.9),
				Color = Color3.fromRGB(255, 226, 150), Material = Enum.Material.Neon,
				CanCollide = false, CanQuery = false,
			})
			bulb.Position = pos - Vector3.new(0, 0.8, 0)
			bulb.Parent = folder
			TweenService:Create(bulb, TweenInfo.new(2.6 + phase + i * 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Transparency = 0.45,
			}):Play()
		end
	end
end

-- Aurora ribbons: long translucent slabs drifting high over the Hollow.
local function auroraRibbons(folder: Instance, center: Vector3)
	local colors = { Color3.fromRGB(140, 230, 200), Color3.fromRGB(170, 180, 255), Color3.fromRGB(220, 160, 240), Color3.fromRGB(150, 226, 210) }
	for i = 1, 4 do
		local ribbon = part({
			Name = "Aurora" .. i, Size = Vector3.new(64, 0.4, 7),
			Color = colors[i], Material = Enum.Material.Neon, Transparency = 0.55,
			CanCollide = false, CanQuery = false, CastShadow = false,
		})
		local base = center + Vector3.new(-30 + i * 14, 72 + i * 6, -36 - i * 14)
		ribbon.CFrame = CFrame.new(base) * CFrame.Angles(math.rad(14), math.rad(i * 24), math.rad(6))
		ribbon.Parent = folder
		local info = TweenInfo.new(9 + i * 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		TweenService:Create(ribbon, info, {
			Position = base + Vector3.new(16, 3, 0),
			Transparency = 0.75,
		}):Play()
	end
end

-- The cocoa campfire: a warm amber heart for the stargazing circle.
local function cocoaCampfire(folder: Instance, at: Vector3)
	for i = 1, 4 do
		local a = math.rad(i * 90 + 45)
		local log = part({
			Name = "CampLog", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.6, 1.3, 1.3),
			Color = Color3.fromRGB(150, 116, 92),
		})
		log.CFrame = CFrame.new(at + Vector3.new(math.cos(a) * 1.6, 0.6, math.sin(a) * 1.6))
			* CFrame.Angles(0, a + math.rad(90), math.rad(90))
		log.Parent = folder
	end
	for f = 1, 3 do
		local flame = part({
			Name = "CampFlame", Shape = Enum.PartType.Ball,
			Size = Vector3.new(2.2 - f * 0.5, 2.8 - f * 0.5, 2.2 - f * 0.5),
			Color = (f == 3) and Color3.fromRGB(255, 244, 200) or Color3.fromRGB(255, 190, 110),
			Material = Enum.Material.Neon, Transparency = 0.15 + f * 0.1,
			CanCollide = false, CanQuery = false, CastShadow = false,
		})
		flame.Position = at + Vector3.new(0, 1 + f * 0.7, 0)
		flame.Parent = folder
		TweenService:Create(flame, TweenInfo.new(0.9 + f * 0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Size = flame.Size * 1.18,
		}):Play()
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 196, 130)
	glow.Brightness = 1.6
	glow.Range = 22
	local anchorFlame = folder:FindFirstChild("CampFlame")
	if anchorFlame then
		glow.Parent = anchorFlame
	end
	local embers = Instance.new("ParticleEmitter")
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.LightEmission = 1
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 210, 140), Color3.fromRGB(255, 170, 110))
	embers.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0),
	})
	embers.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1),
	})
	embers.Lifetime = NumberRange.new(1.2, 2)
	embers.Rate = 4
	embers.Speed = NumberRange.new(2, 4)
	embers.EmissionDirection = Enum.NormalId.Top
	if anchorFlame then
		embers.Parent = anchorFlame
	end
	-- marshmallow sticks leaning on the logs
	for _, sx in ipairs({ -1, 1 }) do
		local stick = part({
			Name = "MallowStick", Size = Vector3.new(0.25, 3.4, 0.25),
			Color = Color3.fromRGB(206, 170, 120), CanCollide = false,
		})
		stick.CFrame = CFrame.new(at + Vector3.new(sx * 2.4, 1.4, -1.6)) * CFrame.Angles(0, 0, math.rad(sx * 35))
		stick.Parent = folder
		local mallow = part({
			Name = "Mallow", Size = Vector3.new(0.8, 0.8, 0.8),
			Color = Color3.fromRGB(255, 250, 240), CanCollide = false,
		})
		mallow.Position = at + Vector3.new(sx * 3.2, 2.6, -1.6)
		mallow.Parent = folder
	end
end

-- A cherry-topped pudding mountain (the book's signature landmark): layered
-- flan stack, cream drips, a snowy cream cap, and a giant glossy cherry.
local function puddingMountain(folder: Instance, at: Vector3, scale: number)
	local layers = {
		{ y = 0, w = 36, h = 14, c = Color3.fromRGB(243, 184, 120) },
		{ y = 9, w = 27, h = 11, c = Color3.fromRGB(250, 204, 138) },
		{ y = 16.5, w = 19, h = 9, c = Color3.fromRGB(255, 222, 168) },
	}
	for i, L in ipairs(layers) do
		local tier = part({
			Name = "MountainTier" .. i, Shape = Enum.PartType.Ball,
			Size = Vector3.new(L.w, L.h, L.w) * scale,
			Position = at + Vector3.new(0, L.y * scale, 0),
			Color = L.c,
		})
		tier.Parent = folder
		-- cream drips spilling over each tier's edge
		for d = 1, 5 do
			local a = math.rad(d * 72 + i * 24)
			local drip = part({
				Name = "Drip", Shape = Enum.PartType.Ball,
				Size = Vector3.new(4.5, 7, 4.5) * scale * (1 - i * 0.16),
				Position = at + Vector3.new(math.cos(a) * L.w * 0.42 * scale, (L.y + L.h * 0.22) * scale, math.sin(a) * L.w * 0.42 * scale),
				Color = Color3.fromRGB(255, 244, 224), CanCollide = false,
			})
			drip.Parent = folder
		end
	end
	local cap = part({
		Name = "CreamCap", Shape = Enum.PartType.Ball, Size = Vector3.new(12, 7, 12) * scale,
		Position = at + Vector3.new(0, 22.5 * scale, 0), Color = Color3.fromRGB(255, 250, 240),
	})
	cap.Parent = folder
	local stem = part({
		Name = "CherryStem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4.5, 0.8, 0.8) * scale,
		Color = Color3.fromRGB(120, 84, 60), CanCollide = false,
	})
	stem.CFrame = CFrame.new(at + Vector3.new(1 * scale, 29.5 * scale, 0)) * CFrame.Angles(0, 0, math.rad(75))
	stem.Parent = folder
	local cherry = part({
		Name = "Cherry", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 7, 7) * scale,
		Position = at + Vector3.new(0, 26.5 * scale, 0), Color = Color3.fromRGB(214, 40, 70),
		Reflectance = 0.12,
	})
	cherry.Parent = folder
	local shine = part({
		Name = "CherryShine", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 2, 1.6) * scale,
		Position = at + Vector3.new(-1.6 * scale, 28.2 * scale, -1.6 * scale),
		Color = Color3.fromRGB(255, 255, 255), Transparency = 0.25, CanCollide = false,
	})
	shine.Parent = folder
end

-- A cozy cottage (body + dome roof + door + glowing window), used to grow the
-- Pudding Hills village. Scale ~0.75-1 keeps them snug next to the original.
local function buildCottage(folder: Instance, base: Vector3, scale: number, bodyColor: Color3, roofColor: Color3)
	local body = part({
		Name = "CottageBody", Size = Vector3.new(18, 13, 15) * scale,
		Position = base + Vector3.new(0, 6.5 * scale, 0), Color = bodyColor,
	})
	body.Parent = folder
	local roof = part({
		Name = "CottageRoof", Shape = Enum.PartType.Ball, Size = Vector3.new(20, 11, 17) * scale,
		Position = base + Vector3.new(0, 14 * scale, 0), Color = roofColor, CanCollide = false,
	})
	roof.Parent = folder
	local door = part({
		Name = "CottageDoor", Size = Vector3.new(4.5, 7, 0.6) * scale,
		Position = base + Vector3.new(0, 3.5 * scale, 7.6 * scale), Color = Color3.fromRGB(196, 150, 120),
	})
	door.Parent = folder
	local window = part({
		Name = "CottageWindow", Size = Vector3.new(3.6, 3.6, 0.6) * scale,
		Position = base + Vector3.new(5.5 * scale, 8 * scale, 7.6 * scale),
		Color = Color3.fromRGB(255, 232, 180), Material = Enum.Material.Neon, Transparency = 0.25,
	})
	window.Parent = folder
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

-- Goo Coast's spread-out shore: a starter trio by the spawn, then friends out
-- at the pier's end, the tide pools, the sandcastle, the lighthouse, the beach
-- huts, the rocky cove, the driftwood, and deep in the southern dunes.
local GOO_PAD_OFFSETS = {
	-- starter cluster by the spawn + guide
	Vector3.new(-10, 2, 26), Vector3.new(12, 2, 22), Vector3.new(0, 2, 10),
	-- at the very end of the pier, over the goo sea (y sits on the planks)
	Vector3.new(0, 3.8, -52),
	-- behind the sandcastle
	Vector3.new(-52, 2, 52),
	-- soaking in the tide pools
	Vector3.new(-34, 2, 12), Vector3.new(36, 2, 16),
	-- beside the lighthouse (far west shore)
	Vector3.new(-70, 2, 10),
	-- behind the beach huts (south-east)
	Vector3.new(46, 2, 62),
	-- in the rocky cove (far east)
	Vector3.new(68, 2, 14),
	-- behind the driftwood on the wet sand
	Vector3.new(-45, 2, 3),
	-- deep in the southern dunes
	Vector3.new(-18, 2, 84),
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
		Name = "GooSea", Size = Vector3.new(320, 1.2, 170), Position = center + Vector3.new(0, 0.2, -75),
		Color = Color3.fromRGB(96, 220, 206), Material = Enum.Material.Glass,
		Reflectance = 0.2, Transparency = 0.2, CanCollide = false,
	})
	sea.Parent = folder
	TweenService:Create(sea, TweenInfo.new(2.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.36 }):Play()

	-- bouncy translucent jelly dunes (arc around the beach, leaving the sea open)
	local jellyColors = { Color3.fromRGB(140, 230, 214), Color3.fromRGB(255, 190, 200), Color3.fromRGB(180, 220, 255), Color3.fromRGB(200, 245, 210) }
	for i = 1, 10 do
		local angle = math.rad(15) + (i / 10) * math.pi * 1.15
		local radius = rng:NextNumber(104, 142)
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
	for i = 0, 16 do
		local z = 20 - i * 6
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
	for _, off in ipairs(SPL({ Vector3.new(-34, 0, 12), Vector3.new(36, 0, 16), Vector3.new(-14, 0, 0) })) do
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
	local castleBase = center + Vector3.new(-70, 0, 61)
	local keep = part({ Name = "CastleKeep", Size = Vector3.new(12, 8, 12), Position = castleBase + Vector3.new(0, 4, 0), Color = sandColor })
	keep.Parent = folder
	for _, off in ipairs({ Vector3.new(-6, 0, -6), Vector3.new(6, 0, -6), Vector3.new(-6, 0, 6), Vector3.new(6, 0, 6) }) do
		local tower = part({ Name = "CastleTower", Size = Vector3.new(5, 11, 5), Position = castleBase + off + Vector3.new(0, 5.5, 0), Color = sandColor })
		tower.Parent = folder
		local coneTop = part({ Name = "CastleTop", Shape = Enum.PartType.Ball, Size = Vector3.new(5.4, 4, 5.4), Position = castleBase + off + Vector3.new(0, 12, 0), Color = Color3.fromRGB(255, 150, 170) })
		coneTop.Parent = folder
	end

	-- ── Rolling goo waves (the book's cresting sea): translucent swells that
	-- breathe up and down with foam caps, plus one tiny wave-rider statue ────
	local waveSpots = SPL({
		Vector3.new(-44, 0, -70), Vector3.new(10, 0, -92), Vector3.new(52, 0, -64), Vector3.new(-12, 0, -56),
	})
	for i, off in ipairs(waveSpots) do
		local pos = center + off
		local swell = part({
			Name = "GooWave" .. i, Shape = Enum.PartType.Ball,
			Size = Vector3.new(22, 9, 14),
			Position = pos + Vector3.new(0, -2.5, 0),
			Color = Color3.fromRGB(110, 226, 210), Material = Enum.Material.Glass,
			Transparency = 0.3, Reflectance = 0.15, CanCollide = false, CastShadow = false,
		})
		swell.Parent = folder
		local foam = part({
			Name = "WaveFoam" .. i, Shape = Enum.PartType.Ball,
			Size = Vector3.new(16, 2.4, 9),
			Position = pos + Vector3.new(0, 1.4, 0),
			Color = Color3.fromRGB(240, 252, 250), Transparency = 0.15, CanCollide = false, CastShadow = false,
		})
		foam.Parent = folder
		local lift = 2.4 + (i % 2)
		local info = TweenInfo.new(2.8 + i * 0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		TweenService:Create(swell, info, { Position = swell.Position + Vector3.new(0, lift, 0) }):Play()
		TweenService:Create(foam, info, { Position = foam.Position + Vector3.new(0, lift, 0) }):Play()
	end
	-- the little wave-rider (straight from the book spread): a mini goo friend
	-- balanced on the closest crest
	local stash = game:GetService("ServerStorage"):FindFirstChild("MeshBodies")
	local riderTemplate = stash and stash:FindFirstChild("goo_ball")
	if riderTemplate then
		local rider = riderTemplate:Clone()
		rider.Name = "WaveRider"
		rider.Size = rider.Size * 0.55
		rider.CanQuery = false
		rider.CanTouch = false
		rider.CFrame = CFrame.new(center + waveSpots[4] + Vector3.new(0, 4.2, 0)) * CFrame.Angles(0, math.rad(160), math.rad(-12))
		rider.Parent = folder
		TweenService:Create(rider, TweenInfo.new(3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			CFrame = rider.CFrame * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(20)),
		}):Play()
	end

	-- foam-white cloud-bushes on the sand
	for i, off in ipairs(SPL({ Vector3.new(-58, 0, 44), Vector3.new(26, 0, 70), Vector3.new(60, 0, 34), Vector3.new(-26, 0, 62) })) do
		cloudBush(folder, center + off, Color3.fromRGB(248, 252, 250), Color3.fromRGB(255, 190, 200))
	end

	-- drifting glossy bubbles for life
	for i = 1, 14 do
		local sz = rng:NextNumber(1.6, 3.4)
		local pos = center + Vector3.new(rng:NextNumber(-90, 90), rng:NextNumber(3, 8), rng:NextNumber(-100, 72))
		local bubble = part({
			Name = "Bubble", Shape = Enum.PartType.Ball, Size = Vector3.new(sz, sz, sz), Position = pos,
			Color = Color3.fromRGB(200, 245, 255), Material = Enum.Material.Glass, Transparency = 0.4, Reflectance = 0.1, CanCollide = false, CastShadow = false,
		})
		bubble.Parent = folder
		TweenService:Create(bubble, TweenInfo.new(rng:NextNumber(2, 3.5), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = pos + Vector3.new(0, 2.5, 0) }):Play()
	end

	-- ── The spread-out shore: lighthouse, beach huts, umbrellas, driftwood,
	-- a rowboat, and a rocky cove, so the whole beach is worth wandering ─────
	-- A small candy-striped lighthouse anchors the far western shore.
	local lhBase = center + Vector3.new(-110, 0, 0)
	local lhColors = { Color3.fromRGB(255, 250, 245), Color3.fromRGB(248, 150, 170) }
	for i = 0, 2 do
		local ring = part({
			Name = "LighthouseRing", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4.6, 5.4 - i * 0.7, 5.4 - i * 0.7),
			Color = lhColors[(i % 2) + 1],
		})
		ring.CFrame = CFrame.new(lhBase + Vector3.new(0, 2.3 + i * 4.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Parent = folder
	end
	local lamp = part({
		Name = "LighthouseLamp", Shape = Enum.PartType.Ball, Size = Vector3.new(3.2, 3.2, 3.2),
		Position = lhBase + Vector3.new(0, 15.6, 0), Color = Color3.fromRGB(255, 232, 160),
		Material = Enum.Material.Neon, CanCollide = false,
	})
	lamp.Parent = folder
	local lampLight = Instance.new("PointLight")
	lampLight.Color = Color3.fromRGB(255, 226, 150)
	lampLight.Brightness = 2
	lampLight.Range = 40
	lampLight.Parent = lamp

	-- Striped beach huts on the south-eastern sand.
	for hi, hut in ipairs({ { Vector3.new(64, 0, 84), Color3.fromRGB(150, 220, 224) }, { Vector3.new(-3, 0, 99), Color3.fromRGB(255, 190, 200) } }) do
		local hutBase, hutColor = hut[1] + center, hut[2]
		local cabin = part({
			Name = "HutBody" .. hi, Size = Vector3.new(8, 8, 7),
			Position = hutBase + Vector3.new(0, 4, 0), Color = Color3.fromRGB(255, 250, 244),
		})
		cabin.Parent = folder
		local roof = part({
			Name = "HutRoof" .. hi, Shape = Enum.PartType.Ball, Size = Vector3.new(9.4, 4.6, 8.4),
			Position = hutBase + Vector3.new(0, 8.8, 0), Color = hutColor, CanCollide = false,
		})
		roof.Parent = folder
		local hutDoor = part({
			Name = "HutDoor" .. hi, Size = Vector3.new(3, 5.4, 0.5),
			Position = hutBase + Vector3.new(0, 2.7, -3.6), Color = hutColor,
		})
		hutDoor.Parent = folder
	end

	-- Beach umbrellas with towels.
	for ui, u in ipairs({ { Vector3.new(-26, 0, 78), Color3.fromRGB(255, 190, 120) }, { Vector3.new(35, 0, 70), Color3.fromRGB(170, 200, 255) } }) do
		local uBase, uColor = u[1] + center, u[2]
		local pole = part({
			Name = "UmbrellaPole" .. ui, Size = Vector3.new(0.5, 7, 0.5),
			Position = uBase + Vector3.new(0, 3.5, 0), Color = Color3.fromRGB(250, 245, 240), CanCollide = false,
		})
		pole.Parent = folder
		local canopy = part({
			Name = "UmbrellaTop" .. ui, Shape = Enum.PartType.Ball, Size = Vector3.new(8, 3, 8),
			Position = uBase + Vector3.new(0, 7, 0), Color = uColor, CanCollide = false,
		})
		canopy.Parent = folder
		local towel = part({
			Name = "Towel" .. ui, Size = Vector3.new(4, 0.18, 7),
			Position = uBase + Vector3.new(4.4, 0.1, 0.5), Color = uColor, CanCollide = false, CanQuery = false,
		})
		towel.Parent = folder
	end

	-- Driftwood + a beached rowboat on the wet sand by the goo sea.
	for di, d in ipairs({ { Vector3.new(-58, 0, -3), 24 }, { Vector3.new(52, 0, -6), -18 } }) do
		local wood = part({
			Name = "Driftwood" .. di, Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, 1.6, 1.6),
			Color = Color3.fromRGB(214, 190, 160),
		})
		wood.CFrame = CFrame.new(d[1] + center + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, math.rad(d[2]), math.rad(90))
		wood.Parent = folder
	end
	local boatBase = center + Vector3.new(-32, 0, -9)
	local hullBottom = part({
		Name = "BoatHull", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 2.2, 8.5),
		Color = Color3.fromRGB(196, 150, 110),
	})
	hullBottom.CFrame = CFrame.new(boatBase + Vector3.new(0, 1.0, 0)) * CFrame.Angles(0, math.rad(30), 0)
	hullBottom.Parent = folder
	local boatSeat = part({
		Name = "BoatSeat", Size = Vector3.new(4.2, 0.5, 1.2),
		Color = Color3.fromRGB(226, 186, 140), CanCollide = false,
	})
	boatSeat.CFrame = CFrame.new(boatBase + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, math.rad(30), 0)
	boatSeat.Parent = folder

	-- A little rocky cove on the far eastern shore.
	for ri, rock in ipairs({ { Vector3.new(93, 0, 12), 5.5 }, { Vector3.new(104, 0, 23), 4.4 }, { Vector3.new(102, 0, 9), 3.2 } }) do
		local stone = part({
			Name = "CoveRock" .. ri, Shape = Enum.PartType.Ball,
			Size = Vector3.new(rock[2], rock[2] * 0.8, rock[2]),
			Position = rock[1] + center + Vector3.new(0, rock[2] * 0.25, 0),
			Color = Color3.fromRGB(196, 186, 210),
		})
		stone.Parent = folder
	end
	local arch = part({
		Name = "CoveArch", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, 7, 7),
		Color = Color3.fromRGB(206, 196, 220), CanCollide = false,
	})
	arch.CFrame = CFrame.new(center + Vector3.new(99, 5, 17)) * CFrame.Angles(math.rad(90), 0, 0)
	arch.Parent = folder

	-- Boardwalk plank paths along the shore (spawn -> pier, west to the
	-- lighthouse, east to the cove).
	local plankColor = Color3.fromRGB(226, 196, 150)
	ribbonPath(folder, { center + Vector3.new(0, 0, 30), center + Vector3.new(0, 0, 22) }, 4, plankColor)
	ribbonPath(folder, { center + SP(Vector3.new(-8, 0, 26)), center + SP(Vector3.new(-40, 0, 16)), center + SP(Vector3.new(-66, 0, 6)), center + Vector3.new(-102, 0, 4) }, 3, plankColor)
	ribbonPath(folder, { center + SP(Vector3.new(8, 0, 26)), center + SP(Vector3.new(40, 0, 18)), center + SP(Vector3.new(60, 0, 14)) }, 3, plankColor)
	ribbonPath(folder, { center + SP(Vector3.new(-6, 0, 34)), center + SP(Vector3.new(-44, 0, 48)) }, 3, plankColor) -- to the sandcastle
	ribbonPath(folder, { center + SP(Vector3.new(20, 0, 32)), center + SP(Vector3.new(44, 0, 56)) }, 3, plankColor) -- on to the beach huts

	-- ── Beauty pass (2026-06-12): sea life + horizon + plaza ────────────────
	local fishTints = { Color3.fromRGB(140, 230, 214), Color3.fromRGB(255, 190, 200), Color3.fromRGB(180, 220, 255) }
	for i, off in ipairs({
		Vector3.new(-40, 10, -100), Vector3.new(40, 12, -120), Vector3.new(0, 9, -70),
		Vector3.new(60, 11, -95), Vector3.new(-55, 13, -60),
	}) do
		gooFish(folder, center + off, fishTints[(i % #fishTints) + 1], i * 0.7)
	end
	sherbetIsle(folder, center + Vector3.new(-85, 0, -128), Color3.fromRGB(255, 170, 195))
	sherbetIsle(folder, center + Vector3.new(95, 0, -118), Color3.fromRGB(170, 200, 255))
	rockCandyStack(folder, center + Vector3.new(88, 0, 30))
	rockCandyStack(folder, center + Vector3.new(110, 0, -4))
	taffyFountain(folder, center + Vector3.new(55, 0, -28))
	for _, lampAt in ipairs({ Vector3.new(-30, 0, 24), Vector3.new(30, 0, 26), Vector3.new(-70, 0, 30) }) do
		gumballLamp(folder, center + lampAt)
	end
	macaronBalloon(folder, center, 70, 100, Color3.fromRGB(150, 220, 224), Color3.fromRGB(255, 250, 240), math.pi / 2)

	-- gameplay infrastructure: own coastal pads + themed capsule/guide + shard + travel
	local pads = {}
	for _, off in ipairs(GOO_PAD_OFFSETS) do
		local pos = center + SP(off)
		local pad = part({ Name = "Pad", Size = Vector3.new(6, 0.4, 6), Position = pos - Vector3.new(0, 1.8, 0), Color = Color3.fromRGB(150, 232, 224), Transparency = 0.2, CanCollide = false })
		pad.Parent = folder
		pads[#pads + 1] = CFrame.new(pos)
	end
	makeLandingPad(folder, zone.spawn, Color3.fromRGB(120, 220, 224))
	-- the capsule keeps the sandcastle company (the western beach district)
	local capsulePrompt = makeCapsule(folder, center + Vector3.new(-55, 3.5, 49), "Goo Capsule", Color3.fromRGB(120, 220, 200))
	local guidePrompt = makeGuide(folder, center + Vector3.new(15, 2.5, 20), "Bloop the Goo Guide", Color3.fromRGB(150, 226, 234))
	makeShardPedestal(folder, zone.shardSpot, Color3.fromRGB(120, 220, 224))
	-- travel plaza out by the rocky cove (east shore), not on the spawn sand
	local travelPads = buildTravelHub(folder, center + Vector3.new(75, 0, -44), "Goo Coast")

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

-- Moonlit Hollow's spread-out glade: a starter trio by the spawn, then friends
-- between the giant mushrooms, around the moonpool rim, behind the cozy log, by
-- the little mushroom cottages, at the stargazing circle, and out in the
-- firefly meadow.
local MOON_PAD_OFFSETS = {
	-- starter cluster by the spawn + guide
	Vector3.new(-8, 2, 24), Vector3.new(12, 2, 20), Vector3.new(0, 2, 6),
	-- tucked in the giant mushroom grove (west)
	Vector3.new(-52, 2, 8), Vector3.new(-40, 2, 30),
	-- behind the cozy log (east)
	Vector3.new(46, 2, 26),
	-- on the moonpool rim
	Vector3.new(-18, 2, -26), Vector3.new(18, 2, -28),
	-- beside the mushroom cottages
	Vector3.new(-62, 2, 68), Vector3.new(68, 2, -14),
	-- at the stargazing circle (far north-east)
	Vector3.new(40, 2, -76),
	-- out in the firefly meadow (south-east)
	Vector3.new(28, 2, 64),
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

	-- twilight ground (a touch deeper, so the land's glow-props actually pop)
	local ground = part({ Name = "Ground", Size = Vector3.new(320, 4, 320), Position = center + Vector3.new(0, -2, 0), Color = Color3.fromRGB(106, 96, 148) })
	ground.Parent = folder

	-- the Moonpool: a still, mirror-glossy pool, ringed by a soft glow
	local pool = part({
		Name = "Moonpool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 46, 46),
		Color = Color3.fromRGB(70, 80, 140), Material = Enum.Material.Glass, Reflectance = 0.5, Transparency = 0.1, CanCollide = false,
	})
	pool.CFrame = CFrame.new(center + Vector3.new(0, 0.2, -17)) * CFrame.Angles(0, 0, math.rad(90))
	pool.Parent = folder
	local ring = part({
		Name = "PoolGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 52, 52),
		Color = Color3.fromRGB(172, 162, 255), Material = Enum.Material.Neon, Transparency = 0.7, CanCollide = false,
	})
	ring.CFrame = CFrame.new(center + Vector3.new(0, 0.12, -17)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder

	-- the Moon, low over the pool so it reflects — a CRESCENT, exactly as it
	-- appears in every night spread of the book (an arc of glowing beads,
	-- fattest in the middle, with the bite facing the stars)
	local moonCenter = center + Vector3.new(0, 72, -133)
	local moonAnchor = part({
		Name = "Moon", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4),
		Position = moonCenter, Transparency = 1,
		CanCollide = false, CanQuery = false, CastShadow = false,
	})
	moonAnchor.Parent = folder
	for i = 0, 10 do
		local a = math.rad(120 + i * 24)
		local d = 8 - math.abs(i - 5) * 1
		local bead = part({
			Name = "MoonBead", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d),
			Position = moonCenter + Vector3.new(math.cos(a) * 9, math.sin(a) * 9, 0),
			Color = Color3.fromRGB(236, 234, 255), Material = Enum.Material.Neon,
			CanCollide = false, CanQuery = false, CastShadow = false,
		})
		bead.Parent = folder
	end
	local moonLight = Instance.new("PointLight")
	moonLight.Color = Color3.fromRGB(200, 200, 255)
	moonLight.Brightness = 1.4
	moonLight.Range = 90
	moonLight.Parent = moonAnchor

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
		mushroom(center + Vector3.new(rng:NextNumber(-90, -49), 0, rng:NextNumber(-17, 61)), rng:NextNumber(7, 12), rng:NextNumber(6, 10), capColors[((i - 1) % #capColors) + 1])
	end
	-- smaller mushrooms dotted around the glade
	for i = 1, 10 do
		mushroom(center + Vector3.new(rng:NextNumber(-81, 81), 0, rng:NextNumber(-75, 75)), rng:NextNumber(2.5, 4.5), rng:NextNumber(2.4, 3.6), capColors[((i - 1) % #capColors) + 1])
	end

	-- a cozy fallen log on the east side
	local log = part({ Name = "CozyLog", Shape = Enum.PartType.Cylinder, Size = Vector3.new(22, 5, 5), Color = Color3.fromRGB(150, 116, 92) })
	log.CFrame = CFrame.new(center + Vector3.new(58, 2.3, 29)) * CFrame.Angles(0, math.rad(35), 0)
	log.Parent = folder

	-- glowing twilight flowers scattered low to the ground
	for _ = 1, 12 do
		local flower = part({
			Name = "GlowFlower", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4),
			Position = center + Vector3.new(rng:NextNumber(-84, 84), 0.6, rng:NextNumber(-84, 84)),
			Color = capColors[rng:NextInteger(1, #capColors)], Material = Enum.Material.Neon, CanCollide = false, CastShadow = false,
		})
		flower.Parent = folder
	end

	-- ── The spread-out glade: mushroom cottages, a stargazing circle, and
	-- lantern-lit stepping-stone paths (night-friendly wayfinding) ───────────
	-- Three tiny mushroom cottages with round doors and warm windows.
	for ci, cot in ipairs({
		{ Vector3.new(-78, 0, 87), Color3.fromRGB(235, 120, 140) },
		{ Vector3.new(90, 0, -12), Color3.fromRGB(150, 200, 255) },
		{ Vector3.new(-29, 0, -93), Color3.fromRGB(190, 130, 255) },
	}) do
		local cBase, capColor = cot[1] + center, cot[2]
		local stem = part({
			Name = "MushroomHouse" .. ci, Shape = Enum.PartType.Cylinder, Size = Vector3.new(7, 7.5, 7.5),
			Color = Color3.fromRGB(248, 240, 230),
		})
		stem.CFrame = CFrame.new(cBase + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
		stem.Parent = folder
		local cap = part({
			Name = "MushroomHouseCap" .. ci, Shape = Enum.PartType.Ball, Size = Vector3.new(11, 6, 11),
			Position = cBase + Vector3.new(0, 8.4, 0), Color = capColor, CanCollide = false,
		})
		cap.Parent = folder
		for di = 1, 3 do
			local a = math.rad(di * 110 + ci * 40)
			local dot = part({
				Name = "CapDot", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.1, 1.6),
				Position = cBase + Vector3.new(math.cos(a) * 3.4, 9.6, math.sin(a) * 3.4),
				Color = Color3.fromRGB(255, 250, 240), CanCollide = false,
			})
			dot.Parent = folder
		end
		local door = part({
			Name = "RoundDoor" .. ci, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 4.2, 4.2),
			Color = Color3.fromRGB(150, 116, 92),
		})
		door.CFrame = CFrame.new(cBase + Vector3.new(0, 2.2, -3.6)) * CFrame.Angles(0, math.rad(90), 0)
		door.Parent = folder
		local windowGlow = part({
			Name = "CottageWindow" .. ci, Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 0.5),
			Position = cBase + Vector3.new(2.4, 4.4, -3.5), Color = Color3.fromRGB(255, 226, 150),
			Material = Enum.Material.Neon, CanCollide = false,
		})
		windowGlow.Parent = folder
	end

	-- The stargazing circle: a ring of mossy stones around a blanket, far
	-- north-east where the sky is widest.
	local starC = center + Vector3.new(70, 0, -101)
	for i = 1, 6 do
		local a = math.rad(i * 60)
		local stone = part({
			Name = "StarStone", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 1.8, 2.6),
			Position = starC + Vector3.new(math.cos(a) * 7, 0.7, math.sin(a) * 7),
			Color = Color3.fromRGB(170, 165, 205),
		})
		stone.Parent = folder
	end
	local blanket = part({
		Name = "StarBlanket", Size = Vector3.new(7, 0.2, 7),
		Position = starC + Vector3.new(0, 0.12, 0), Color = Color3.fromRGB(120, 110, 180),
		CanCollide = false, CanQuery = false,
	})
	blanket.Parent = folder

	-- Lantern posts along the ways (warm pools of light for little explorers).
	for _, lp in ipairs(SPL({
		Vector3.new(0, 0, 16), Vector3.new(-28, 0, -2), Vector3.new(-48, 0, 34),
		Vector3.new(22, 0, 28), Vector3.new(52, 0, 8), Vector3.new(16, 0, -44),
	})) do
		local lBase = lp + center
		local post = part({
			Name = "LanternPost", Size = Vector3.new(0.6, 5.5, 0.6),
			Position = lBase + Vector3.new(0, 2.75, 0), Color = Color3.fromRGB(120, 100, 110),
		})
		post.Parent = folder
		local lantern = part({
			Name = "Lantern", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.8, 1.5),
			Position = lBase + Vector3.new(0, 5.9, 0), Color = Color3.fromRGB(255, 226, 150),
			Material = Enum.Material.Neon, CanCollide = false,
		})
		lantern.Parent = folder
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 220, 160)
		glow.Brightness = 1.3
		glow.Range = 17
		glow.Parent = lantern
	end

	-- Glowing stepping-stone paths from the spawn to every pocket.
	local stoneColors = { Color3.fromRGB(186, 164, 230), Color3.fromRGB(150, 226, 210) }
	steppingStones(folder, { center + Vector3.new(0, 0, 30), center + SP(Vector3.new(0, 0, -2)) }, stoneColors) -- to the moonpool
	steppingStones(folder, { center + SP(Vector3.new(-12, 0, -6)), center + SP(Vector3.new(-44, 0, 8)) }, stoneColors) -- to the grove
	steppingStones(folder, { center + SP(Vector3.new(-48, 0, 22)), center + SP(Vector3.new(-52, 0, 52)), center + Vector3.new(-78, 0, 80) }, stoneColors) -- grove to cottage
	steppingStones(folder, { center + SP(Vector3.new(10, 0, 28)), center + SP(Vector3.new(40, 0, 24)) }, stoneColors) -- to the cozy log
	steppingStones(folder, { center + SP(Vector3.new(50, 0, 16)), center + SP(Vector3.new(58, 0, 0)), center + Vector3.new(88, 0, -8) }, stoneColors) -- log to cottage
	steppingStones(folder, { center + SP(Vector3.new(12, 0, -34)), center + SP(Vector3.new(42, 0, -64)), center + Vector3.new(66, 0, -97) }, stoneColors) -- to the stargazing circle

	-- ── The storybook forest: gnarled (but friendly) trees ringing the glade,
	-- dark border mounds with cozy lit windows, and the Sparkle-fall ─────────
	-- proper twilight trees: tall cylinder trunks (slight lean), a branch stub,
	-- and a BIG fluffy moonlit canopy — same recipe that makes the orchard read
	-- as trees, recolored for night
	local trunkColor = Color3.fromRGB(96, 80, 118)
	local canopyColors2 = { Color3.fromRGB(150, 132, 205), Color3.fromRGB(126, 118, 188), Color3.fromRGB(172, 148, 222) }
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = rng:NextNumber(99, 148)
		local base = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local scale = rng:NextNumber(0.9, 1.35)
		local trunkH = 10 * scale
		local lean = rng:NextNumber(-8, 8)
		local trunk = part({
			Name = "MoonTrunk", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(trunkH, 2.4 * scale, 2.4 * scale), Color = trunkColor,
		})
		trunk.CFrame = CFrame.new(base + Vector3.new(0, trunkH / 2, 0)) * CFrame.Angles(0, 0, math.rad(90 + lean))
		trunk.Parent = folder
		local branch = part({
			Name = "MoonBranch", Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4.5 * scale, 1 * scale, 1 * scale), Color = trunkColor, CanCollide = false,
		})
		branch.CFrame = CFrame.new(base + Vector3.new(1.8 * scale, trunkH * 0.62, 0)) * CFrame.Angles(0, 0, math.rad(38))
		branch.Parent = folder
		-- a generous 4-puff canopy (the bit that makes it read TREE)
		local canopyColor = canopyColors2[(i % #canopyColors2) + 1]
		local crownY = trunkH + 1.6 * scale
		for _, puff in ipairs({
			{ Vector3.new(0, 0, 0), 10 }, { Vector3.new(3.6, -1.2, 1.4), 7 },
			{ Vector3.new(-3.2, -1, -1.6), 7 }, { Vector3.new(0.6, 3, 0), 6.5 },
		}) do
			local d = puff[2] * scale
			local p = part({
				Name = "MoonCanopy", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d * 0.85, d),
				Position = base + Vector3.new(puff[1].X * scale, crownY + puff[1].Y * scale, puff[1].Z * scale),
				Color = canopyColor, CanCollide = false,
			})
			p.Parent = folder
		end
		-- a few firefly-lit flecks nestled in the leaves
		for f = 1, 2 do
			local fleck = part({
				Name = "CanopyFleck", Shape = Enum.PartType.Ball, Size = Vector3.new(0.7, 0.7, 0.7),
				Position = base + Vector3.new(rng:NextNumber(-3, 3), crownY + rng:NextNumber(-1, 2.5), rng:NextNumber(-3, 3)),
				Color = Color3.fromRGB(255, 234, 170), Material = Enum.Material.Neon, CanCollide = false, CastShadow = false,
			})
			fleck.Parent = folder
		end
	end

	-- ── Midfield life (Moonlit felt empty between the pool and the ring) ────
	-- crystal clusters: little glowing twilight gems
	for i, spot in ipairs(SPL({
		Vector3.new(-26, 0, 14), Vector3.new(30, 0, -12), Vector3.new(12, 0, 46),
		Vector3.new(-44, 0, -18), Vector3.new(52, 0, 22), Vector3.new(-12, 0, -48),
	})) do
		local cc = { Color3.fromRGB(190, 150, 255), Color3.fromRGB(140, 220, 235), Color3.fromRGB(255, 170, 220) }
		for s = 1, 3 do
			local h = rng:NextNumber(1.6, 3.4)
			local shard = part({
				Name = "TwilightCrystal", Size = Vector3.new(0.9, h, 0.9),
				Color = cc[(i + s) % #cc + 1], Material = Enum.Material.Neon, Transparency = 0.2,
				CanCollide = false, CastShadow = false,
			})
			shard.CFrame = CFrame.new(center + spot + Vector3.new((s - 2) * 1.1, h / 2 - 0.2, rng:NextNumber(-0.8, 0.8)))
				* CFrame.Angles(math.rad(rng:NextNumber(-14, 14)), 0, math.rad(rng:NextNumber(-14, 14)))
			shard.Parent = folder
		end
	end
	-- star puddles: tiny mirror pools catching the moon
	for _, spot in ipairs(SPL({ Vector3.new(22, 0, 18), Vector3.new(-36, 0, 36), Vector3.new(44, 0, -34), Vector3.new(-18, 0, 58) })) do
		local puddle = part({
			Name = "StarPuddle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 7, 7),
			Color = Color3.fromRGB(90, 96, 158), Material = Enum.Material.Glass,
			Reflectance = 0.45, Transparency = 0.12, CanCollide = false,
		})
		puddle.CFrame = CFrame.new(center + spot + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
		puddle.Parent = folder
	end
	-- mossy dream-rocks with glowing caps
	for i, spot in ipairs(SPL({ Vector3.new(-52, 0, 44), Vector3.new(58, 0, -8), Vector3.new(8, 0, -38), Vector3.new(-30, 0, -56), Vector3.new(36, 0, 56) })) do
		local d = rng:NextNumber(3.4, 6)
		local rock = part({
			Name = "DreamRock", Shape = Enum.PartType.Ball, Size = Vector3.new(d, d * 0.7, d),
			Position = center + spot + Vector3.new(0, d * 0.22, 0), Color = Color3.fromRGB(120, 112, 156),
		})
		rock.Parent = folder
		local moss = part({
			Name = "GlowMoss", Shape = Enum.PartType.Ball, Size = Vector3.new(d * 0.7, d * 0.3, d * 0.7),
			Position = center + spot + Vector3.new(d * 0.12, d * 0.52, 0),
			Color = Color3.fromRGB(150, 235, 200), Material = Enum.Material.Neon, Transparency = 0.35,
			CanCollide = false, CastShadow = false,
		})
		moss.Parent = folder
	end
	-- two more lantern posts so the midfield glows at kid height
	for _, lp2 in ipairs(SPL({ Vector3.new(-24, 0, 40), Vector3.new(34, 0, -36) })) do
		local lBase = lp2 + center
		local post = part({
			Name = "LanternPost", Size = Vector3.new(0.6, 5.5, 0.6),
			Position = lBase + Vector3.new(0, 2.75, 0), Color = Color3.fromRGB(120, 100, 110),
		})
		post.Parent = folder
		local lantern = part({
			Name = "Lantern", Shape = Enum.PartType.Ball, Size = Vector3.new(1.5, 1.8, 1.5),
			Position = lBase + Vector3.new(0, 5.9, 0), Color = Color3.fromRGB(255, 226, 150),
			Material = Enum.Material.Neon, CanCollide = false,
		})
		lantern.Parent = folder
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 220, 160)
		glow.Brightness = 1.3
		glow.Range = 17
		glow.Parent = lantern
	end

	-- dark border mounds with little glowing windows ("someone tiny lives there")
	for i, m in ipairs({
		{ Vector3.new(-138, 0, -109), 34 }, { Vector3.new(145, 0, 102), 40 }, { Vector3.new(138, 0, -138), 30 },
	}) do
		local at, d = center + m[1], m[2]
		local mound = part({
			Name = "BorderMound" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(d, d * 0.8, d),
			Position = at + Vector3.new(0, -d * 0.28, 0), Color = Color3.fromRGB(96, 86, 132), CanCollide = false,
		})
		mound.Parent = folder
		for w = 1, 3 do
			local wa = math.rad(w * 34 - 70)
			local win = part({
				Name = "MoundWindow", Size = Vector3.new(1.3, 1.8, 0.6),
				Position = at + Vector3.new(math.cos(wa) * d * 0.42, d * 0.12 + (w % 2) * 2.4, math.sin(wa) * d * 0.42),
				Color = Color3.fromRGB(255, 226, 150), Material = Enum.Material.Neon, CanCollide = false,
			})
			win.Parent = folder
		end
	end

	-- the Sparkle-fall: rare golden streaks falling across the night sky (the
	-- book's opening page, forever happening gently over the Hollow)
	local skyField = part({
		Name = "SparkleFall", Size = Vector3.new(290, 1, 290),
		Position = center + Vector3.new(0, 150, 0), Transparency = 1, CanCollide = false, CanQuery = false,
	})
	skyField.Parent = folder
	local fall = Instance.new("ParticleEmitter")
	fall.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	fall.LightEmission = 1
	fall.LightInfluence = 0
	fall.Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 244, 210))
	fall.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2.6), NumberSequenceKeypoint.new(1, 0),
	})
	fall.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.85, 0.4), NumberSequenceKeypoint.new(1, 1),
	})
	fall.Lifetime = NumberRange.new(2.4, 3.2)
	fall.Rate = 0.12 -- one streak every ~8 seconds: rare enough to feel magic
	fall.Speed = NumberRange.new(42, 55)
	fall.EmissionDirection = Enum.NormalId.Bottom
	fall.SpreadAngle = Vector2.new(24, 24)
	fall.Acceleration = Vector3.new(-6, -10, 0)
	fall.Parent = skyField

	-- lavender cloud-bushes in the glade
	for i, off in ipairs(SPL({ Vector3.new(-30, 0, 52), Vector3.new(34, 0, 48), Vector3.new(-58, 0, -30), Vector3.new(56, 0, 38) })) do
		cloudBush(folder, center + off, Color3.fromRGB(232, 226, 246), Color3.fromRGB(190, 160, 240))
	end

	-- drifting fireflies
	local fField = part({ Name = "Fireflies", Size = Vector3.new(260, 1, 260), Position = center + Vector3.new(0, 4, 0), Transparency = 1, CanCollide = false, CanQuery = false })
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

	-- ── Beauty pass (2026-06-12): canon night magic ─────────────────────────
	crescentSwing(folder, center + Vector3.new(52, 0, -80), center + Vector3.new(0, 0, -17))
	lanternString(folder, center + Vector3.new(-78, 9, 84), center + Vector3.new(-48, 8, 52), 0)
	lanternString(folder, center + Vector3.new(90, 9, -10), center + Vector3.new(70, 8, -38), 0.6)
	lanternString(folder, center + Vector3.new(-29, 9, -90), center + Vector3.new(0, 8, -50), 1.2)
	auroraRibbons(folder, center)
	cocoaCampfire(folder, center + Vector3.new(80, 0, -92))

	-- gameplay infrastructure: own glade pads + themed capsule/guide + shard + travel
	local pads = {}
	for _, off in ipairs(MOON_PAD_OFFSETS) do
		local pos = center + SP(off)
		local pad = part({ Name = "Pad", Size = Vector3.new(6, 0.4, 6), Position = pos - Vector3.new(0, 1.8, 0), Color = Color3.fromRGB(186, 164, 230), Transparency = 0.2, CanCollide = false })
		pad.Parent = folder
		pads[#pads + 1] = CFrame.new(pos)
	end
	makeLandingPad(folder, zone.spawn, Color3.fromRGB(196, 166, 255))
	-- the capsule glows beside the cozy log (the glade's eastern district)
	local capsulePrompt = makeCapsule(folder, center + Vector3.new(49, 3.5, 49), "Moonlit Capsule", Color3.fromRGB(150, 120, 210))
	local guidePrompt = makeGuide(folder, center + Vector3.new(-20, 2.5, 23), "Nox the Night Guide", Color3.fromRGB(176, 152, 224))
	makeShardPedestal(folder, zone.shardSpot, Color3.fromRGB(196, 166, 255))
	-- travel plaza up by the stargazing circle (the glade's quiet north), with
	-- the glowing stepping stones already leading the way
	local travelPads = buildTravelHub(folder, center + Vector3.new(52, 0, -142), "Moonlit Hollow")

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
		local radius = hillRng:NextNumber(84, 150)
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

	-- ── Welcome boards: three little picture signs on the spawn pad's north
	-- edge, facing arriving players. Icons first, words tiny — the storybook
	-- "how to play" a 6-year-old can read at a glance. ──────────────────────
	local boardSpecs = {
		{ pos = Vector3.new(-8, 0, 27.5), icon = "👆", line = "Squish sleepy friends!", color = Color3.fromRGB(255, 170, 195) },
		{ pos = Vector3.new(0, 0, 26), icon = "⭐", line = "Earn Sparkle Coins!", color = Color3.fromRGB(255, 210, 120) },
		{ pos = Vector3.new(8, 0, 27.5), icon = "🎁", line = "Collect new friends!", color = Color3.fromRGB(180, 200, 255) },
	}
	for i, spec in ipairs(boardSpecs) do
		local face = CFrame.lookAt(Vector3.new(spec.pos.X, 0, spec.pos.Z), Vector3.new(0, 0, 36))
		local post = part({
			Name = "WelcomePost" .. i, Size = Vector3.new(0.5, 2.6, 0.5),
			Color = Color3.fromRGB(244, 230, 214),
		})
		post.CFrame = face + Vector3.new(0, 1.3, 0)
		post.Parent = folder
		local panel = part({
			Name = "WelcomeBoard" .. i, Size = Vector3.new(4.6, 3.4, 0.4),
			Color = Color3.fromRGB(255, 250, 243),
		})
		panel.CFrame = face + Vector3.new(0, 4.1, 0)
		panel.Parent = folder
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 0
		gui.Brightness = 1.1
		gui.Parent = panel
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = spec.color
		bg.BorderSizePixel = 0
		bg.Parent = gui
		local icon = Instance.new("TextLabel")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.new(1, 0, 0.62, 0)
		icon.Position = UDim2.fromScale(0, 0.05)
		icon.Font = Enum.Font.FredokaOne
		icon.TextScaled = true
		icon.Text = i .. " " .. spec.icon
		icon.TextColor3 = Color3.fromRGB(255, 255, 255)
		icon.TextStrokeColor3 = Color3.fromRGB(120, 90, 110)
		icon.TextStrokeTransparency = 0.6
		icon.Parent = bg
		local line = Instance.new("TextLabel")
		line.BackgroundTransparency = 1
		line.Size = UDim2.new(1, -12, 0.3, 0)
		line.Position = UDim2.new(0, 6, 0.66, 0)
		line.Font = Enum.Font.FredokaOne
		line.TextScaled = true
		line.TextWrapped = true
		line.Text = spec.line
		line.TextColor3 = Color3.fromRGB(96, 74, 96)
		line.Parent = bg
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

	-- Sparkle Capsule machine — out in its own little glade on the windmill
	-- path (districts pass: the spawn meadow stays uncluttered; the First Day
	-- arrow walks new players here).
	local capsuleModel = Instance.new("Model")
	capsuleModel.Name = "SparkleCapsule"
	local capsuleBase = part({
		Name = "Base",
		Size = Vector3.new(6, 7, 6),
		Position = Vector3.new(-17, 3.5, -52),
		Color = Color3.fromRGB(255, 180, 205),
	})
	capsuleBase.Parent = capsuleModel
	local capsuleDome = part({
		Name = "Dome",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6.5, 6.5, 6.5),
		Position = Vector3.new(-17, 8.5, -52),
		Color = Color3.fromRGB(190, 230, 255),
		Transparency = 0.35,
		Material = Enum.Material.Glass,
		CanCollide = false,
	})
	capsuleDome.Parent = capsuleModel
	capsuleModel.PrimaryPart = capsuleBase
	floatingLabel("Sparkle Capsule", Color3.fromRGB(225, 90, 150), capsuleBase, 7.5)

	local capsulePrompt = Instance.new("ProximityPrompt")
	capsulePrompt.ActionText = "Open Sparkle Capsule"
	capsulePrompt.ObjectText = "Sparkle Capsule"
	capsulePrompt.HoldDuration = 0.2
	capsulePrompt.MaxActivationDistance = 14
	capsulePrompt.RequiresLineOfSight = false
	capsulePrompt.Parent = capsuleBase
	capsuleModel.Parent = folder

	-- Soft Dumpling guide — the real card-faithful 3D shape (the same mesh the
	-- squishable Soft Dumpling and the Family guardians use), not a plain ball.
	local guideDef = SquishyData.getById("soft_dumpling")
	local guideModel = SquishyModelFactory.build(guideDef)
	guideModel.Name = "GuideSoftDumpling"
	guideModel:ScaleTo(1.25) -- a little larger than a world friend (she's the greeter)
	for _, gp in ipairs(guideModel:GetDescendants()) do
		if gp:IsA("BasePart") then
			gp.CanCollide = false
			gp.CanQuery = false
		end
	end
	guideModel:PivotTo(CFrame.new(-20, 2, 17))
	local guideBody = guideModel.PrimaryPart
	floatingLabel("Soft Dumpling", Color3.fromRGB(225, 140, 90), guideBody, 4.5)

	local guidePrompt = Instance.new("ProximityPrompt")
	guidePrompt.ActionText = "Talk"
	guidePrompt.ObjectText = "Soft Dumpling"
	guidePrompt.HoldDuration = 0.1
	guidePrompt.MaxActivationDistance = 14
	guidePrompt.RequiresLineOfSight = false
	guidePrompt.Parent = guideBody
	guideModel.Parent = folder

	-- Spawn pads where sleepy squishy friends appear — TRULY spread now: a small
	-- starter cluster by the guide so the first minute is easy, then pockets at
	-- every landmark (village, orchard, windmill field, garden, picnic, far east)
	-- so finding friends is exploring, not standing in one click-cluster.
	local padPositions = {
		-- starter cluster (visible from spawn, by the guide + capsule)
		Vector3.new(-8, 2, 6), Vector3.new(10, 2, 2), Vector3.new(2, 2, -8),
		-- the cottage village lane (south-west)
		Vector3.new(-66, 2, 32), Vector3.new(-80, 2, 44),
		-- under the orchard trees (north-east, by the shard pedestal)
		Vector3.new(44, 2, -34), Vector3.new(56, 2, -48),
		-- the windmill field, deep across the river (north-west)
		Vector3.new(-16, 2, -68), Vector3.new(8, 2, -52),
		-- beside the flower garden (north-west)
		Vector3.new(-34, 2, -46),
		-- the picnic clearing (east, past the boutique)
		Vector3.new(68, 2, 22),
		-- the far eastern rise, on the way to the Goo Coast gate
		Vector3.new(84, 2, -8),
	}
	local pads = {}
	for i, posRaw in ipairs(padPositions) do
		local pos = SP(posRaw)
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
	local riverPts = SPL({
		Vector3.new(-104, 0, 26), Vector3.new(-55, 0, 15), Vector3.new(-16, 0, 23),
		Vector3.new(20, 0, 18), Vector3.new(58, 0, 25), Vector3.new(104, 0, 20),
	})
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
		Position = Vector3.new(0, 0.4, 30),
		Color = Color3.fromRGB(255, 236, 212),
	})
	deck.Parent = bridge
	for _, sx in ipairs({ -1, 1 }) do
		local rail = part({
			Name = "Rail",
			Size = Vector3.new(0.6, 1.6, 18),
			Position = Vector3.new(sx * 5.4, 1.3, 30),
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
	local treeSpots = SPL({
		Vector3.new(40, 0, -30), Vector3.new(52, 0, -22), Vector3.new(34, 0, -42),
		Vector3.new(50, 0, -42), Vector3.new(60, 0, -32), Vector3.new(44, 0, -54),
	})
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
	local cBase = Vector3.new(-70, 0, 49)
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
		ts[2](SP(ts[1]), candy[((i - 1) % #candy) + 1])
	end

	-- Ambient drifting sparkle motes across the whole valley — gentle floating magic.
	local sparkleField = part({
		Name = "ValleySparkles",
		Size = Vector3.new(270, 1, 270),
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
		Position = Vector3.new(0, 92, -64),
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

	-- Background music + per-land ambience are client-side now (SoundScape
	-- crossfades each land's own track as you travel — ids in SoundConfig).

	-- ── Phase A: quest landmarks ─────────────────────────────────────────────
	-- The lost shard's resting place at the orchard's edge (book canon). Empty now;
	-- QuestService floats the shard here once enough friends are woken.
	local shardSpot = Vector3.new(68, 0, -58)
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
	local gx = 145
	for _, sx in ipairs({ -1, 1 }) do
		local post = part({ Name = "Post", Size = Vector3.new(3, 16, 3),
			Position = Vector3.new(gx, 8, 29 + sx * 9), Color = Color3.fromRGB(150, 224, 214) })
		post.Parent = gate
	end
	local arch = part({ Name = "Arch", Size = Vector3.new(3, 3, 24),
		Position = Vector3.new(gx, 17.5, 29), Color = Color3.fromRGB(150, 224, 214) })
	arch.Parent = gate
	local barrier = part({ Name = "Barrier", Size = Vector3.new(1.2, 16, 18),
		Position = Vector3.new(gx, 8, 29), Color = Color3.fromRGB(190, 240, 255),
		Material = Enum.Material.Glass, Transparency = 0.5 })
	barrier.Parent = gate
	floatingLabel("Goo Coast", Color3.fromRGB(40, 150, 150), arch, 4)
	gate.PrimaryPart = arch
	gate.Parent = folder

	-- ── The spread-out valley: a village lane, windmill field, flower garden,
	-- and picnic clearing, so friends have places to hide behind/beside ──────
	-- Two more cottages make a lane with the original (a tiny storybook village).
	buildCottage(folder, Vector3.new(-107, 0, 58), 0.8, Color3.fromRGB(255, 232, 214), Color3.fromRGB(186, 224, 196))
	buildCottage(folder, Vector3.new(-84, 0, 75), 0.72, Color3.fromRGB(244, 234, 255), Color3.fromRGB(206, 186, 240))

	-- A windmill on the far north-western field (the valley's storybook skyline).
	local windmillBase = Vector3.new(-29, 0, -109)
	local tower = part({
		Name = "WindmillTower", Shape = Enum.PartType.Cylinder, Size = Vector3.new(13, 5.5, 5.5),
		Color = Color3.fromRGB(255, 240, 222),
	})
	tower.CFrame = CFrame.new(windmillBase + Vector3.new(0, 6.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	tower.Parent = folder
	local cap = part({
		Name = "WindmillCap", Shape = Enum.PartType.Ball, Size = Vector3.new(6.4, 4.4, 6.4),
		Position = windmillBase + Vector3.new(0, 14, 0), Color = Color3.fromRGB(244, 150, 150), CanCollide = false,
	})
	cap.Parent = folder
	local hub = part({
		Name = "WindmillHub", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4),
		Position = windmillBase + Vector3.new(0, 13, 3.1), Color = Color3.fromRGB(196, 150, 120), CanCollide = false,
	})
	hub.Parent = folder
	for _, ang in ipairs({ 25, 115 }) do -- two crossed sails at a jaunty angle
		local sail = part({
			Name = "WindmillSail", Size = Vector3.new(13, 1.6, 0.4),
			Color = Color3.fromRGB(255, 250, 240), CanCollide = false,
		})
		sail.CFrame = CFrame.new(windmillBase + Vector3.new(0, 13, 3.2)) * CFrame.Angles(0, 0, math.rad(ang))
		sail.Parent = folder
	end

	-- A fenced flower garden north of the river.
	local gardenC = Vector3.new(-41, 0, -81)
	for i = 1, 10 do
		local a = math.rad(i * 36)
		local post = part({
			Name = "FencePost", Size = Vector3.new(0.6, 2.4, 0.6),
			Position = gardenC + Vector3.new(math.cos(a) * 8.5, 1.2, math.sin(a) * 6.5),
			Color = Color3.fromRGB(244, 230, 214),
		})
		post.Parent = folder
	end
	local tulipColors = { Color3.fromRGB(255, 150, 170), Color3.fromRGB(255, 210, 120), Color3.fromRGB(190, 160, 240), Color3.fromRGB(255, 170, 140) }
	for i = 1, 7 do
		local a = math.rad(i * 51)
		local r = (i % 2 == 0) and 4.4 or 2.2
		local at = gardenC + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local stem = part({
			Name = "Stem", Size = Vector3.new(0.3, 1.7, 0.3), Position = at + Vector3.new(0, 0.85, 0),
			Color = Color3.fromRGB(150, 208, 130), CanCollide = false,
		})
		stem.Parent = folder
		local head = part({
			Name = "Tulip", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.3, 1.1),
			Position = at + Vector3.new(0, 2.1, 0), Color = tulipColors[(i % #tulipColors) + 1], CanCollide = false,
		})
		head.Parent = folder
	end

	-- A picnic clearing east of the boutique.
	local picnicC = Vector3.new(90, 0, 43)
	for ix = 0, 1 do
		for iz = 0, 1 do
			local square = part({
				Name = "Blanket", Size = Vector3.new(4, 0.2, 4),
				Position = picnicC + Vector3.new(ix * 4 - 2, 0.12, iz * 4 - 2),
				Color = ((ix + iz) % 2 == 0) and Color3.fromRGB(255, 170, 190) or Color3.fromRGB(255, 247, 240),
				CanCollide = false, CanQuery = false,
			})
			square.Parent = folder
		end
	end
	local basket = part({
		Name = "Basket", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 2.2, 2.2),
		Color = Color3.fromRGB(196, 154, 116),
	})
	basket.CFrame = CFrame.new(picnicC + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
	basket.Parent = folder
	for _, off in ipairs({ Vector3.new(-7, 0, 4), Vector3.new(7, 0, -3) }) do
		local bench = part({
			Name = "LogBench", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6, 1.8, 1.8),
			Color = Color3.fromRGB(206, 170, 120),
		})
		bench.CFrame = CFrame.new(picnicC + off + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, math.rad(35), math.rad(90))
		bench.Parent = folder
	end

	-- Caramel paths so every pocket has a readable trail from the spawn.
	local pathColor = Color3.fromRGB(240, 196, 138)
	ribbonPath(folder, SPL({ Vector3.new(-4, 0, 30), Vector3.new(-40, 0, 38), Vector3.new(-66, 0, 42), Vector3.new(-70, 0, 42) }), 3, pathColor) -- to the village
	ribbonPath(folder, SPL({ Vector3.new(0, 0, 11), Vector3.new(-10, 0, -34), Vector3.new(-18, 0, -68), Vector3.new(-20, 0, -73) }), 3, pathColor) -- over the bridge to the windmill
	ribbonPath(folder, SPL({ Vector3.new(-14, 0, -40), Vector3.new(-24, 0, -50), Vector3.new(-28, 0, -55) }), 2.4, pathColor) -- garden spur
	ribbonPath(folder, SPL({ Vector3.new(6, 0, 8), Vector3.new(38, 0, -28), Vector3.new(45, 0, -38) }), 3, pathColor) -- to the orchard + shard
	ribbonPath(folder, SPL({ Vector3.new(10, 0, 32), Vector3.new(54, 0, 28), Vector3.new(60, 0, 29) }), 3, pathColor) -- past the boutique to the picnic

	-- ── The Sparkle Wheel: a pastel rideable ferris wheel crowning the Market
	-- Meadow — a skyline landmark that pulls little explorers east. Anchored
	-- parts spun by a gentle server loop; Seat objects carry riders.
	do
		local hub = Vector3.new(67, 19, 3)
		local wheelRadius = 13
		-- A-frame legs + axle
		for _, sz in ipairs({ -1, 1 }) do
			for _, sx in ipairs({ -1, 1 }) do
				local leg = part({
					Name = "WheelLeg", Size = Vector3.new(1.4, 24, 1.4),
					Color = Color3.fromRGB(255, 250, 240),
				})
				leg.CFrame = CFrame.new(hub + Vector3.new(sx * 5, -10.5, sz * 3.4)) * CFrame.Angles(math.rad(-sz * 9), 0, math.rad(sx * 13))
				leg.Parent = folder
			end
		end
		local axle = part({
			Name = "WheelAxle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(9, 2, 2),
			Color = Color3.fromRGB(255, 201, 84),
		})
		axle.CFrame = CFrame.new(hub) * CFrame.Angles(0, 0, 0)
		axle.Parent = folder

		-- the spinning ring: spokes + rim segments in one model
		local ring = Instance.new("Model")
		ring.Name = "SparkleWheelRing"
		local ringCenter = part({
			Name = "RingCenter", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3),
			Color = Color3.fromRGB(255, 170, 195), CFrame = CFrame.new(hub),
		})
		ringCenter.Parent = ring
		ring.PrimaryPart = ringCenter
		local rimColors = { Color3.fromRGB(255, 170, 195), Color3.fromRGB(255, 210, 120), Color3.fromRGB(170, 200, 255), Color3.fromRGB(180, 230, 200) }
		for i = 1, 8 do
			local a = math.rad(i * 45)
			local spoke = part({
				Name = "Spoke", Size = Vector3.new(0.6, wheelRadius, 0.6),
				Color = Color3.fromRGB(255, 250, 240), CanCollide = false,
			})
			spoke.CFrame = CFrame.new(hub) * CFrame.Angles(0, 0, a) * CFrame.new(0, wheelRadius / 2, 0)
			spoke.Parent = ring
		end
		for i = 1, 16 do
			local a1 = math.rad(i * 22.5)
			local a2 = math.rad((i + 1) * 22.5)
			local p1 = hub + Vector3.new(math.cos(a1) * wheelRadius, math.sin(a1) * wheelRadius, 0)
			local p2 = hub + Vector3.new(math.cos(a2) * wheelRadius, math.sin(a2) * wheelRadius, 0)
			local seg = part({
				Name = "Rim", Size = Vector3.new((p2 - p1).Magnitude + 0.4, 0.8, 0.8),
				Color = rimColors[(i % #rimColors) + 1], CanCollide = false,
			})
			seg.CFrame = CFrame.lookAt((p1 + p2) / 2, p2) * CFrame.Angles(0, math.rad(90), 0)
			seg.Parent = ring
		end
		ring.Parent = folder

		-- gondolas: pastel baskets with Seats, kept upright by the spin loop
		local gondolas = {}
		for i = 1, 6 do
			local g = Instance.new("Model")
			g.Name = "Gondola" .. i
			local basket = part({
				Name = "Basket", Size = Vector3.new(3.6, 2.2, 3),
				Color = rimColors[(i % #rimColors) + 1],
			})
			basket.Parent = g
			g.PrimaryPart = basket
			local roof = part({
				Name = "GondolaRoof", Shape = Enum.PartType.Ball, Size = Vector3.new(4.2, 2, 3.6),
				Color = Color3.fromRGB(255, 250, 240), CanCollide = false,
			})
			roof.Parent = g
			local seat = Instance.new("Seat")
			seat.Name = "RideSeat"
			seat.Size = Vector3.new(2.4, 0.4, 2)
			seat.Color = Color3.fromRGB(255, 244, 224)
			seat.TopSurface = Enum.SurfaceType.Smooth
			seat.Anchored = true
			seat.Parent = g
			g.Parent = folder
			gondolas[i] = g
		end

		-- the gentle spin (one rotation per minute). angle is an accumulator, so a
		-- Faster Rides boost just turns it a little quicker — no jump. Gentle 1.3x,
		-- shared: fast if any gondola rider wants it.
		local angle = 0
		RunService.Heartbeat:Connect(function(dt)
			local riders = {}
			for _, g in ipairs(gondolas) do
				local s = g:FindFirstChild("RideSeat")
				if s and s:IsA("Seat") and s.Occupant then
					riders[#riders + 1] = s.Occupant
				end
			end
			local mult = RidePrefs.maxSpeedFor(riders, true)
			angle = (angle + dt * math.pi * 2 / 60 * mult) % (math.pi * 2)
			ring:PivotTo(CFrame.new(hub) * CFrame.Angles(0, 0, angle))
			for i, g in ipairs(gondolas) do
				local a = angle + math.rad(i * 60)
				local pos = hub + Vector3.new(math.cos(a) * wheelRadius, math.sin(a) * wheelRadius, 0)
				local basket = g.PrimaryPart
				if basket then
					basket.CFrame = CFrame.new(pos + Vector3.new(0, -2.2, 0))
					local roof = g:FindFirstChild("GondolaRoof")
					if roof then
						roof.CFrame = CFrame.new(pos + Vector3.new(0, -0.6, 0))
					end
					local seat = g:FindFirstChild("RideSeat")
					if seat then
						seat.CFrame = CFrame.new(pos + Vector3.new(0, -1.2, 0))
					end
				end
			end
		end)
		floatingLabel("🎡 Sparkle Wheel", Color3.fromRGB(225, 90, 150), axle, 16)
	end

	-- Cherry pudding mountains on the far ring (the book's signature skyline)
	puddingMountain(folder, Vector3.new(-145, 0, -70), 1.15)
	puddingMountain(folder, Vector3.new(142, 0, -99), 1)
	puddingMountain(folder, Vector3.new(-84, 0, -148), 0.85)

	-- cloud-bushes drifting through the meadows
	local bushFlowers = { Color3.fromRGB(255, 150, 170), Color3.fromRGB(255, 210, 120), Color3.fromRGB(190, 160, 240) }
	for i, at in ipairs(SPL({
		Vector3.new(-24, 0, 26), Vector3.new(34, 0, 20), Vector3.new(-52, 0, -18),
		Vector3.new(20, 0, -44), Vector3.new(64, 0, -28), Vector3.new(-72, 0, 18),
		Vector3.new(8, 0, 44), Vector3.new(-44, 0, 48),
	})) do
		cloudBush(folder, at, Color3.fromRGB(255, 252, 248), bushFlowers[(i % #bushFlowers) + 1])
	end

	-- ── Beauty pass (2026-06-12): candy skyline + path charm ────────────────
	sodaFalls(folder, Vector3.new(-148, 0, 38), Vector3.new(-80, 0, 22)) -- the river's storybook source
	donutArch(folder, Vector3.new(44, 0, 44), Vector3.new(78, 0, 40)) -- astride the picnic path
	candyCaneArch(folder, Vector3.new(-30, 0, 49), Vector3.new(-58, 0, 56))
	candyCaneArch(folder, Vector3.new(-62, 0, 56), Vector3.new(-90, 0, 60))
	candyCaneArch(folder, Vector3.new(-92, 0, 60), Vector3.new(-107, 0, 58))
	for _, lampAt in ipairs({
		Vector3.new(20, 0, 40), Vector3.new(-20, 0, 46), Vector3.new(8, 0, -30),
		Vector3.new(58, 0, -44), Vector3.new(95, 0, 30),
	}) do
		gumballLamp(folder, lampAt)
	end
	macaronBalloon(folder, Vector3.new(0, 0, 0), 85, 105, Color3.fromRGB(255, 170, 195), Color3.fromRGB(255, 226, 150), 0)
	macaronBalloon(folder, Vector3.new(0, 0, 0), 60, 88, Color3.fromRGB(170, 200, 255), Color3.fromRGB(255, 250, 240), math.pi)

	-- Travel Plaza: the hub lives out on the eastern rise (the road toward the
	-- old Goo Coast gate), its own destination instead of spawn furniture.
	local travelPads = buildTravelHub(folder, Vector3.new(116, 0, -23), "Pudding Hills")
	-- a path spur from the picnic meadow out to the plaza
	ribbonPath(folder, { Vector3.new(81, 0, 38), Vector3.new(108, 0, 28) }, 3, pathColor)

	local puddingHills = {
		zone = "Pudding Hills",
		packId = "launch_squishy_foods",
		capsuleKey = "StarterCapsule",
		pads = pads,
		capsulePrompt = capsulePrompt,
		guidePrompt = guidePrompt,
		travelPads = travelPads,
	}

	return { zones = { puddingHills, buildGooCoast(), buildMoonlitHollow() } }
end

return WorldService
