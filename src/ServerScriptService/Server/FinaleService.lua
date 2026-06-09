-- FinaleService (SERVER)
-- The storybook payoff: when a player recovers all three Sparkle shards, the
-- Sparkle is restored — a one-time big Sparkle Coin reward, the world's Sparkle
-- orb brightens, and the client plays a celebration.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local FinaleService = {}

local restoredEvent: RemoteEvent
local toastEvent: RemoteEvent
local worldBrightened = false

-- Brighten the world Sparkle orb above Pudding Hills (one-time, shared).
local function brightenWorldSparkle()
	if worldBrightened then
		return
	end
	local ph = Workspace:FindFirstChild("PuddingHills")
	local sparkle = ph and ph:FindFirstChild("TheSparkle")
	local core = sparkle and sparkle:FindFirstChild("Core")
	if not core or not core:IsA("BasePart") then
		return
	end
	worldBrightened = true
	local light = core:FindFirstChildWhichIsA("PointLight")
	if light then
		TweenService:Create(light, TweenInfo.new(2.5), { Brightness = 6, Range = 130 }):Play()
	end
	TweenService:Create(core, TweenInfo.new(2.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.new(20, 20, 20),
	}):Play()
	local em = core:FindFirstChildWhichIsA("ParticleEmitter")
	if em then
		em.Rate = em.Rate * 2
	end
end

function FinaleService.celebrate(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	local first = not PlayerDataService.isSparkleRestored(player)
	if first then
		PlayerDataService.markSparkleRestored(player)
		PlayerDataService.addCoins(player, GameConfig.FinaleRewardCoins)
	end
	brightenWorldSparkle()
	restoredEvent:FireClient(player, { reward = first and GameConfig.FinaleRewardCoins or 0, first = first })
	toastEvent:FireClient(player, "✨ You restored the Sparkle! The whole Squishy world shines again! ✨")
	PlayerDataService.sync(player)
end

function FinaleService.init()
	restoredEvent = Remotes.get(Remotes.SparkleRestored)
	toastEvent = Remotes.get(Remotes.Toast)
end

return FinaleService
