-- TravelService (SERVER)
-- Hops a player between the lands via Travel Pads. A land is reachable once the
-- PRIOR land's Sparkle shard has been recovered (Pudding Hills is always open), so
-- travel naturally follows the quest chain. Server-authoritative: the pad just
-- asks; this validates the unlock + teleports.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local TravelService = {}

local toastEvent: RemoteEvent

-- The ONE unlock decision (also reused by QuestService to gate land-locked things).
-- Unlock is DERIVED — there is no stored flag — so the escort path (which writes no
-- Shards) can never set it.
function TravelService.isUnlocked(profile, zoneName: string): boolean
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

local ESCORT_RADIUS = 16 -- a companion standing this close to the pad rides along

-- The next land whose Sparkle shard this player still needs (for the warm redirect).
function TravelService.nextShardZone(profile): string?
	for _, name in ipairs(ZoneConfig.Order) do
		local s = profile.Shards[name]
		if not (s and s.collected) then
			return name
		end
	end
	return nil
end

-- An UNLOCKED player standing at this pad, if any — they escort a locked sibling along.
local function unlockedCompanionAtPad(player: Player, destZone: string, pad: BasePart?): Player?
	local ref = (pad and pad.Position)
		or (player.Character and player.Character.PrimaryPart and player.Character.PrimaryPart.Position)
	if not ref then
		return nil
	end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local op = PlayerDataService.get(other)
			local oc = other.Character
			local orp = oc and oc:FindFirstChild("HumanoidRootPart")
			if op and orp and TravelService.isUnlocked(op, destZone)
				and (orp.Position - ref).Magnitude <= ESCORT_RADIUS then
				return other
			end
		end
	end
	return nil
end

-- Friend/stranger split — only decides whether to SHOW the companion's name (escort
-- itself is open to all; she triggers the pad herself, nobody is force-teleported).
-- OwnerDebug can force it for solo Studio testing (IsFriendsWith is empty there).
local friendOverride: { [number]: string } = {}
function TravelService.setFriendOverride(userId: number, mode: string?)
	friendOverride[userId] = mode
end
function TravelService.isFriendly(a: Player, b: Player): boolean
	local o = friendOverride[a.UserId] or friendOverride[b.UserId]
	if o == "friend" then
		return true
	elseif o == "stranger" then
		return false
	end
	local ok, res = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	return ok and res == true
end

function TravelService.travel(player: Player, destZone: string, pad: BasePart?)
	local profile = PlayerDataService.get(player)
	local zone = ZoneConfig.get(destZone)
	if not profile or not zone then
		return
	end
	local char = player.Character
	if not char or not char.PrimaryPart then
		return
	end
	if not TravelService.isUnlocked(profile, destZone) then
		-- Escort: a locked sibling rides along when an unlocked friend is at the pad.
		-- She squishes/bounces/plays freely, but the shard pedestal, guide, and
		-- land-gated progress stay locked (escort writes ZERO Shards, so her unlock
		-- stays derived-false); a warm toast points at her OWN next shard.
		local escort = unlockedCompanionAtPad(player, destZone, pad)
		if escort then
			char:PivotTo(CFrame.new(zone.spawn + Vector3.new(0, 3, 0)))
			local nextZone = TravelService.nextShardZone(profile) or "Pudding Hills"
			local who = TravelService.isFriendly(player, escort) and ("exploring with " .. escort.DisplayName) or "visiting"
			toastEvent:FireClient(player, "Welcome to " .. destZone .. "! You're " .. who .. " — squish and play all you like! Your own Sparkle Shard is waiting back in " .. nextZone .. ". ✨")
			if TravelService.onTraveled then
				TravelService.onTraveled(player, destZone)
			end
			return
		end
		local prior = ZoneConfig.priorZone(destZone)
		toastEvent:FireClient(player, "Recover the " .. (prior or "previous land's") .. " shard first to open " .. destZone .. "!")
		return
	end
	char:PivotTo(CFrame.new(zone.spawn + Vector3.new(0, 3, 0)))
	toastEvent:FireClient(player, "Welcome to " .. destZone .. "! ✨")
	-- fires only on a SUCCESSFUL hop (Main wires the FTUE funnel to this)
	if TravelService.onTraveled then
		TravelService.onTraveled(player, destZone)
	end
end

function TravelService.init()
	toastEvent = Remotes.get(Remotes.Toast)
end

return TravelService
