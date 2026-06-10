-- SquishService (SERVER)
-- Spawns sleepy squishy friends on the Pudding Hills pads and runs the gentle
-- squish loop: a click adds Joy, and when a friend's Joy Meter is full it gives
-- a Happy Pop (sparkles + Sparkle Coins) and a new sleepy friend wakes up.
-- All Joy and coins are server-authoritative.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SquishyData = require(Shared:WaitForChild("SquishyData"))
local SocialConfig = require(Shared:WaitForChild("SocialConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)
local SquishyModelFactory = require(script.Parent.SquishyModelFactory)

local SquishService = {}

-- Set by Main so the tutorial can react to Happy Pops.
SquishService.onHappyPop = nil :: ((Player, any) -> ())?
-- Set by Main: a GOLDEN friend (an "Everybody Squish!" event friend) Happy Popped.
SquishService.onGoldenPop = nil :: ((Player, any, Model) -> ())?
-- Set by Main: any squish at all (the First Day list watches the very first one).
SquishService.onSquish = nil :: ((Player) -> ())?
-- Set by Main: what to multiply coin awards by right now (Sparkle Surge = 2).
SquishService.coinMultiplier = nil :: (() -> number)?

local squishiesFolder: Folder
local squishResultEvent: RemoteEvent
local pads: { { cf: CFrame, zone: string, packId: string } } = {}
local activeByPad: { [number]: Model } = {} -- pad index -> the squishy currently there
local objectCounter = 0
local rng = Random.new()

local function pickDefForPack(packId: string)
	local pool = SquishyData.getByPack(packId)
	if #pool > 0 then
		return pool[rng:NextInteger(1, #pool)]
	end
	return SquishyData.getById("soft_dumpling")
end

local function buildSquishy(def, cf: CFrame): Model
	objectCounter += 1
	local objectId = "sq_" .. objectCounter

	-- The friend's real shape comes from the factory (a dumpling looks like a
	-- dumpling). A little size variety so a cluster feels hand-placed, not cloned.
	local model = SquishyModelFactory.build(def)
	model:ScaleTo(rng:NextNumber(0.92, 1.12))
	model:PivotTo(cf)

	model:SetAttribute("ObjectId", objectId)
	model:SetAttribute("DefId", def.Id)
	model:SetAttribute("Joy", 0)
	model:SetAttribute("Sleepy", true)

	-- On the MODEL, so ears, wings, and toppings are all squishable.
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 32
	click.Parent = model
	click.MouseClick:Connect(function(player)
		SquishService.handleSquish(player, model)
	end)

	model.Parent = squishiesFolder
	return model
end

-- Spawns a temporary GOLDEN friend for an "Everybody Squish!" event: its whole
-- shape glimmers gold, worth extra coins, and never tied to a pad (so it
-- doesn't respawn — the event owns its life). Returns the model.
function SquishService.spawnGolden(packId: string, cf: CFrame): Model
	local model = buildSquishy(pickDefForPack(packId), cf)
	model:SetAttribute("Golden", true)
	SquishyModelFactory.applyGolden(model)
	return model
end

function SquishService.spawnAtPad(padIndex: number)
	local p = pads[padIndex]
	if not p then
		return
	end
	local model = buildSquishy(pickDefForPack(p.packId), p.cf)
	model:SetAttribute("PadIndex", padIndex)
	activeByPad[padIndex] = model
end

local function scheduleRespawn(padIndex)
	if type(padIndex) ~= "number" then
		return
	end
	task.delay(GameConfig.HappyPopRespawnSeconds, function()
		if not activeByPad[padIndex] and pads[padIndex] then
			SquishService.spawnAtPad(padIndex)
		end
	end)
end

function SquishService.handleSquish(player: Player, model: Model)
	if not model or not model.Parent then
		return
	end
	local objectId = model:GetAttribute("ObjectId")
	local defId = model:GetAttribute("DefId")
	if type(objectId) ~= "string" or type(defId) ~= "string" then
		return
	end
	-- A friend that already Happy Popped is mid-celebration; ignore extra clicks.
	if model:GetAttribute("Popped") then
		return
	end

	-- Gentle per-player, per-friend cooldown (anti-spam, never punishing). We store
	-- it on the friend itself, so it's cleaned up automatically when the friend pops
	-- (no growing table to prune).
	local cooldownKey = "LastSquish_" .. player.UserId
	local now = os.clock()
	if now - (model:GetAttribute(cooldownKey) or 0) < GameConfig.SquishCooldownSeconds then
		return
	end
	model:SetAttribute(cooldownKey, now)

	local def = SquishyData.getById(defId)
	if not def then
		return
	end

	PlayerDataService.incSquish(player)
	if SquishService.onSquish then
		SquishService.onSquish(player)
	end

	local joy = math.min(1, (model:GetAttribute("Joy") or 0) + GameConfig.JoyPerSquish)
	model:SetAttribute("Joy", joy)
	model:SetAttribute("Sleepy", false)

	if joy >= 1 then
		-- Happy Pop!
		local isGolden = model:GetAttribute("Golden") == true
		local coins = def.CoinReward or 5
		if isGolden then
			coins *= SocialConfig.EventGoldenCoinMultiplier
		end
		if SquishService.coinMultiplier then
			coins = math.floor(coins * SquishService.coinMultiplier())
		end
		PlayerDataService.addCoins(player, coins)
		PlayerDataService.incHappyPop(player)

		squishResultEvent:FireAllClients({
			objectId = objectId,
			defId = def.Id,
			joy = 1,
			popped = true,
			byUserId = player.UserId,
			coins = coins,
		})

		local padIndex = model:GetAttribute("PadIndex")
		if type(padIndex) == "number" then
			activeByPad[padIndex] = nil
		end
		-- Free the pad now, but keep the friend around for a beat so the client's
		-- Happy Pop animation can play before it's removed.
		model:SetAttribute("Popped", true)
		local clicker = model:FindFirstChildWhichIsA("ClickDetector", true)
		if clicker then
			clicker.MaxActivationDistance = 0
		end
		task.delay(GameConfig.HappyPopHoldSeconds, function()
			if model and model.Parent then
				model:Destroy()
			end
		end)
		scheduleRespawn(padIndex)

		if SquishService.onHappyPop then
			SquishService.onHappyPop(player, def)
		end
		if isGolden and SquishService.onGoldenPop then
			SquishService.onGoldenPop(player, def, model)
		end
		PlayerDataService.sync(player)
	else
		-- Just a happy squish — tell everyone so the friend wobbles for them too.
		squishResultEvent:FireAllClients({
			objectId = objectId,
			defId = def.Id,
			joy = joy,
			popped = false,
			byUserId = player.UserId,
		})
	end
end

-- zoneGroups: array of { zone = string, packId = string, pads = { CFrame } }.
-- A sleepy friend from each zone's pack spawns at every pad in that zone.
function SquishService.init(zoneGroups: { { zone: string, packId: string, pads: { CFrame } } })
	pads = {}
	for _, g in ipairs(zoneGroups) do
		for _, cf in ipairs(g.pads) do
			pads[#pads + 1] = { cf = cf, zone = g.zone, packId = g.packId }
		end
	end
	squishiesFolder = Instance.new("Folder")
	squishiesFolder.Name = "Squishies"
	squishiesFolder.Parent = Workspace
	squishResultEvent = Remotes.get(Remotes.SquishResult)

	for i = 1, #pads do
		SquishService.spawnAtPad(i)
	end
end

return SquishService
