-- DailyService (SERVER)
-- "Daily reasons to return" — currently a free Sparkle Capsule each day. Daily
-- quests + a gentle streak will live here too. All resets are UTC-day based and
-- server-authoritative; the capsule stays FREE (opened as a gift, never Robux).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerDataService = require(script.Parent.PlayerDataService)
local CapsuleService = require(script.Parent.CapsuleService)

local DailyService = {}

local toastEvent: RemoteEvent

function DailyService.claimDailyCapsule(player: Player)
	if not PlayerDataService.isReady(player) then
		return
	end
	if not PlayerDataService.isDailyCapsuleReady(player) then
		toastEvent:FireClient(player, "Your free Sparkle Capsule will be ready again tomorrow!")
		return
	end
	-- Open a FREE capsule; only spend the day's claim if it actually opened.
	if CapsuleService.tryOpen(player, true) then
		PlayerDataService.markDailyCapsuleClaimed(player)
		PlayerDataService.sync(player)
	end
end

function DailyService.init()
	toastEvent = Remotes.get(Remotes.Toast)
	local claim = Remotes.get(Remotes.ClaimDailyCapsule)
	claim.OnServerEvent:Connect(function(player)
		DailyService.claimDailyCapsule(player)
	end)
end

return DailyService
