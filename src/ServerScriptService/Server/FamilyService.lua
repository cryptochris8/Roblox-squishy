--!strict
-- FamilyService (SERVER)
-- The Family Three — Chris's daughters, one guardian per land. Each stands on
-- a glowing pedestal near her land's Sparkle shard, visible from the start as
-- a "someone special is waiting here" teaser. You BEFRIEND her by restoring
-- that land's shard (the reward for the work) — the warm card-reveal plays,
-- she joins the Squishy Book's ⭐ Family tab, and you can walk with her like
-- any buddy. Earned, never bought; one per land, in order:
--   Pudding Hills → Apple Addy   Goo Coast → Eggy Ellie   Moonlit → Hot Dog Heidi

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))
local SquishyData = require(Shared:WaitForChild("SquishyData"))

local PlayerDataService = require(script.Parent.PlayerDataService)
local SquishyModelFactory = require(script.Parent.SquishyModelFactory)

local FamilyService = {}

local toastEvent: RemoteEvent
local capsuleResultEvent: RemoteEvent

-- which daughter guards which land
local BY_ZONE: { [string]: string } = {
	["Pudding Hills"] = "apple_addy",
	["Goo Coast"] = "eggy_ellie",
	["Moonlit Hollow"] = "hot_dog_heidi",
}

local PEDESTAL_COLOR: { [string]: Color3 } = {
	apple_addy = Color3.fromRGB(255, 150, 180),
	eggy_ellie = Color3.fromRGB(150, 200, 255),
	hot_dog_heidi = Color3.fromRGB(202, 162, 246),
}

local figures: { { model: Model, baseY: number, phase: number } } = {}

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	for key, value in pairs(props) do
		(p :: any)[key] = value
	end
	return p
end

local function zoneFolder(zoneName: string): Instance
	return Workspace:FindFirstChild((string.gsub(zoneName, " ", ""))) or Workspace
end

-- True once the player has restored this land's shard.
local function shardDone(player: Player, zoneName: string): boolean
	local profile = PlayerDataService.get(player)
	local shard = profile and profile.Shards[zoneName]
	return shard ~= nil and shard.collected == true
end

-- Befriend a land's daughter: Book entry + buddy unlock, idempotent
-- (discoverCard is). `silent` skips the big card reveal + server shout — used
-- by the returning-player catch-up so nobody gets three reveals stacked at
-- once. Returns true if she was NEWLY befriended.
function FamilyService.grant(player: Player, zoneName: string, silent: boolean?): boolean
	local famId = BY_ZONE[zoneName]
	if not famId or not PlayerDataService.isReady(player) then
		return false
	end
	if PlayerDataService.hasDiscovered(player, famId) then
		return false
	end
	local def = SquishyData.getById(famId)
	if not def then
		return false
	end
	PlayerDataService.discoverCard(player, famId)

	if not silent then
		capsuleResultEvent:FireClient(player, {
			defId = def.Id,
			displayName = def.DisplayName,
			cardNumber = def.CardNumber,
			rarity = def.Rarity,
			imageAssetId = def.ImageAssetId,
			isNew = true,
			bonusCoins = 0,
			wasFree = true,
			variantLevel = 0,
			variantUpgraded = false,
		})
		toastEvent:FireClient(player, "💛 " .. def.DisplayName .. " is now your friend! Open your Squishy Book to walk together.")
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				toastEvent:FireClient(other, "💛 " .. player.DisplayName .. " befriended " .. def.DisplayName .. ", a Family friend!")
			end
		end
	end
	PlayerDataService.sync(player)
	return true
end

