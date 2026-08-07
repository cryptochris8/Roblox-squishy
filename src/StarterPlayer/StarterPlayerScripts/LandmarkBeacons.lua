-- LandmarkBeacons (CLIENT)
-- Tier 2 of the Sparkle Beacon system: the NAMES over the balloons that
-- LandmarkService floats above every landmark.
--
-- The whole reason names live here and not on the server is the scar recorded
-- at WorldService.lua:52 — "distant ones just stack into word soup." That is
-- true and unavoidable for a lone BillboardGui, because an offset-sized
-- billboard holds CONSTANT SCREEN SIZE at every distance. Soup is only
-- preventable by a single owner that can see all the labels at once, which is
-- this module. Its guarantees:
--
--   1. Names appear only in a middle distance band. Closer than that, the
--      landmark's own 60-stud world label is already showing (never two names
--      for one place); farther, only the balloon's colour + icon speak.
--   2. At most 3 names on screen at once — ONE on a phone. Nearest first.
--   3. A name is only shown for something roughly in front of you.
--   4. A screen-space collision pass: project every candidate; if two would
--      land within 120px (90 on a phone), the farther one drops to icon-only.
--      That makes overlap structurally impossible, not just unlikely.
--
-- Everything here is cosmetic and client-local. It never talks to the server.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiTheme = require(script.Parent.UiTheme)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local LandmarkConfig = require(Shared:WaitForChild("LandmarkConfig"))

local LandmarkBeacons = {}

local localPlayer = Players.LocalPlayer

local UPDATE_INTERVAL = 0.2 -- the bands only need to change a few times a second
local FORWARD_COS = math.cos(math.rad(56)) -- a ~112-degree forward cone
local NAME_DWELL = 1.6 -- once a name is up, hold it this long (anti-strobe)

local entries = {} -- [landmarkId] = { lm, balloon, gui, icon, name }
local accum = 0
local running = false

local function makeBanner(lm, balloon: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "BeaconBanner"
	gui.Adornee = balloon
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(46, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0)
	gui.Enabled = false
	gui.Parent = balloon

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 4)
	layout.Parent = holder

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(34, 34)
	icon.Font = UiTheme.HeaderFont
	icon.TextSize = 28
	icon.Text = lm.icon
	icon.LayoutOrder = 1
	icon.Parent = holder

	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromOffset(0, 34)
	name.AutomaticSize = Enum.AutomaticSize.X
	name.Font = UiTheme.HeaderFont
	name.TextSize = 19
	name.TextColor3 = Color3.fromRGB(255, 255, 255)
	name.TextStrokeColor3 = UiTheme.Colors.Shade
	name.TextStrokeTransparency = 0.15
	name.Text = lm.name
	name.Visible = false
	name.LayoutOrder = 2
	name.Parent = holder

	local model = balloon:FindFirstAncestorOfClass("Model")
	return {
		lm = lm, balloon = balloon, gui = gui, icon = icon, name = name,
		model = model, hidden = false, nameUntil = 0,
	}
end

