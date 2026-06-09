-- TravelService (SERVER)
-- Hops a player between the lands via Travel Pads. A land is reachable once the
-- PRIOR land's Sparkle shard has been recovered (Pudding Hills is always open), so
-- travel naturally follows the quest chain. Server-authoritative: the pad just
-- asks; this validates the unlock + teleports.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local TravelService = {}

local toastEvent: RemoteEvent

local function isUnlocked(profile, zoneName: string): boolean
	local zone = ZoneConfig.get(zoneName)
	if not zone then
		return false
	end
	if zone.alwaysUnlocked then
		return true
	end
	local prior = ZoneConfig.priorZone(zoneName)
	if not prior then
		return true
	end
	local s = profile.Shards[prior]
	return s ~= nil and s.collected == true
end

function TravelService.travel(player: Player, destZone: string)
	local profile = PlayerDataService.get(player)
	local zone = ZoneConfig.get(destZone)
	if not profile or not zone then
		return
	end
	local char = player.Character
	if not char or not char.PrimaryPart then
		return
	end
	if not isUnlocked(profile, destZone) then
		local prior = ZoneConfig.priorZone(destZone)
		toastEvent:FireClient(player, "Recover the " .. (prior or "previous land's") .. " shard first to open " .. destZone .. "!")
		return
	end
	char:PivotTo(CFrame.new(zone.spawn + Vector3.new(0, 3, 0)))
	toastEvent:FireClient(player, "Welcome to " .. destZone .. "! ✨")
end

function TravelService.init()
	toastEvent = Remotes.get(Remotes.Toast)
end

return TravelService