-- Returning players who restored a land BEFORE this feature existed: catch
-- them up. Waits for the profile to finish loading (RequestInitialState can
-- arrive first), grants quietly, then one warm welcome-back toast.
function FamilyService.checkOwed(player: Player)
	task.spawn(function()
		local deadline = os.clock() + 15
		while not PlayerDataService.isReady(player) and player.Parent and os.clock() < deadline do
			task.wait(0.2)
		end
		if not PlayerDataService.isReady(player) then
			return
		end
		local names = {}
		for _, zoneName in ipairs(ZoneConfig.Order) do
			local famId = BY_ZONE[zoneName]
			if shardDone(player, zoneName) and famId and not PlayerDataService.hasDiscovered(player, famId) then
				if FamilyService.grant(player, zoneName, true) then
					local def = SquishyData.getById(famId)
					names[#names + 1] = def and def.DisplayName or famId
				end
			end
		end
		if #names > 0 then
			toastEvent:FireClient(player, "💛 " .. table.concat(names, " & ") .. " " ..
				(#names == 1 and "is waiting" or "are waiting") .. " in your ⭐ Family book!")
		end
	end)
end

-- A glowing pedestal with the waiting daughter (always visible; the prompt
-- gates befriending on the shard so the goal is seen but earned).
local function buildPedestal(zoneName: string)
	local famId = BY_ZONE[zoneName]
	local def = famId and SquishyData.getById(famId)
	local zone = ZoneConfig.get(zoneName)
	if not (def and zone) then
		return
	end
	local color = PEDESTAL_COLOR[famId] or Color3.fromRGB(255, 150, 180)
	-- a place of honour beside where the shard is recovered
	local spot = zone.shardSpot + Vector3.new(-18, 0, 6)

	local folder = Instance.new("Model")
	folder.Name = "FamilyShrine_" .. famId
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local base = part({
		Name = "Base", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 11, 11),
		Color = Color3.fromRGB(255, 250, 240), CanCollide = true, CanQuery = true,
	})
	base.CFrame = CFrame.new(spot + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	base.Parent = folder
	local glowRing = part({
		Name = "GlowRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 12.6, 12.6),
		Color = color, Material = Enum.Material.Neon, Transparency = 0.4,
	})
	glowRing.CFrame = CFrame.new(spot + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	glowRing.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 2
	light.Range = 26
	light.Parent = glowRing

	-- a soft column of rising sparkles
	local em = Instance.new("ParticleEmitter")
	em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	em.LightEmission = 0.9
	em.Color = ColorSequence.new(color, Color3.fromRGB(255, 250, 240))
	em.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 1.4), NumberSequenceKeypoint.new(1, 0),
	})
	em.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(1, 1),
	})
	em.Lifetime = NumberRange.new(1.4, 2.2)
	em.Rate = 10
	em.Speed = NumberRange.new(2, 4)
	em.EmissionDirection = Enum.NormalId.Top
	em.SpreadAngle = Vector2.new(40, 40)
	em.Parent = base

	-- the daughter herself, a little larger than a world friend (she's special)
	local figure = SquishyModelFactory.build(def)
	figure.Name = "Figure"
	figure:ScaleTo(1.35)
	for _, p in ipairs(figure:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
		end
	end
	local figureBase = 3.6
	figure:PivotTo(CFrame.new(spot + Vector3.new(0, figureBase, 0)))
	figure.Parent = folder

	-- her name, always shown
	local nameGui = Instance.new("BillboardGui")
	nameGui.Name = "FamilySign"
	nameGui.Size = UDim2.fromOffset(220, 40)
	nameGui.StudsOffsetWorldSpace = Vector3.new(0, 7.5, 0)
	nameGui.AlwaysOnTop = true
	nameGui.MaxDistance = 120
	nameGui.Parent = base
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextSize = 24
	lbl.TextColor3 = color
	lbl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.2
	lbl.Text = "⭐ " .. def.DisplayName
	lbl.Parent = nameGui

	-- befriend prompt (gated on the shard)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = def.DisplayName
	prompt.ActionText = "Say hello"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = base
	prompt.Triggered:Connect(function(player)
		if not PlayerDataService.isReady(player) then
			return
		end
		if PlayerDataService.hasDiscovered(player, famId) then
			toastEvent:FireClient(player, "💛 " .. def.DisplayName .. " is your friend! Tap her in your Squishy Book to walk together.")
		elseif shardDone(player, zoneName) then
			FamilyService.grant(player, zoneName)
		else
			toastEvent:FireClient(player, "Restore the " .. zoneName .. " Sparkle, and " .. def.DisplayName .. " will be your friend! 💛")
		end
	end)

	folder.Parent = zoneFolder(zoneName)
	figures[#figures + 1] = { model = figure, baseY = spot.Y + figureBase, phase = #figures * 2.1 }
end

function FamilyService.init()
	toastEvent = Remotes.get(Remotes.Toast)
	capsuleResultEvent = Remotes.get(Remotes.CapsuleResult)

	task.spawn(function()
		for _, zoneName in ipairs(ZoneConfig.Order) do
			-- wait for the land folder to exist (WorldService builds them)
			local fname = (string.gsub(zoneName, " ", ""))
			local t0 = os.clock()
			repeat task.wait(0.2) until Workspace:FindFirstChild(fname) or os.clock() - t0 > 30
			buildPedestal(zoneName)
		end
	end)

	-- one gentle bob + slow spin for every waiting daughter
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, f in ipairs(figures) do
			if f.model.Parent then
				local y = f.baseY + math.sin(t * 1.4 + f.phase) * 0.4
				f.model:PivotTo(CFrame.new(f.model:GetPivot().Position.X, y, f.model:GetPivot().Position.Z)
					* CFrame.Angles(0, t * 0.5 + f.phase, 0))
			end
		end
	end)
end

return FamilyService