-- Beacon models are Persistent (they must exist before you are near them), so
-- unlike the rest of the world they never stream out — which means another
-- land's balloons would hang in this land's sky across the 600-stud gap. Hide
-- the PHYSICAL beacon client-side for any land the player isn't standing in.
local function setPhysicalHidden(e, hidden: boolean)
	if e.hidden == hidden or not e.model then
		return
	end
	e.hidden = hidden
	for _, p in ipairs(e.model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = hidden and 1 or 0
		elseif p:IsA("PointLight") then
			p.Enabled = not hidden
		end
	end
end

-- Adopt any beacon the server has built (and any that stream in later).
local function adopt(inst: Instance)
	if not inst:IsA("BasePart") then
		return
	end
	local id = inst:GetAttribute("LandmarkId")
	if type(id) ~= "string" or entries[id] then
		return
	end
	local lm = LandmarkConfig.get(id)
	if lm then
		entries[id] = makeBanner(lm, inst)
	end
end

local function update()
	local camera = Workspace.CurrentCamera
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not camera or not hrp then
		-- No character for a moment on every respawn. Leave the world exactly as
		-- it is rather than blanking 25 beacons and popping them back — a flash
		-- across the whole sky on every death is worse than a stale frame.
		return
	end
	local here = (hrp :: BasePart).Position
	local land = LandmarkConfig.landAt(here)
	local compact = UiTheme.isCompact()
	local maxNames = compact and LandmarkConfig.MaxNamesCompact or LandmarkConfig.MaxNames
	local minPx = compact and LandmarkConfig.MinNameSpacingPxCompact or LandmarkConfig.MinNameSpacingPx
	local camCF = camera.CFrame
	local forward = camCF.LookVector

	-- Pass 1: band each beacon, and collect the ones eligible for a NAME.
	local candidates = {}
	for _, e in pairs(entries) do
		local lm = e.lm
		if lm.land ~= land then
			-- never draw another land's sky over this one, balloon included
			e.gui.Enabled = false
			e.name.Visible = false
			setPhysicalHidden(e, true)
		else
			setPhysicalHidden(e, false)
			local d = (Vector3.new(lm.pos.X, here.Y, lm.pos.Z) - here).Magnitude
			if d < (lm.nearBand or LandmarkConfig.NearBand) then
				-- the landmark's own world label is showing — stay quiet
				e.gui.Enabled = false
				e.name.Visible = false
			else
				e.gui.Enabled = true
				e.name.Visible = false -- pass 2 may switch this back on
				if d <= LandmarkConfig.NameBand then
					local toward = (e.balloon.Position - camCF.Position).Unit
					if toward:Dot(forward) >= FORWARD_COS then
						table.insert(candidates, { e = e, d = d })
					end
				end
			end
		end
	end

	-- Pass 2: hand out the names. This runs 5x/second, so a name that simply won
	-- the contest each frame would strobe as the player turns — every grant is
	-- therefore held for a minimum dwell, and holders are re-seated FIRST.
	local now = os.clock()
	table.sort(candidates, function(a, b)
		local aHeld = a.e.nameUntil > now
		local bHeld = b.e.nameUntil > now
		if aHeld ~= bHeld then
			return aHeld -- keep what's already on screen
		end
		return a.d < b.d
	end)
	local granted = {}
	for _, cand in ipairs(candidates) do
		if #granted >= maxNames then
			break
		end
		local screenPos, onScreen = camera:WorldToViewportPoint(cand.e.balloon.Position)
		if onScreen and screenPos.Z > 0 then
			-- A named banner is a wide, short box (~210x40), not a disc — test
			-- it as one, or two names sitting side by side read as clear when
			-- they visually overlap.
			local clear = true
			for _, g in ipairs(granted) do
				if math.abs(screenPos.X - g.X) < minPx * 1.7 and math.abs(screenPos.Y - g.Y) < 46 then
					clear = false
					break
				end
			end
			if clear then
				cand.e.name.Visible = true
				cand.e.nameUntil = now + NAME_DWELL
				table.insert(granted, Vector2.new(screenPos.X, screenPos.Y))
			end
		end
	end

	-- Size each enabled banner to what it is actually showing (an offset
	-- billboard is constant screen size, so this IS the "grows as you approach"
	-- feeling — and it keeps icon-only beacons visually quiet).
	for _, e in pairs(entries) do
		if e.gui.Enabled then
			if e.name.Visible then
				e.gui.Size = UDim2.fromOffset(compact and 160 or 210, 40)
			else
				e.gui.Size = UDim2.fromOffset(compact and 34 or 46, 46)
			end
		end
	end
end

function LandmarkBeacons.init()
	if running then
		return
	end
	running = true

	task.spawn(function()
		local folder = Workspace:WaitForChild("LandmarkBeacons", 60)
		if not folder then
			return
		end
		for _, model in ipairs(folder:GetDescendants()) do
			adopt(model)
		end
		folder.DescendantAdded:Connect(adopt)
	end)

	RunService.RenderStepped:Connect(function(dt)
		accum += dt
		if accum < UPDATE_INTERVAL then
			return
		end
		accum = 0
		local ok, err = pcall(update)
		if not ok then
			warn("[LandmarkBeacons] " .. tostring(err))
		end
	end)
end

return LandmarkBeacons
