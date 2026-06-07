-- SquishService (SERVER)
-- Spawns sleepy squishy friends on the Pudding Hills pads and runs the gentle
-- squish loop: a click adds Joy, and when a friend's Joy Meter is full it gives
-- a Happy Pop (sparkles + Sparkle Coins) and a new sleepy friend wakes up.
-- All Joy and coins are server-authoritative.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SquishyData = require(Shared:WaitForChild("SquishyData"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local SquishService = {}

-- Set by Main so the tutorial can react to Happy Pops.
SquishService.onHappyPop = nil :: ((Player, any) -> ())?

local squishiesFolder: Folder
local squishResultEvent: RemoteEvent
local pads: { CFrame } = {}
local activeByPad: { [number]: Model } = {} -- pad index -> the squishy currently there
local lastSquish: { [number]: { [string]: number } } = {} -- userId -> objectId -> os.clock()
local objectCounter = 0
local rng = Random.new()

-- Soft pastel body color per rarity (kid-friendly, never harsh).
local RARITY_COLORS = {
	common = Color3.fromRGB(255, 196, 212),
	rare = Color3.fromRGB(176, 196, 255),
	epic = Color3.fromRGB(214, 176, 255),
	legendary = Color3.fromRGB(255, 226, 150),
	mythic = Color3.fromRGB(255, 210, 170),
}

local function pickStarterDef()
	local pool = GameConfig.PuddingHillsStarters
	for _ = 1, 6 do
		local id = pool[rng:NextInteger(1, #pool)]
		local def = SquishyData.getById(id)
		if def then
			return def
		end
	end
	return SquishyData.getById("soft_dumpling")
end

local function buildSquishy(def, cf: CFrame): Model
	objectCounter += 1
	local objectId = "sq_" .. objectCounter

	local model = Instance.new("Model")
	model.Name = def.DisplayName

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(4, 4, 4)
	body.Anchored = true
	body.CanCollide = false
	body.Material = Enum.Material.SmoothPlastic
	body.Color = RARITY_COLORS[def.Rarity] or RARITY_COLORS.common
	body.CFrame = cf
	body.Parent = model

	model.PrimaryPart = body
	model:SetAttribute("ObjectId", objectId)
	model:SetAttribute("DefId", def.Id)
	model:SetAttribute("Joy", 0)
	model:SetAttribute("Sleepy", true)

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 32
	click.Parent = body
	click.MouseClick:Connect(function(player)
		SquishService.handleSquish(player, model)
	end)

	model.Parent = squishiesFolder
	return model
end

function SquishService.spawnAtPad(padIndex: number)
	local cf = pads[padIndex]
	if not cf then
		return
	end
	local model = buildSquishy(pickStarterDef(), cf)
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

	-- Gentle per-player, per-friend cooldown (anti-spam, never punishing).
	local userBucket = lastSquish[player.UserId]
	if not userBucket then
		userBucket = {}
		lastSquish[player.UserId] = userBucket
	end
	local now = os.clock()
	if now - (userBucket[objectId] or 0) < GameConfig.SquishCooldownSeconds then
		return
	end
	userBucket[objectId] = now

	local def = SquishyData.getById(defId)
	if not def then
		return
	end

	PlayerDataService.incSquish(player)

	local joy = math.min(1, (model:GetAttribute("Joy") or 0) + GameConfig.JoyPerSquish)
	model:SetAttribute("Joy", joy)
	model:SetAttribute("Sleepy", false)

	if joy >= 1 then
		-- Happy Pop!
		local coins = def.CoinReward or 5
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
		task.delay(0.4, function()
			if model and model.Parent then
				model:Destroy()
			end
		end)
		scheduleRespawn(padIndex)

		if SquishService.onHappyPop then
			SquishService.onHappyPop(player, def)
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

function SquishService.init(spawnPads: { CFrame })
	pads = spawnPads
	squishiesFolder = Instance.new("Folder")
	squishiesFolder.Name = "Squishies"
	squishiesFolder.Parent = Workspace
	squishResultEvent = Remotes.get(Remotes.SquishResult)

	local count = math.min(GameConfig.PuddingHillsFriendCount, #pads)
	for i = 1, count do
		SquishService.spawnAtPad(i)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastSquish[player.UserId] = nil
	end)
end

return SquishService
