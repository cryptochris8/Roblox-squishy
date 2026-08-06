--!strict
-- SwitcherooService (SERVER)
-- The Switcheroo Station (doc 15 §6): the kid-safe swap machine, Phase 1.
-- A candy-striped depot south of the Pudding Hills Travel Plaza where
-- Whistlestop the owl conductor sends a SPARE friend "on an adventure" aboard
-- the Sparkle Express — and a rarity-matched mystery traveler steps off for
-- you, drawn from a cross-server pool fed by real kids (with Whistlestop's
-- Pouch as the never-fails fallback, so the Station works at zero players).
--
-- THE INVARIANT (never weaken): the traveler is selected and IN HAND before
-- the kid's spare is debited. A server crash mid-swap can cost the shared pool
-- an entry — never a child anything. Only spares move (the last copy is not a
-- spare by arithmetic — PlayerDataService.getSpares), rarity is exact-matched
-- always, and every swap ends in a discovery, a variant step, or coins plus a
-- banked spare. There is no counterparty, so there is nothing to scam.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local SquishyData = require(Shared:WaitForChild("SquishyData"))
local SwitcherooConfig = require(Shared:WaitForChild("SwitcherooConfig"))
local VariantConfig = require(Shared:WaitForChild("VariantConfig"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)
local DailyService = require(script.Parent.DailyService)
local BoopService = require(script.Parent.BoopService)
local Telemetry = require(script.Parent.Telemetry)

local SwitcherooService = {}

local DEPOT_ORIGIN = Vector3.new(112, 0, -52) -- south of the Travel Plaza; FINAL, never spread
local DEPOT_FACE = Vector3.new(116, 0, -23) -- the depot looks toward the plaza
local PROMPT_RANGE = 20 -- server-side range check for deposits (prompt shows at 14)

local toastEvent: RemoteEvent
local openEvent: RemoteEvent
local resultEvent: RemoteEvent

local rng = Random.new()
local depotDeskPart: BasePart? = nil
local lastDeposit: { [Player]: number } = {}

-- The cross-server pools: one key per rarity. GetDataStore throws in an
-- unpublished place — the pouch fallback keeps the Station alive without it.
local poolStore: DataStore? = nil
do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(SwitcherooConfig.PoolStoreName)
	end)
	if ok then
		poolStore = store
	end
end

-- Stranger-safety: a traveler's "once loved by" name shows only when the two
-- kids are Roblox friends. Reuses Boop's owner-debug override so both branches
-- are demoable solo in Studio (where IsFriendsWith is always empty).
local function areFriends(player: Player, userId: number): boolean
	if BoopService.forceFriendTier ~= nil then
		return BoopService.forceFriendTier
	end
	local ok, result = pcall(function()
		return player:IsFriendsWith(userId)
	end)
	return ok and result == true
end

-- ── The depot ────────────────────────────────────────────────────────────────

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(p :: any)[key] = value
	end
	return p
end

