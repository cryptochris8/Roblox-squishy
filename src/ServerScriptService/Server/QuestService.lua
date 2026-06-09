-- QuestService (SERVER)
-- "The Lost Sparkle" quest — starting with The First Shard in Pudding Hills.
-- Per-player progress lives in the player's profile (PlayerDataService). The shard
-- itself is a shared world landmark that appears at the orchard once a player has
-- woken enough sleepy friends, and is recovered via a ProximityPrompt.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local QuestService = {}

local toastEvent: RemoteEvent
local shardSpot: Vector3
local gooCoastBarrier: BasePart?
local shardModel: Model? = nil
local gateOpened = false

-- Build the glowing shard at the orchard's edge (shared world landmark).
local function buildShard()
	if shardModel and shardModel.Parent then
		return
	end
	local model = Instance.new("Model")
	model.Name = "LostShard"

	local crystal = Instance.new("Part")
	crystal.Name = "Crystal"
	crystal.Shape = Enum.PartType.Block
	crystal.Size = Vector3.new(2.4, 6.5, 2.4)
	crystal.Material = Enum.Material.Neon
	crystal.Color = Color3.fromRGB(180, 240, 255)
	crystal.Anchored = true
	crystal.CanCollide = false
	crystal.CastShadow = false
	crystal.CFrame = CFrame.new(shardSpot + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(20))
	crystal.Parent = model
	model.PrimaryPart = crystal

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(200, 245, 255)
	light.Brightness = 3
	light.Range = 28
	light.Parent = crystal

	local em = Instance.new("ParticleEmitter")
	em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	em.LightEmission = 1
	em.Color = ColorSequence.new(Color3.fromRGB(220, 250, 255), Color3.fromRGB(255, 240, 200))
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
	gui.Size = UDim2.fromOffset(160, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.Parent = crystal
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextSize = 20
	lbl.TextColor3 = Color3.fromRGB(90, 170, 200)
	lbl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.2
	lbl.Text = "Lost Shard"
	lbl.Parent = gui

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Recover the Shard"
	prompt.ObjectText = "Lost Shard"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = crystal
	prompt.Triggered:Connect(function(player)
		QuestService.onShardTriggered(player)
	end)

	model.Parent = Workspace:FindFirstChild("PuddingHills") or Workspace

	-- gentle bob + slow spin
	TweenService:Create(crystal, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		CFrame = crystal.CFrame * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, math.rad(50), 0),
	}):Play()

	shardModel = model
end

function QuestService.revealShard()
	buildShard()
end

local function openGate()
	if gateOpened then
		return
	end
	gateOpened = true
	if gooCoastBarrier and gooCoastBarrier.Parent then
		gooCoastBarrier.CanCollide = false
		gooCoastBarrier.CanQuery = false
		TweenService:Create(gooCoastBarrier, TweenInfo.new(1.2), { Transparency = 1 }):Play()
		local gate = gooCoastBarrier.Parent
		local arch = gate and gate:FindFirstChild("Arch")
		local labelGui = arch and arch:FindFirstChildWhichIsA("BillboardGui")
		local lbl = labelGui and labelGui:FindFirstChildWhichIsA("TextLabel")
		if lbl then
			lbl.Text = "Goo Coast — Coming Soon!"
		end
		Debris:AddItem(gooCoastBarrier, 1.4)
	end
end

-- Called by SquishService on every Happy Pop (a friend waking up).
function QuestService.notePop(player: Player, _def: any)
	local profile = PlayerDataService.get(player)
	if not profile or profile.FirstShardCollected then
		return
	end
	local goal = GameConfig.FirstShardWakeGoal
	if profile.FirstShardProgress >= goal then
		QuestService.revealShard() -- make sure it's present
		return
	end
	profile.FirstShardProgress += 1
	if profile.FirstShardProgress >= goal then
		QuestService.revealShard()
		toastEvent:FireClient(player, "The lost shard is glimmering at the orchard's edge — go and recover it!")
	end
	PlayerDataService.sync(player)
end

-- Player held the shard's prompt.
function QuestService.onShardTriggered(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	if profile.FirstShardCollected then
		toastEvent:FireClient(player, "You've already recovered the First Shard!")
		return
	end
	if profile.FirstShardProgress < GameConfig.FirstShardWakeGoal then
		local left = GameConfig.FirstShardWakeGoal - profile.FirstShardProgress
		toastEvent:FireClient(player, "Wake " .. left .. " more sleepy friend" .. (left == 1 and "" or "s") .. " to reveal the shard!")
		return
	end
	profile.FirstShardCollected = true
	PlayerDataService.addCoins(player, GameConfig.FirstShardRewardCoins)
	openGate()
	toastEvent:FireClient(player, "You found the First Shard! Pudding Hills sparkles again — Goo Coast is opening!")
	PlayerDataService.sync(player)
end

-- On join: reveal the shard for a returning player who's qualified but hasn't
-- recovered it yet, and re-open Goo Coast for anyone who already finished (the
-- gate is a shared landmark that rebuilds closed on each server start).
function QuestService.checkReveal(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	if profile.FirstShardCollected then
		openGate()
	elseif profile.FirstShardProgress >= GameConfig.FirstShardWakeGoal then
		QuestService.revealShard()
	end
end

function QuestService.giveClue(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	if profile.FirstShardCollected then
		toastEvent:FireClient(player, "You've restored Pudding Hills' shard! Goo Coast awaits.")
	elseif profile.FirstShardProgress >= GameConfig.FirstShardWakeGoal then
		toastEvent:FireClient(player, "The lost shard is glimmering at the orchard's edge — go recover it!")
	else
		local left = GameConfig.FirstShardWakeGoal - profile.FirstShardProgress
		toastEvent:FireClient(player, "The Sparkle dropped a shard here! Wake " .. left .. " more sleepy friend" .. (left == 1 and "" or "s") .. " and it will appear at the orchard.")
	end
end

function QuestService.init(world: any)
	toastEvent = Remotes.get(Remotes.Toast)
	shardSpot = (world and world.shardSpot) or Vector3.new(47, 0, -40)
	gooCoastBarrier = world and world.gooCoastBarrier
end

return QuestService
