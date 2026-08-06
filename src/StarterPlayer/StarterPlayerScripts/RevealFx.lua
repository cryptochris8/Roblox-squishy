-- RevealFx (CLIENT)
-- Screen-space celebration effects for the Sparkle Capsule ceremony — SquishFx's
-- UI-side sibling. Everything here is pure decoration parented into the reveal's
-- auto-fit stage (so phones scale it for free), everything is budgeted (one
-- sliding-window cap, halved in the compact layout and again in Calm Sparkles
-- mode), and nothing here talks to the server.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local UiTheme = require(script.Parent.UiTheme)

local localPlayer = Players.LocalPlayer

local RevealFx = {}

local SPARKLE_IMAGE = "rbxasset://textures/particles/sparkles_main.dds"
local WHITE = Color3.fromRGB(255, 255, 255)

-- ── FX budget (SquishFx's pattern, sized for UI particles) ───────────────────
local FX_MAX_PER_SECOND = 160
local FX_MIN_BURST = 3
local recentBursts = {} -- sliding one-second window of { at, count }

local function fxScalar(): number
	local s = UiTheme.isCompact() and 0.5 or 1
	if localPlayer:GetAttribute("CalmSparkles") == true then
		s *= 0.5
	end
	return s
end

local function budgetBurst(requested: number): number
	local now = os.clock()
	local total = 0
	for i = #recentBursts, 1, -1 do
		if now - recentBursts[i].at > 1 then
			table.remove(recentBursts, i)
		else
			total += recentBursts[i].count
		end
	end
	local scalar = fxScalar()
	local allowed = math.max(math.floor(requested * scalar + 0.5), FX_MIN_BURST)
	local ceiling = math.floor(FX_MAX_PER_SECOND * scalar)
	if total + allowed > ceiling then
		allowed = math.clamp(ceiling - total, FX_MIN_BURST, allowed)
	end
	table.insert(recentBursts, { at = now, count = allowed })
	return allowed
end

-- ── Primitives ───────────────────────────────────────────────────────────────

-- A radial sparkle burst from `pos` (offset UDim2 inside `parent`).
function RevealFx.burst(parent: GuiObject, pos: UDim2, count: number, color: Color3)
	local n = budgetBurst(count)
	for _ = 1, n do
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = SPARKLE_IMAGE
		img.ImageColor3 = color
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = pos
		local size = math.random(10, 22)
		img.Size = UDim2.fromOffset(size, size)
		img.ZIndex = 8
		img.Rotation = math.random(0, 360)
		img.Parent = parent
		local angle = math.random() * math.pi * 2
		local dist = math.random(50, 150)
		local dur = 0.45 + math.random() * 0.35
		TweenService:Create(img, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = pos + UDim2.fromOffset(math.cos(angle) * dist, math.sin(angle) * dist),
			ImageTransparency = 1,
			Rotation = img.Rotation + math.random(-120, 120),
			Size = UDim2.fromOffset(4, 4),
		}):Play()
		Debris:AddItem(img, dur + 0.1)
	end
end

-- A heart burst (gift + Family reveals). 💖 is on the proven-good glyph list.
function RevealFx.hearts(parent: GuiObject, pos: UDim2, count: number)
	local n = budgetBurst(count)
	for _ = 1, n do
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Text = "💖"
		lbl.TextSize = math.random(16, 26)
		lbl.AnchorPoint = Vector2.new(0.5, 0.5)
		lbl.Position = pos
		lbl.Size = UDim2.fromOffset(30, 30)
		lbl.ZIndex = 8
		lbl.Parent = parent
		local angle = math.random() * math.pi * 2
		local dist = math.random(40, 120)
		local dur = 0.55 + math.random() * 0.4
		TweenService:Create(lbl, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = pos + UDim2.fromOffset(math.cos(angle) * dist, math.sin(angle) * dist - 30),
			TextTransparency = 1,
			Rotation = math.random(-40, 40),
		}):Play()
		Debris:AddItem(lbl, dur + 0.1)
	end
end

-- An expanding ring pulse.
function RevealFx.ring(parent: GuiObject, pos: UDim2, color: Color3)
	local ring = Instance.new("Frame")
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = pos
	ring.Size = UDim2.fromOffset(60, 60)
	ring.ZIndex = 7
	ring.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Transparency = 0.1
	stroke.Parent = ring
	TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(240, 240),
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.6)
end

-- Tiny sparkles slowly circling the capsule. Returns a cleanup function.
-- One rotating container = one tween, however many orbiters ride it.
function RevealFx.orbiters(parent: GuiObject, pos: UDim2, count: number, color: Color3): () -> ()
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = pos
	holder.Size = UDim2.fromOffset(210, 210)
	holder.ZIndex = 6
	holder.Parent = parent
	local n = math.max(3, math.floor(count * fxScalar() + 0.5))
	for i = 1, n do
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = SPARKLE_IMAGE
		img.ImageColor3 = color
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		local angle = (i / n) * math.pi * 2
		img.Position = UDim2.new(0.5, math.cos(angle) * 100, 0.5, math.sin(angle) * 100)
		img.Size = UDim2.fromOffset(12, 12)
		img.ZIndex = 6
		img.Parent = holder
	end
	local spin = TweenService:Create(holder, TweenInfo.new(6, Enum.EasingStyle.Linear), { Rotation = 360 })
	spin:Play()
	return function()
		spin:Cancel()
		holder:Destroy()
	end
