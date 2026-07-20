--!strict
-- GardenService (SERVER)
-- The Sparkle Garden (WO-5): a cozy garden district just off Pudding Hills spawn.
-- Buy a Sparkle Seed with EARNED coins, plant it in a bed, and it grows while
-- you're away (growth is an os.time() delta computed on read — nothing ticks,
-- nothing wilts, nothing is ever lost). Come back to harvest it for coins.
--
-- Kindness watering: a visitor can water another player's rendered garden for a
-- gentle growth nudge (both get sparkle hearts; the owner gets a happy toast).
-- Same-server, online owners ONLY — we write growth into the OWNER's LIVE profile,
-- never an offline one (the session-lock rule the project was burned by before).
--
-- THE LAW: plants never wilt/die/get stolen; watering is pure upside; no timers,
-- no countdowns, no "your plant is sad" copy — ever.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local GardenConfig = require(Shared:WaitForChild("GardenConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)
local DailyService = require(script.Parent.DailyService)
local TravelService = require(script.Parent.TravelService)

local GardenService = {}

-- Wired by Main (keeps BadgeService out of our requires, like GiftService.onGiftSent).
GardenService.onHarvest = nil :: ((player: Player) -> ())?

local toastEvent: RemoteEvent
local openEvent: RemoteEvent
local waterFxEvent: RemoteEvent

-- The district sits SOUTHEAST of the Pudding Hills spawn (0,0.5,34), on the walk
-- toward the orchard + first shard (so kids find it), in a spot verified CLEAR of
-- every other structure. FINAL offsets — never run through ZoneConfig spread.
local DISTRICT_ORIGIN = Vector3.new(40, 0, -20)
local PLOT_SPACING_X = 10
local PLOT_SPACING_Z = 11
local COLS = 4
-- 3 bed mounds per plot, laid left→right across the plot
local BED_LOCAL_X = { ["1"] = -2.2, ["2"] = 0, ["3"] = 2.2 }
local VALID_BED = { ["1"] = true, ["2"] = true, ["3"] = true }

-- One friend override for the whole feature reuses TravelService's (the OwnerDebug
-- treatAsFriend/treatAsStranger already drive it), so attribution is testable solo.

type Plot = {
	index: number,
	model: Model,
	soil: BasePart,
	label: TextLabel,
	ownerUserId: number, -- 0 = unclaimed
	plants: { [string]: Model }, -- bedId → the currently-rendered plant model
}

local plots: { Plot } = {}
local slotOf: { [Player]: number } = {} -- player → plot index
local districtReady = false
local lastWaterPair: { [string]: number } = {} -- pairKey → os.clock (per-pair cooldown)

-- ── little builders (WorldService's helpers are module-local, so we keep our own) ──
local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	return p
end

local function pairKey(a: number, b: number): string
	return if a < b then a .. "-" .. b else b .. "-" .. a
end

local function rootPos(player: Player): Vector3?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return if root then (root :: BasePart).Position else nil
end

-- Does this profile have at least one bed that's planted and NOT yet fully grown?
-- (Nothing to water if the whole garden is empty or already bloomed.)
local function hasGrowingBed(profile: any): boolean
	local now = os.time()
	for _, bed in pairs(profile.Garden.beds) do
		local seed = GardenConfig.getSeed(bed.seedId)
		if seed and not GardenConfig.isReady(seed, bed.plantedAt, bed.wateredBonus, now) then
			return true
		end
	end
	return false
end

-- ── plant rendering ───────────────────────────────────────────────────────────
-- Clear any plant currently in a bed and grow a fresh one matching the stage.
local function renderBed(plot: Plot, bedId: string)
	local existing = plot.plants[bedId]
	if existing then
		existing:Destroy()
		plot.plants[bedId] = nil
	end
	local owner = plot.ownerUserId
	if owner == 0 then
		return
	end
	local player = Players:GetPlayerByUserId(owner)
	local profile = player and PlayerDataService.get(player)
	if not profile then
		return
	end
	local bed = profile.Garden.beds[bedId]
	if not bed then
		return -- empty soil
	end
	local seed = GardenConfig.getSeed(bed.seedId)
	if not seed then
		return
	end
	local now = os.time()
	local pct = GardenConfig.grownPct(seed, bed.plantedAt, bed.wateredBonus, now)
	local stage = GardenConfig.stageFor(pct)

	local model = Instance.new("Model")
	model.Name = "Plant_" .. bedId
	local base = (plot.soil.CFrame * CFrame.new(BED_LOCAL_X[bedId], 0.5, 0))

	-- a green stem whose height grows with progress
	local stemH = 0.6 + pct * 2.6
	local stem = part({
		Name = "Stem",
		Size = Vector3.new(0.35, stemH, 0.35),
		Color = Color3.fromRGB(120, 190, 120),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
	})
	stem.CFrame = base * CFrame.new(0, stemH / 2, 0)
	stem.Parent = model

	-- the bloom on top: small + closed early, big + bright + sparkling when ready
	local bloomSize = if stage == "seedling" then 0.5 elseif stage == "sprouting" then 0.9 elseif stage == "budding" then 1.3 else 1.8
	local bloom = part({
		Name = "Bloom",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(bloomSize, bloomSize, bloomSize),
		Color = if stage == "seedling" then Color3.fromRGB(150, 205, 140) else seed.color,
		Material = if stage == "bloomed" then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
	})
	bloom.CFrame = base * CFrame.new(0, stemH + bloomSize * 0.4, 0)
	bloom.Parent = model
	model.PrimaryPart = bloom

	if stage == "bloomed" then
		-- a gentle "ready to harvest!" sparkle (no countdown, just an invitation)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Rate = 6
		emitter.Lifetime = NumberRange.new(0.6, 1.1)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.Size = NumberSequence.new(0.7)
		emitter.LightEmission = 0.6
		emitter.Color = ColorSequence.new(seed.color)
		emitter.Parent = bloom
	end

	model.Parent = plot.model
	plot.plants[bedId] = model
end

local function renderPlot(plot: Plot)
	for _, bedId in ipairs(GardenConfig.BedIds) do
		renderBed(plot, bedId)
	end
	-- refresh the little name sign
	if plot.ownerUserId == 0 then
		plot.label.Text = "🌱 Sparkle Garden"
	else
		local player = Players:GetPlayerByUserId(plot.ownerUserId)
		plot.label.Text = (player and player.DisplayName or "A") .. "'s Garden"
	end
end

-- Re-draw the plot belonging to a given player (after plant/harvest/water).
local function refreshPlayer(player: Player)
	local idx = slotOf[player]
	if idx and plots[idx] then
		renderPlot(plots[idx])
	end
end

-- ── the world: build the district + its plots ─────────────────────────────────
local function buildPlot(parent: Instance, index: number): Plot
	local col = (index - 1) % COLS
	local row = math.floor((index - 1) / COLS)
	local pos = DISTRICT_ORIGIN
		+ Vector3.new((col - (COLS - 1) / 2) * PLOT_SPACING_X, 0, (row - 0.5) * PLOT_SPACING_Z)

	local model = Instance.new("Model")
	model.Name = "GardenPlot_" .. index

	-- the raised soil bed
	local soil = part({
		Name = "Soil",
		Size = Vector3.new(7.6, 1, 3.4),
		Position = pos + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(120, 86, 62),
		Material = Enum.Material.Ground,
	})
	soil.Parent = model
	model.PrimaryPart = soil

	-- a soft wooden rim so a plot reads as a tended bed
	for _, sx in ipairs({ -1, 1 }) do
		local rimZ = part({
			Name = "Rim",
			Size = Vector3.new(8, 0.6, 0.4),
			Position = pos + Vector3.new(0, 1, sx * 1.9),
			Color = Color3.fromRGB(196, 150, 110),
		})
		rimZ.Parent = model
	end

	-- three little mounds marking the bed spots
	for _, bedId in ipairs(GardenConfig.BedIds) do
		local mound = part({
			Name = "Mound",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.6, 0.7, 1.6),
			CFrame = soil.CFrame * CFrame.new(BED_LOCAL_X[bedId], 0.5, 0),
			Color = Color3.fromRGB(104, 74, 54),
			CanCollide = false,
			CanQuery = false,
		})
		mound.Parent = model
	end

	-- a signpost + floating name label
	local post = part({
		Name = "Post",
		Size = Vector3.new(0.3, 3, 0.3),
		Position = pos + Vector3.new(-4, 1.5, 0),
		Color = Color3.fromRGB(196, 150, 110),
	})
	post.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.fromOffset(180, 40)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.MaxDistance = 60
	billboard.AlwaysOnTop = false
	billboard.Adornee = post
	billboard.Parent = post
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(96, 74, 96)
	label.TextStrokeTransparency = 0.4
	label.Text = "🌱 Sparkle Garden"
	label.Parent = billboard

	-- two prompts on the SOIL part (a prompt on a Model never renders): the owner
	-- Tends, everyone else can Water. The client hides whichever one isn't for them.
	soil:SetAttribute("OwnerUserId", 0)

	local tend = Instance.new("ProximityPrompt")
	tend.Name = "TendPrompt"
	tend.ActionText = "🌱 Tend your Garden"
	tend.ObjectText = "Sparkle Garden"
	tend.HoldDuration = 0.2
	tend.MaxActivationDistance = GardenConfig.Watering.PromptDistance
	tend.RequiresLineOfSight = false
	tend.Parent = soil

	local water = Instance.new("ProximityPrompt")
	water.Name = "WaterPrompt"
	water.ActionText = "💧 Water this garden"
	water.ObjectText = "Sparkle Garden"
	water.HoldDuration = 0.3
	water.MaxActivationDistance = GardenConfig.Watering.PromptDistance
	water.RequiresLineOfSight = false
	water.Enabled = false -- off until the plot is claimed
	water.Parent = soil

	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Parent = parent

	local plot: Plot = {
		index = index,
		model = model,
		soil = soil,
		label = label,
		ownerUserId = 0,
		plants = {},
	}

	tend.Triggered:Connect(function(triggerer)
		-- only the plot's owner tends it (the client hides this for others anyway)
		if plot.ownerUserId == triggerer.UserId then
			openEvent:FireClient(triggerer)
		end
	end)
	water.Triggered:Connect(function(triggerer)
		GardenService.doWater(triggerer, plot.ownerUserId)
	end)

	return plot
end

local function buildDistrict(home: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "SparkleGarden"

	-- a soft grass patch under the plots + a welcome arch sign
	local patch = part({
		Name = "GardenGround",
		Size = Vector3.new(COLS * PLOT_SPACING_X + 8, 0.4, 2 * PLOT_SPACING_Z + 8),
		Position = DISTRICT_ORIGIN + Vector3.new(0, 0.2, 0),
		Color = Color3.fromRGB(178, 214, 150),
		Material = Enum.Material.Grass,
	})
	patch.Parent = folder

	local archLabelPost = part({
		Name = "GardenSign",
		Size = Vector3.new(0.5, 5, 0.5),
		Position = DISTRICT_ORIGIN + Vector3.new(0, 2.5, -(PLOT_SPACING_Z + 3)),
		Color = Color3.fromRGB(196, 150, 110),
	})
	archLabelPost.Parent = folder
	local signBb = Instance.new("BillboardGui")
	signBb.Size = UDim2.fromOffset(260, 60)
	signBb.StudsOffset = Vector3.new(0, 2.4, 0)
	signBb.MaxDistance = 120
	signBb.Adornee = archLabelPost
	signBb.Parent = archLabelPost
	local signLabel = Instance.new("TextLabel")
	signLabel.BackgroundTransparency = 1
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextScaled = true
	signLabel.TextColor3 = Color3.fromRGB(225, 90, 150)
	signLabel.TextStrokeTransparency = 0.4
	signLabel.Text = "🌸 The Sparkle Garden 🌸"
	signLabel.Parent = signBb

	-- A seed stall at the front: a UNIVERSAL entry to your garden panel, so EVERY
	-- player can plant/harvest even when all the rendered plots are claimed (the
	-- panel + plant/harvest work off your profile, not a plot). Plotless players
	-- just don't get a rendered, waterable bed in the world this session.
	local stall = part({
		Name = "SeedStall",
		Size = Vector3.new(6, 3, 2.4),
		Position = DISTRICT_ORIGIN + Vector3.new(0, 1.5, -(PLOT_SPACING_Z + 1)),
		Color = Color3.fromRGB(196, 150, 110),
	})
	stall.Parent = folder
	local awning = part({
		Name = "StallAwning",
		Size = Vector3.new(7, 0.4, 3.4),
		Position = DISTRICT_ORIGIN + Vector3.new(0, 3.3, -(PLOT_SPACING_Z + 1)),
		Color = Color3.fromRGB(255, 170, 195),
	})
	awning.Parent = folder
	local stallPrompt = Instance.new("ProximityPrompt")
	stallPrompt.Name = "SeedStallPrompt"
	stallPrompt.ActionText = "🌱 Tend your Garden"
	stallPrompt.ObjectText = "Sparkle Seeds"
	stallPrompt.HoldDuration = 0.2
	stallPrompt.MaxActivationDistance = 12
	stallPrompt.RequiresLineOfSight = false
	stallPrompt.Parent = stall
	stallPrompt.Triggered:Connect(function(player)
		openEvent:FireClient(player) -- opens the TRIGGERER's own garden
	end)

	for i = 1, GardenConfig.PlotSlots do
		plots[i] = buildPlot(folder, i)
	end

	folder.Parent = home
end

-- ── plot assignment (session-scoped; the plant DATA lives on the profile) ──────
local assignPlot: (player: Player) -> () -- forward declaration (claimWhenReady uses it)

-- Claim a plot only once BOTH the district exists and the profile has loaded, so
-- the first render actually shows the player's saved plants.
local function claimWhenReady(player: Player)
	task.spawn(function()
		local deadline = os.clock() + 30
		while (not districtReady or not PlayerDataService.isReady(player)) and player.Parent and os.clock() < deadline do
			task.wait(0.2)
		end
		if player.Parent and PlayerDataService.isReady(player) then
			assignPlot(player)
		end
	end)
end

function assignPlot(player: Player)
	if slotOf[player] then
		return
	end
	for _, plot in ipairs(plots) do
		if plot.ownerUserId == 0 then
			plot.ownerUserId = player.UserId
			plot.soil:SetAttribute("OwnerUserId", player.UserId)
			local waterPrompt = plot.soil:FindFirstChild("WaterPrompt") :: ProximityPrompt?
			if waterPrompt then
				waterPrompt.Enabled = true
			end
			slotOf[player] = plot.index
			renderPlot(plot)
			return
		end
	end
	-- more players than plots (only if PlotSlots < server size): they simply have
	-- no rendered bed this session; their garden still grows and syncs to the HUD.
end

local function releasePlot(player: Player)
	local idx = slotOf[player]
	slotOf[player] = nil
	if not idx or not plots[idx] then
		return
	end
	local plot = plots[idx]
	plot.ownerUserId = 0
	plot.soil:SetAttribute("OwnerUserId", 0)
	local waterPrompt = plot.soil:FindFirstChild("WaterPrompt") :: ProximityPrompt?
	if waterPrompt then
		waterPrompt.Enabled = false
	end
	for bedId, model in pairs(plot.plants) do
		model:Destroy()
		plot.plants[bedId] = nil
	end
	plot.label.Text = "🌱 Sparkle Garden"

	-- hand the freed plot to a waiting player who joined when we were full
	-- (skip the player who's leaving — they're briefly still in the list)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and not slotOf[other] and PlayerDataService.isReady(other) then
			assignPlot(other)
			break
		end
	end
end

-- ── the loop: plant / harvest / water ─────────────────────────────────────────
local function onPlant(player: Player, bedId: any, seedId: any)
	if type(bedId) ~= "string" or type(seedId) ~= "string" or not VALID_BED[bedId] then
		return
	end
	local seed = GardenConfig.getSeed(seedId)
	if not seed then
		return
	end
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	-- Occupied only counts if it's a KNOWN plant; a bed left holding a removed/
	-- renamed seedId reads as empty soil (gardenView omits it), so allow replanting
	-- over it instead of soft-locking the bed forever.
	local existing = profile.Garden.beds[bedId]
	if existing and GardenConfig.getSeed(existing.seedId) then
		toastEvent:FireClient(player, "That bed already has a plant growing! 🌱")
		return
	end
	if not PlayerDataService.spendCoins(player, seed.price) then
		toastEvent:FireClient(player, "You need " .. seed.price .. " coins for a " .. seed.name .. " — happy squishing!")
		return
	end
	profile.Garden.beds[bedId] = { seedId = seedId, plantedAt = os.time(), wateredBonus = 0 }
	PlayerDataService.sync(player)
	refreshPlayer(player)
	toastEvent:FireClient(player, "🌱 You planted a " .. seed.name .. "! It'll grow while you're away.")
end

local function onHarvest(player: Player, bedId: any)
	if type(bedId) ~= "string" then
		return
	end
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	local bed = profile.Garden.beds[bedId]
	if not bed then
		return
	end
	local seed = GardenConfig.getSeed(bed.seedId)
	if not seed then
		profile.Garden.beds[bedId] = nil -- unknown seed: clear it so the bed frees up
		PlayerDataService.sync(player)
		refreshPlayer(player)
		return
	end
	if not GardenConfig.isReady(seed, bed.plantedAt, bed.wateredBonus, os.time()) then
		toastEvent:FireClient(player, "🌱 Still growing — come back a little later!")
		return
	end
	-- pay out, plus a chance at a shiny "sparkle bloom" bonus
	local coins = seed.harvestCoins
	local bonus = 0
	if seed.dropChance > 0 and (Random.new():NextNumber() < seed.dropChance) then
		bonus = seed.dropCoins
	end
	PlayerDataService.addCoins(player, coins + bonus)
	profile.Garden.beds[bedId] = nil
	PlayerDataService.sync(player)
	refreshPlayer(player)
	if bonus > 0 then
		toastEvent:FireClient(player, "🌈 A sparkle bloom! You harvested " .. (coins + bonus) .. " coins!")
	else
		toastEvent:FireClient(player, "✨ You harvested your " .. seed.name .. " for " .. coins .. " coins!")
	end
	if GardenService.onHarvest then
		GardenService.onHarvest(player)
	end
end

-- Kindness watering. `ownerUserId` is the plot's current owner (set on the plot).
function GardenService.doWater(visitor: Player, ownerUserId: number)
	if type(ownerUserId) ~= "number" or ownerUserId == 0 then
		return
	end
	if visitor.UserId == ownerUserId then
		return -- can't water your own garden (the quest wants a FRIEND's)
	end
	if not PlayerDataService.isReady(visitor) then
		return
	end
	local owner = Players:GetPlayerByUserId(ownerUserId)
	if not owner or not PlayerDataService.isReady(owner) then
		return -- they've wandered off / are on another server — never write offline
	end
	-- must stand near the owner's plot
	local idx = slotOf[owner]
	local plot = idx and plots[idx]
	local vpos = rootPos(visitor)
	if not plot or not vpos or (vpos - plot.soil.Position).Magnitude > GardenConfig.Watering.Range then
		return
	end
	-- per-pair cooldown
	local key = pairKey(visitor.UserId, ownerUserId)
	local now = os.clock()
	if now - (lastWaterPair[key] or 0) < GardenConfig.Watering.PairCooldown then
		return
	end
	-- both caps
	if PlayerDataService.watersGivenToday(visitor) >= GardenConfig.Watering.PerDay then
		toastEvent:FireClient(visitor, "You've watered all your gardens for today — more tomorrow! 💧")
		return
	end
	if PlayerDataService.gardenReceivedToday(owner) >= GardenConfig.Watering.ReceivedPerDay then
		toastEvent:FireClient(visitor, "This garden's had plenty of water today — try another friend's! 💧")
		return
	end
	local ownerProfile = PlayerDataService.get(owner)
	if not ownerProfile or not hasGrowingBed(ownerProfile) then
		toastEvent:FireClient(visitor, "Their garden's all grown — nothing to water right now! 🌱")
		return
	end

	-- do it: nudge growth on the OWNER's live profile, roll both counters
	lastWaterPair[key] = now
	PlayerDataService.noteWaterGiven(visitor)
	PlayerDataService.noteWaterReceived(owner, GardenConfig.Watering.BonusSeconds)
	PlayerDataService.sync(owner)
	PlayerDataService.sync(visitor)
	refreshPlayer(owner)
	DailyService.noteEvent(visitor, "water")

	-- attribution: name only for Roblox friends, else "a kind visitor"
	local friend = TravelService.isFriendly(visitor, owner)
	local fromName = if friend then visitor.DisplayName else "A kind visitor"
	toastEvent:FireClient(owner, "💧 " .. fromName .. " watered your garden! 💖")
	toastEvent:FireClient(visitor, "💧 You watered " .. owner.DisplayName .. "'s garden — how kind! 💖")
	waterFxEvent:FireAllClients({ fromUserId = visitor.UserId, toUserId = ownerUserId, fromName = fromName })
end

-- ── welcome-back growth report (once per join; growth-framed, never neglect) ───
function GardenService.onJoin(player: Player)
	task.spawn(function()
		local deadline = os.clock() + 15
		while not PlayerDataService.isReady(player) and player.Parent and os.clock() < deadline do
			task.wait(0.2)
		end
		local profile = PlayerDataService.get(player)
		if not profile or not player.Parent then
			return
		end
		local now = os.time()
		local anyReady = false
		local anyGrowing = false
		for _, bed in pairs(profile.Garden.beds) do
			local seed = GardenConfig.getSeed(bed.seedId)
			if seed then
				if GardenConfig.isReady(seed, bed.plantedAt, bed.wateredBonus, now) then
					anyReady = true
				else
					anyGrowing = true
				end
			end
		end
		if anyReady then
			toastEvent:FireClient(player, "✨ Something in your Sparkle Garden is ready to harvest!")
		elseif anyGrowing then
			toastEvent:FireClient(player, "🌱 Your Sparkle Garden grew while you were away — go take a look!")
		end
	end)
end

-- OWNER DEBUG: backdate every planted bed a full grow cycle so the growth report
-- and harvest are demoable on cue (this IS the real growth mechanism — a per-plot
-- plantedAt delta — not a global os.time() fake, which would corrupt daily resets).
function GardenService.debugGrow(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	for _, bed in pairs(profile.Garden.beds) do
		local seed = GardenConfig.getSeed(bed.seedId)
		if seed then
			bed.plantedAt = os.time() - seed.growSeconds - 10
		end
	end
	PlayerDataService.sync(player)
	refreshPlayer(player)
	toastEvent:FireClient(player, "🌱 (debug) your garden jumped ahead — it's ready!")
end

function GardenService.init()
	toastEvent = Remotes.get(Remotes.Toast)
	openEvent = Remotes.get(Remotes.OpenGardenUI)
	waterFxEvent = Remotes.get(Remotes.WaterFx)
	Remotes.get(Remotes.PlantSeed).OnServerEvent:Connect(onPlant)
	Remotes.get(Remotes.HarvestPlant).OnServerEvent:Connect(onHarvest)
	Remotes.get(Remotes.WaterGarden).OnServerEvent:Connect(function(visitor, ownerUserId)
		GardenService.doWater(visitor, ownerUserId)
	end)

	-- self-build the district once Pudding Hills exists (Boutique pattern), then
	-- claim plots for whoever's already here.
	task.spawn(function()
		local home = Workspace:WaitForChild("PuddingHills", 30) or Workspace
		buildDistrict(home)
		districtReady = true
		for _, player in ipairs(Players:GetPlayers()) do
			claimWhenReady(player)
		end
	end)

	Players.PlayerAdded:Connect(claimWhenReady)

	Players.PlayerRemoving:Connect(function(player)
		releasePlot(player)
		-- sweep this player's per-pair cooldowns (exact half-match, not substring)
		local me = tostring(player.UserId)
		for key in pairs(lastWaterPair) do
			local a, b = string.match(key, "^(%d+)%-(%d+)$")
			if a == me or b == me then
				lastWaterPair[key] = nil
			end
		end
	end)
end

return GardenService