local function buildDepot(home: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "SwitcherooStation"

	local face = CFrame.lookAt(DEPOT_ORIGIN, Vector3.new(DEPOT_FACE.X, 0, DEPOT_FACE.Z))

	-- Platform the kids stand on (collidable, walk-up).
	local platform = part({
		Name = "StationPlatform", Size = Vector3.new(16, 1, 10),
		CFrame = face + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(232, 196, 160), Material = Enum.Material.WoodPlanks,
		CanCollide = true, CanQuery = true,
	})
	platform.Parent = folder

	-- The candy-striped booth: alternating peppermint columns + a rounded roof.
	for i = 0, 5 do
		local stripe = part({
			Name = "BoothStripe" .. i, Size = Vector3.new(1.4, 5.5, 0.6),
			CFrame = face * CFrame.new(-3.5 + i * 1.4, 3.75, -3.6),
			Color = i % 2 == 0 and Color3.fromRGB(235, 90, 100) or Color3.fromRGB(255, 250, 244),
		})
		stripe.Parent = folder
	end
	local roof = part({
		Name = "BoothRoof", Shape = Enum.PartType.Cylinder, Size = Vector3.new(9.6, 3.4, 3.4),
		CFrame = face * CFrame.new(0, 6.9, -3.6) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(255, 170, 190),
	})
	roof.Parent = folder

	-- The desk the prompt lives on (a prompt on a Model never renders — BasePart).
	local desk = part({
		Name = "StationDesk", Size = Vector3.new(6, 2.4, 2),
		CFrame = face * CFrame.new(0, 2.2, -2.4),
		Color = Color3.fromRGB(210, 140, 90), Material = Enum.Material.Wood,
		CanCollide = true, CanQuery = true,
	})
	desk.Parent = folder
	depotDeskPart = desk

	-- A stub of candy track running off toward the coaster rim: the Express
	-- "stops here" in fiction (the real ride loops the land's edge nearby).
	-- Local -X: the depot faces the plaza (north-ish), so its RightVector
	-- points WEST — the rim is EAST, which is local negative X (review catch).
	for i = 0, 4 do
		local tie = part({
			Name = "TrackTie" .. i, Size = Vector3.new(2.6, 0.3, 0.8),
			CFrame = face * CFrame.new(-(6 + i * 2), 0.35, 2.2),
			Color = Color3.fromRGB(170, 110, 70), Material = Enum.Material.Wood,
		})
		tie.Parent = folder
	end
	for _, side in ipairs({ -1, 1 }) do
		local rail = part({
			Name = "TrackRail", Size = Vector3.new(10, 0.35, 0.35),
			CFrame = face * CFrame.new(-10, 0.65, 2.2 + side * 0.9),
			Color = Color3.fromRGB(255, 205, 220), Material = Enum.Material.Neon,
		})
		rail.Parent = folder
	end

	-- Whistlestop, the plump owl conductor (hand-built: no owl archetype in the
	-- factory, and a real friend moonlighting as staff would confuse the Book).
	local owl = Instance.new("Model")
	owl.Name = "Whistlestop"
	local body = part({
		Name = "Body", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3.4, 2.8),
		CFrame = face * CFrame.new(3.6, 2.2, -2.2),
		Color = Color3.fromRGB(150, 110, 80),
	})
	body.Parent = owl
	owl.PrimaryPart = body
	local belly = part({
		Name = "Belly", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.4, 1.4),
		CFrame = face * CFrame.new(3.6, 1.9, -1.6),
		Color = Color3.fromRGB(235, 210, 170),
	})
	belly.Parent = owl
	for _, side in ipairs({ -1, 1 }) do
		local eye = part({
			Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.5),
			CFrame = face * CFrame.new(3.6 + side * 0.55, 3.1, -1.35),
			Color = Color3.fromRGB(255, 252, 246),
		})
		eye.Parent = owl
		local pupil = part({
			Name = "Pupil", Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.3),
			CFrame = face * CFrame.new(3.6 + side * 0.55, 3.1, -1.15),
			Color = Color3.fromRGB(60, 45, 40),
		})
		pupil.Parent = owl
		local wing = part({
			Name = "Wing", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 2, 1.6),
			CFrame = face * CFrame.new(3.6 + side * 1.55, 2.1, -2.2) * CFrame.Angles(0, 0, math.rad(side * 15)),
			Color = Color3.fromRGB(125, 90, 65),
		})
		wing.Parent = owl
	end
	local beak = part({
		Name = "Beak", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.7),
		CFrame = face * CFrame.new(3.6, 2.75, -1.2),
		Color = Color3.fromRGB(240, 170, 80),
	})
	beak.Parent = owl
	local cap = part({
		Name = "ConductorCap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 1.9, 1.9),
		CFrame = face * CFrame.new(3.6, 3.95, -1.9) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(70, 90, 150),
	})
	cap.Parent = owl
	local brim = part({
		Name = "CapBrim", Size = Vector3.new(1.7, 0.18, 0.9),
		CFrame = face * CFrame.new(3.6, 3.7, -1.35),
		Color = Color3.fromRGB(60, 75, 125),
	})
	brim.Parent = owl
	owl.Parent = folder

	-- Sign + the walk-up prompt.
	local sign = Instance.new("BillboardGui")
	sign.Name = "StationSign"
	sign.Size = UDim2.fromOffset(240, 34)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 8.6, 0)
	sign.AlwaysOnTop = true
	sign.MaxDistance = 70
	sign.Parent = desk
	local signLabel = Instance.new("TextLabel")
	signLabel.BackgroundTransparency = 1
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextSize = 24
	signLabel.TextColor3 = Color3.fromRGB(235, 90, 100)
	signLabel.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	signLabel.TextStrokeTransparency = 0.2
	signLabel.Text = "🚂 Switcheroo Station"
	signLabel.Parent = sign

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SwitcherooPrompt"
	prompt.ObjectText = "Whistlestop"
	prompt.ActionText = "Visit the Switcheroo Station"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = desk
	prompt.Triggered:Connect(function(player)
		SwitcherooService.openStation(player)
	end)

	folder.Parent = home
