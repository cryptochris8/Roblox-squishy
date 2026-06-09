-- QuestService (SERVER)
-- "The Lost Sparkle" quest, one Sparkle shard per land. Each zone runs the same
-- spine (driven by ZoneConfig): get a clue -> wake enough sleepy friends in that
-- land -> the shard appears at the land's landmark -> recover it -> that land's
-- Sparkle is restored and the next land opens. Recovering all three shards fires
-- the finale. Per-player progress lives in profile.Shards[zoneName]; each shard is
-- a shared world landmark.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local QuestService = {}

-- hooks, wired by Main
QuestService.onShardRecovered = nil :: any -- (player, zoneName)
QuestService.onAllShardsRecovered = nil :: any -- (player)

local toastEvent: RemoteEvent
local shardModels: { [string]: Model } = {}

local SHARD_COLORS = {
	["Pudding Hills"] = Color3.fromRGB(180, 240, 255),
	["Goo Coast"] = Color3.fromRGB(150, 255, 214),
	["Moonlit Hollow"] = Color3.fromRGB(214, 180, 255),
}

local function zoneFolder(zoneName: string): Instance
	local folderName = string.gsub(zoneName, " ", "")
	return Workspace:FindFirstChild(folderName) or Workspace
end

-- Build the glowing shard at a land's landmark (a shared world object).
local function buildShard(zoneName: string)
	local existing = shardModels[zoneName]
	if existing and existing.Parent then
		return
	end
	local zone = ZoneConfig.get(zoneName)
	if not zone then
		return
	end
	local color = SHARD_COLORS[zoneName] or Color3.fromRGB(190, 235, 255)

	local model = Instance.new("Model")
	model.Name = "Shard_" .. string.gsub(zoneName, " ", "")

	local crystal = Instance.new("Part")
	crystal.Name = "Crystal"
	crystal.Shape = Enum.PartType.Block
	crystal.Size = Vector3.new(2.4, 6.5, 2.4)
	crystal.Material = Enum.Material.Neon
	crystal.Color = color
	crystal.Anchored = true
	crystal.CanCollide = false
	crystal.CastShadow = false
	crystal.CFrame = CFrame.new(zone.shardSpot + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(20))
	crystal.Parent = model
	model.PrimaryPart = crystal

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 3
	light.Range = 28
	light.Parent = crystal

	local em = Instance.new("ParticleEmitter")
	em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	em.LightEmission = 1
	em.Color = ColorSequence.new(color, Color3.fromRGB(255, 245, 215))
	em.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 2), NumberSequenceKeypoint.new(1, 0),
	})
	em.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.1), NumberSequenceKeypoint.new(1, 1),
	})
	em.Lifetime = NumberRange.new(1.2, 2)
	em.Rate = 18
	em.Speed = NumberRange.new(2, 5)
	em.SpreadAngle = Vector2.new(180, 180)
	em.Parent = crystal

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 160
	gui.Parent = crystal
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextSize = 20
	lbl.TextColor3 = Color3.fromRGB(90, 170, 200)
	lbl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.2
	lbl.Text = "Sparkle Shard"
	lbl.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Recover the Shard"
	prompt.ObjectText = "Sparkle Shard"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = crystal
	prompt.Triggered:Connect(function(player)
		QuestService.onShardTriggered(player, zoneName)
	end)

	model.Parent = zoneFolder(zoneName)

	TweenService:Create(crystal, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		CFrame = crystal.CFrame * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, math.rad(50), 0),
	}):Play()

	shardModels[zoneName] = model
end

QuestService.buildShard = buildShard

-- Called by SquishService on every Happy Pop. Advances the popped friend's land shard.
function QuestService.notePop(player: Player, def: any)
	if not def or type(def.Zone) ~= "string" then
		return
	end
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	local zone = ZoneConfig.get(def.Zone)
	local shard = profile.Shards[def.Zone]
	if not zone or not shard or shard.collected then
		return
	end
	if shard.progress >= zone.shardWakeGoal then
		buildShard(def.Zone)
		return
	end
	shard.progress += 1
	if shard.progress >= zone.shardWakeGoal then
		buildShard(def.Zone)
		toastEvent:FireClient(player, "The " .. def.Zone .. " shard is glimmering nearby — go and recover it!")
	end
	PlayerDataService.sync(player)
end

-- Player held a shard's prompt.
function QuestService.onShardTriggered(player: Player, zoneName: string)
	local profile = PlayerDataService.get(player)
	local zone = ZoneConfig.get(zoneName)
	local shard = profile and profile.Shards[zoneName]
	if not profile or not zone or not shard then
		return
	end
	if shard.collected then
		toastEvent:FireClient(player, "You've already recovered the " .. zoneName .. " shard!")
		return
	end
	if shard.progress < zone.shardWakeGoal then
		local left = zone.shardWakeGoal - shard.progress
		toastEvent:FireClient(player, "Wake " .. left .. " more sleepy friend" .. (left == 1 and "" or "s") .. " here to reveal the shard!")
		return
	end
	shard.collected = true
	PlayerDataService.addCoins(player, zone.shardRewardCoins)

	local allDone = true
	for _, z in ipairs(ZoneConfig.Order) do
		if not (profile.Shards[z] and profile.Shards[z].collected) then
			allDone = false
			break
		end
	end

	if allDone then
		toastEvent:FireClient(player, "✨ You recovered ALL THREE Sparkle shards! ✨")
		if QuestService.onAllShardsRecovered then
			QuestService.onAllShardsRecovered(player)
		end
	elseif zone.unlocksNext then
		toastEvent:FireClient(player, "You recovered the " .. zoneName .. " shard!  " .. zone.unlocksNext .. " is now open — find a Travel Pad to visit it!")
	else
		toastEvent:FireClient(player, "You recovered the " .. zoneName .. " shard!")
	end

	if QuestService.onShardRecovered then
		QuestService.onShardRecovered(player, zoneName)
	end
	PlayerDataService.sync(player)
end

-- On join: reveal any shard the player has qualified for but not yet recovered.
function QuestService.checkReveal(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	for _, zoneName in ipairs(ZoneConfig.Order) do
		local zone = ZoneConfig.get(zoneName)
		local shard = profile.Shards[zoneName]
		if zone and shard and not shard.collected and shard.progress >= zone.shardWakeGoal then
			buildShard(zoneName)
		end
	end
end

-- A land's guide gives that land's clue.
function QuestService.giveClue(player: Player, zoneName: string?)
	zoneName = zoneName or "Pudding Hills"
	local profile = PlayerDataService.get(player)
	local zone = ZoneConfig.get(zoneName)
	local shard = profile and profile.Shards[zoneName]
	if not profile or not zone or not shard then
		return
	end
	if shard.collected then
		local nextBit = zone.unlocksNext and (" " .. zone.unlocksNext .. " awaits!") or " The Sparkle shines bright again!"
		toastEvent:FireClient(player, "You've restored the " .. zoneName .. " shard!" .. nextBit)
	elseif shard.progress >= zone.shardWakeGoal then
		toastEvent:FireClient(player, "The " .. zoneName .. " shard is glimmering nearby — go recover it!")
	else
		local left = zone.shardWakeGoal - shard.progress
		toastEvent:FireClient(player, "The Sparkle dropped a shard here! Wake " .. left .. " more sleepy friend" .. (left == 1 and "" or "s") .. " and it will appear.")
	end
end

function QuestService.init()
	toastEvent = Remotes.get(Remotes.Toast)
end

return QuestService