end

-- A soft rotating ray wheel behind the risen capsule (legendary+). Layer 2
-- counter-rotates. Returns a cleanup function.
function RevealFx.rays(parent: GuiObject, pos: UDim2, color: Color3, layers: number): () -> ()
	local holders = {}
	local spins = {}
	for layer = 1, math.max(1, layers) do
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = pos
		holder.Size = UDim2.fromOffset(320, 320)
		holder.ZIndex = 5
		holder.Parent = parent
		for i = 1, 8 do
			local ray = Instance.new("Frame")
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.Position = UDim2.fromScale(0.5, 0.5)
			ray.Size = UDim2.fromOffset(4, 320)
			ray.BackgroundColor3 = color
			ray.BackgroundTransparency = 0.75
			ray.BorderSizePixel = 0
			ray.Rotation = (i / 8) * 180 + (layer - 1) * 11
			ray.ZIndex = 5
			ray.Parent = holder
			local g = Instance.new("UIGradient")
			g.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			})
			g.Rotation = 90
			g.Parent = ray
		end
		local dir = (layer % 2 == 1) and 360 or -360
		local spin = TweenService:Create(holder, TweenInfo.new(30, Enum.EasingStyle.Linear), { Rotation = dir })
		spin:Play()
		table.insert(holders, holder)
		table.insert(spins, spin)
	end
	return function()
		for _, s in ipairs(spins) do
			s:Cancel()
		end
		for _, h in ipairs(holders) do
			h:Destroy()
		end
	end
end

-- Star motes drifting up through the ceremony. Returns a stop function.
function RevealFx.starRain(parent: GuiObject, palette: { Color3 }): () -> ()
	local alive = true
	task.spawn(function()
		while alive and parent.Parent do
			local n = budgetBurst(2)
			for _ = 1, n do
				local img = Instance.new("ImageLabel")
				img.BackgroundTransparency = 1
				img.Image = SPARKLE_IMAGE
				img.ImageColor3 = palette[math.random(1, #palette)]
				img.AnchorPoint = Vector2.new(0.5, 0.5)
				img.Position = UDim2.new(math.random(), 0, 1.05, 0)
				local size = math.random(8, 16)
				img.Size = UDim2.fromOffset(size, size)
				img.ImageTransparency = 0.25
				img.ZIndex = 4
				img.Parent = parent
				local dur = 1.4 + math.random() * 0.8
				TweenService:Create(img, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
					Position = UDim2.new(img.Position.X.Scale + (math.random() - 0.5) * 0.08, 0, -0.08, 0),
					ImageTransparency = 1,
					Rotation = math.random(-90, 90),
				}):Play()
				Debris:AddItem(img, dur + 0.1)
			end
			task.wait(0.22)
		end
	end)
	return function()
		alive = false
	end
end

-- A shine sweep travelling across a landed card (a moving white gradient band).
function RevealFx.shineSweep(card: GuiObject, dur: number)
	local band = Instance.new("Frame")
	band.BackgroundColor3 = WHITE
	band.BackgroundTransparency = 0.55
	band.BorderSizePixel = 0
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Rotation = 18
	band.Size = UDim2.new(0, 46, 1.6, 0)
	band.Position = UDim2.new(-0.2, 0, 0.5, 0)
	band.ZIndex = 9
	band.Parent = card
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = band
	TweenService:Create(band, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		Position = UDim2.new(1.2, 0, 0.5, 0),
	}):Play()
	Debris:AddItem(band, dur + 0.1)
end

-- ONE soft white veil per reveal, photosensitivity-capped: never brighter than
-- 0.55 transparency, never shorter than 0.25s total. The ceremony director is
-- responsible for calling this at most once per reveal.
function RevealFx.flash(parent: GuiObject)
	local veil = Instance.new("Frame")
	veil.BackgroundColor3 = WHITE
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Size = UDim2.fromScale(1, 1)
	veil.ZIndex = 10
	veil.Parent = parent
	local inTween = TweenService:Create(veil, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.55 })
	inTween:Play()
	inTween.Completed:Once(function()
		TweenService:Create(veil, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	end)
	Debris:AddItem(veil, 0.4)
end

-- Roll a label's text from one number to another ("+0" -> "+30 Sparkle Coins").
-- onTick (optional) fires for at most `maxTicks` steps — the quiet count chime.
function RevealFx.countUp(label: TextLabel, from: number, to: number, dur: number, format: (number) -> string, onTick: (() -> ())?)
	local maxTicks = 6
	local steps = math.min(math.max(to - from, 1), 12)
	task.spawn(function()
		local ticked = 0
		for i = 1, steps do
			if not label.Parent then
				return
			end
			local value = math.floor(from + (to - from) * (i / steps) + 0.5)
			label.Text = format(value)
			if onTick and ticked < maxTicks then
				ticked += 1
				onTick()
			end
			task.wait(dur / steps)
		end
		if label.Parent then
			label.Text = format(to)
		end
	end)
end

return RevealFx