end

-- ── Opening the panel ────────────────────────────────────────────────────────

local rarityOrder = function(rarity: string): number
	local cfg = (RarityConfig :: any)[rarity]
	return (cfg and cfg.SortOrder) or 0
end

local lastOpen: { [Player]: number } = {}

function SwitcherooService.openStation(player: Player)
	-- The priciest prompt opener in the game (a full profile sweep) gets a
	-- gentle per-player debounce against prompt-spam.
	local now = os.clock()
	local last = lastOpen[player]
	if last and now - last < 1 then
		return
	end
	lastOpen[player] = now
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	local spares = {}
	for defId in pairs(profile.Discovered) do
		local n = PlayerDataService.getSpares(player, defId)
		if n >= 1 then
			local def = SquishyData.getById(defId)
			-- The Family Three never travel (one-grant finale rewards).
			if def and def.ReleaseType ~= "family" then
				table.insert(spares, {
					defId = def.Id,
					displayName = def.DisplayName,
					cardNumber = def.CardNumber,
					rarity = def.Rarity,
					imageAssetId = def.ImageAssetId,
					spares = n,
				})
			end
		end
	end
	table.sort(spares, function(a, b)
		local ra, rb = rarityOrder(a.rarity), rarityOrder(b.rarity)
		if ra ~= rb then
			return ra > rb
		end
		return a.displayName < b.displayName
	end)
	openEvent:FireClient(player, {
		spares = spares,
		adventuresLeft = PlayerDataService.switcherooLeftToday(player),
	})
end

-- ── The traveler draw ────────────────────────────────────────────────────────

-- Band-weighted pick: undiscovered friends win 4:1 over known ones. The POOL
-- takes the band's oldest (entries append in arrival order, so nothing lingers
-- forever); the POUCH randomizes inside the band — its candidate list is the
-- card-number-sorted roster, so "first" there would deal the same friend to
-- every kid every time (review catch).
local function pickIndex(candidates: { number }, isUndiscovered: { [number]: boolean }, randomize: boolean?): number?
	if #candidates == 0 then
		return nil
	end
	local fresh, known = {}, {}
	for _, idx in ipairs(candidates) do
		table.insert(if isUndiscovered[idx] then fresh else known, idx)
	end
	local band
	if #fresh > 0 and #known > 0 then
		band = if rng:NextInteger(1, SwitcherooConfig.UndiscoveredWeight + 1) <= SwitcherooConfig.UndiscoveredWeight
			then fresh
			else known
	elseif #fresh > 0 then
		band = fresh
	else
		band = known
	end
	if randomize then
		return band[rng:NextInteger(1, #band)]
	end
	return band[1]
end

-- Draw from the cross-server pool. Returns the picked entry or nil.
-- UpdateAsync CONTRACT: the transform may be invoked MULTIPLE times (conflict
-- retries) — it must be pure per invocation. `picked` is reset at the TOP of
-- every invocation so a retried transform that bails can never leak a stale
-- pick from an aborted attempt (the cross-server double-grant the adversarial
-- review caught). Bail paths return nil, which CANCELS the write entirely
-- (no durable no-op writes on every empty-pool draw).
local function drawFromPool(player: Player, rarity: string): any?
	if not poolStore then
		return nil
	end
	local picked: any = nil
	local ok = pcall(function()
		(poolStore :: DataStore):UpdateAsync(SwitcherooConfig.PoolKeyPrefix .. rarity, function(entries)
			picked = nil -- purity: only the COMMITTED invocation's pick survives
			if type(entries) ~= "table" or #entries == 0 then
				return nil -- cancel: nothing to draw, nothing to write
			end
			local candidates: { number } = {}
			local isUndiscovered: { [number]: boolean } = {}
			for idx, e in ipairs(entries) do
				if type(e) == "table" and type(e.d) == "string" and e.u ~= player.UserId
					and SquishyData.getById(e.d) then
					table.insert(candidates, idx)
					isUndiscovered[idx] = not PlayerDataService.hasDiscovered(player, e.d)
				end
			end
			local idx = pickIndex(candidates, isUndiscovered)
			if not idx then
				return nil -- cancel: no drawable entry for this player
			end
			picked = entries[idx]
			table.remove(entries, idx)
			-- silent aging: the pool never grows past its cap
			while #entries > SwitcherooConfig.PoolMaxEntries do
				table.remove(entries, 1)
			end
			return entries
		end)
	end)
	if not ok then
		return nil
	end
	return picked
end

-- Put a drawn entry BACK, verbatim, when the swap could not complete after the
-- draw (e.g. the spare vanished in a race). Never pushToPool here — that would
-- mint a fresh entry attributed to THIS player and corrupt the "once loved by"
-- provenance of another child's friend.
local function restoreToPool(rarity: string, entry: any)
	if not poolStore or type(entry) ~= "table" then
		return
	end
	pcall(function()
		(poolStore :: DataStore):UpdateAsync(SwitcherooConfig.PoolKeyPrefix .. rarity, function(entries)
			if type(entries) ~= "table" then
				entries = {}
			end
			table.insert(entries, entry)
			while #entries > SwitcherooConfig.PoolMaxEntries do
				table.remove(entries, 1)
			end
			return entries
		end)
	end)
end

-- Whistlestop's Pouch: the never-fails fallback. Seeds a LAUNCH-roster friend
-- of the same rarity ("the Express visits many worlds" — honest fiction).
-- Launch only: the 8 weekly event friends stay exclusive to the visiting tent
-- (the pouch must never free-mint a Friend-of-the-Week — review catch), and
-- the Family Three never travel. Real kids' pool deposits of event friends CAN
-- still arrive — genuine scarcity, exactly as designed.
local function drawFromPouch(player: Player, rarity: string, excludeDefId: string): any?
	local defs = SquishyData.getByRarity(rarity)
	local candidates: { number } = {}
	local isUndiscovered: { [number]: boolean } = {}
	for idx, def in ipairs(defs) do
		if def.ReleaseType == "launch" and def.Id ~= excludeDefId then
			table.insert(candidates, idx)
			isUndiscovered[idx] = not PlayerDataService.hasDiscovered(player, def.Id)
		end
	end
	local idx = pickIndex(candidates, isUndiscovered, true)
	if not idx then
		return nil
	end
	return { d = defs[idx].Id, u = 0, n = nil, t = 1, pouch = true }
end

-- Push the deposited spare into the pool for another world to meet. Best-effort:
-- a failed push loses one economy entry, never a player's property.
local function pushToPool(player: Player, defId: string, rarity: string, travels: number)
	if not poolStore then
		return
	end
	local entry = { d = defId, u = player.UserId, n = player.DisplayName, t = travels, ts = os.time() }
	pcall(function()
		(poolStore :: DataStore):UpdateAsync(SwitcherooConfig.PoolKeyPrefix .. rarity, function(entries)
			if type(entries) ~= "table" then
				entries = {}
			end
			table.insert(entries, entry)
			while #entries > SwitcherooConfig.PoolMaxEntries do
				table.remove(entries, 1)
			end
			return entries
		end)
	end)
end

-- ── The swap itself ──────────────────────────────────────────────────────────

-- The guarded deposit body. Runs with the per-player in-flight flag HELD (see
-- onDeposit): the drawFromPool yield can outlast the 2s debounce under
-- DataStore throttling, and without the flag a second deposit could re-enter
-- past the cap/spare checks while the first was still drawing (review catch).
local function doDeposit(player: Player, defId: string)
	if not PlayerDataService.isReady(player) then
		return
	end
	-- A DataStore-outage session runs on a temp profile: a deposit would
	-- evaporate on leave. Refuse gently (the ProcessReceipt principle).
	if not PlayerDataService.isSavable(player) then
		toastEvent:FireClient(player, "💤 The Station is snoozing right now — try again a little later!")
		return
	end
	-- Range: the swap only happens AT the depot (it's a ritual place). The
	-- panel closed on "All aboard!", so a refusal must SAY something.
	local desk = depotDeskPart
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not desk or not hrp or ((hrp :: BasePart).Position - desk.Position).Magnitude > PROMPT_RANGE then
		toastEvent:FireClient(player, "🚂 Scoot back to the Switcheroo Station to send a friend!")
		return
	end
	local def = SquishyData.getById(defId)
	if not def or def.ReleaseType == "family" then
		return
	end
	if PlayerDataService.getSpares(player, defId) < 1 then
		return
	end
	if PlayerDataService.switcherooLeftToday(player) < 1 then
		toastEvent:FireClient(player, "🚂 The Express is resting its wheels — more adventures tomorrow!")
		return
	end

	-- 1) Select the incoming traveler FIRST (pool, then pouch — never fails).
	local entry = drawFromPool(player, def.Rarity)
	if not entry then
		entry = drawFromPouch(player, def.Rarity, defId)
	end
	if not entry then
		-- No same-rarity friend exists at all (cannot happen with real data —
		-- the picker only offered rarities the roster contains). Bail safely:
		-- the spare was never touched.
		toastEvent:FireClient(player, "🚂 The Express is out exploring — try again in a moment!")
		return
	end
	local incoming = SquishyData.getById(entry.d)
	if not incoming then
		toastEvent:FireClient(player, "🚂 The Express is out exploring — try again in a moment!")
		return
	end

	-- 2) Traveler in hand: NOW debit the spare (re-checked atomically here).
	-- If the spare vanished (only reachable through profile edge cases — the
	-- in-flight flag serializes this player), a POOL-drawn entry goes back
	-- verbatim: another child's traveling friend is never silently destroyed.
	if not PlayerDataService.consumeSpare(player, defId) then
		if not entry.pouch then
			restoreToPool(def.Rarity, entry)
		end
		return
	end

	-- 3) Grant the traveler through the standard pipeline: the copy banks, then
	-- discovery / variant shine-up / coins — a swap can never end in loss.
	PlayerDataService.addCopy(player, incoming.Id)
	local isNew = PlayerDataService.discoverCard(player, incoming.Id)
	local bonusCoins = 0
	local variantLevel = 0
	local variantUpgraded = false
	if not isNew then
		variantLevel = PlayerDataService.getVariant(player, incoming.Id)
		if variantLevel < VariantConfig.Max then
			variantLevel = PlayerDataService.upgradeVariant(player, incoming.Id)
			variantUpgraded = true
			local lv = VariantConfig.Levels[variantLevel]
			bonusCoins = (lv and lv.bonusCoins) or 0
		else
			bonusCoins = VariantConfig.MaxDuplicateCoins or 0
		end
		if bonusCoins > 0 then
			PlayerDataService.addCoins(player, bonusCoins)
		end
	end

	-- 4) Provenance + counters + the outbound push.
	local travels = math.max(1, tonumber(entry.t) or 1)
	local fromIsFriend = type(entry.u) == "number" and entry.u > 0 and areFriends(player, entry.u)
	local fromName = if fromIsFriend then entry.n else nil
	PlayerDataService.addTravelStamp(player, incoming.Id, travels, fromName, fromIsFriend)
	PlayerDataService.noteSwitcheroo(player)
	PlayerDataService.pushSwapStory(player, { defId = defId, dir = "sent", t = os.time() })
	PlayerDataService.pushSwapStory(player, { defId = incoming.Id, dir = "met", from = fromName, t = os.time() })
	DailyService.noteEvent(player, "switcheroo")

	local profile = PlayerDataService.get(player)
	local outTravels = 1
	if profile then
		local stamp = profile.Stamps[defId]
		outTravels = ((stamp and stamp.travels) or 0) + 1
	end
	pushToPool(player, defId, def.Rarity, outTravels)

	PlayerDataService.sync(player)
	Telemetry.custom(player, "SwitcherooSwap")

	-- 5) The moment: the send-off toast + the traveler's full reveal ceremony.
	-- The stamp travels STRUCTURED (from-name separate) so the client can hide
	-- the cross-server name in Streamer Mode — StreamerMode.mask() can only
	-- alias players in THIS server, and the depositor never is (review catch).
	toastEvent:FireClient(player, "🚂 " .. def.DisplayName .. " hopped aboard with a tiny suitcase — off to find a new best friend!")
	resultEvent:FireClient(player, {
		defId = incoming.Id,
		displayName = incoming.DisplayName,
		cardNumber = incoming.CardNumber,
		rarity = incoming.Rarity,
		imageAssetId = incoming.ImageAssetId,
		isNew = isNew,
		bonusCoins = bonusCoins,
		wasFree = true,
		variantLevel = variantLevel,
		variantUpgraded = variantUpgraded,
		switcherooStamp = { from = fromName, pouch = entry.pouch == true },
		adventuresLeft = PlayerDataService.switcherooLeftToday(player),
	})

	if SwitcherooService.onSwap then
		SwitcherooService.onSwap(player, isNew, incoming)
	end

	-- 6) Persist promptly: the pool already committed durably, so the profile
	-- must not trail it by an autosave window (ProcessReceipt's save principle).
	PlayerDataService.saveNow(player)
end

-- optional hook (wired by Main), like CapsuleService.onOpened
SwitcherooService.onSwap = (nil :: any)

local depositing: { [Player]: boolean } = {}

local function onDeposit(player: Player, defId: unknown)
	if type(defId) ~= "string" then
		return
	end
	local now = os.clock()
	local last = lastDeposit[player]
	if last and now - last < 2 then
		return
	end
	lastDeposit[player] = now
	-- One deposit in flight per player, ever: the pool draw yields, and the
	-- checks above the yield must never go stale (see doDeposit's header).
	if depositing[player] then
		return
	end
	depositing[player] = true
	local ok, err = pcall(doDeposit, player, defId)
	depositing[player] = nil
	if not ok then
		warn("[SwitcherooService] deposit failed: " .. tostring(err))
	end
end

function SwitcherooService.init()
	toastEvent = Remotes.get(Remotes.Toast)
	openEvent = Remotes.get(Remotes.OpenSwitcheroo)
	resultEvent = Remotes.get(Remotes.SwitcherooResult)

	Remotes.get(Remotes.SwitcherooDeposit).OnServerEvent:Connect(onDeposit)

	Players.PlayerRemoving:Connect(function(player)
		lastDeposit[player] = nil
		depositing[player] = nil
		lastOpen[player] = nil
	end)

	-- Self-build off Pudding Hills, the GardenService pattern.
	task.spawn(function()
		local home = Workspace:WaitForChild("PuddingHills", 30) or Workspace
		buildDepot(home)
	end)
end

return SwitcherooService
