--!strict
-- CheerService (SERVER)
-- Validates the one-tap Cheer on Sparkle Beacon discoveries (doc 15 §5) and
-- relays it to the discoverer. Love-bombing is mechanically impossible: one
-- cheer per (cheerer, reveal), a per-pair cooldown across reveals on top, a
-- short accept window, and the discoverer's client aggregates what does land.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local RevealConfig = require(Shared:WaitForChild("RevealConfig"))
local BoopService = require(script.Parent.BoopService)

local CheerService = {}

-- Stranger-safety (doc 14 §1): the discoverer sees the cheerer's name only if
-- they're Roblox friends — everyone else is "a kind visitor". Reuses Boop's
-- forceFriendTier override so both branches are demoable solo in Studio
-- (OwnerDebug treatAsFriend / treatAsStranger), where IsFriendsWith is empty.
local function areFriends(a: Player, b: Player): boolean
	if BoopService.forceFriendTier ~= nil then
		return BoopService.forceFriendTier
	end
	local ok, result = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	return ok and result == true
end

type Reveal = {
	player: Player,
	at: number,
	cheered: { [number]: boolean }, -- cheerer UserId -> true
}

local reveals: { [number]: Reveal } = {}
local pairLast: { [string]: number } = {} -- "cheererId:discovererId" -> os.clock()
local nextId = 0

local cheerArrivedEvent: RemoteEvent

-- Register a beacon-worthy reveal; returns the revealId the beacon broadcasts.
function CheerService.registerReveal(player: Player): number
	nextId += 1
	reveals[nextId] = { player = player, at = os.clock(), cheered = {} }
	-- Sweep anything past its window (+ slack) so the map never grows.
	local cutoff = os.clock() - RevealConfig.CheerWindowSeconds - 30
	for id, r in pairs(reveals) do
		if r.at < cutoff then
			reveals[id] = nil
		end
	end
	return nextId
end

function CheerService.init()
	cheerArrivedEvent = Remotes.get(Remotes.CheerArrived)
	local cheerEvent = Remotes.get(Remotes.CheerDiscovery)

	cheerEvent.OnServerEvent:Connect(function(cheerer: Player, revealId: unknown)
		if type(revealId) ~= "number" then
			return
		end
		local reveal = reveals[revealId]
		if not reveal then
			return
		end
		local discoverer = reveal.player
		if discoverer == cheerer or discoverer.Parent == nil then
			return
		end
		local now = os.clock()
		if now - reveal.at > RevealConfig.CheerWindowSeconds then
			return
		end
		if reveal.cheered[cheerer.UserId] then
			return
		end
		local pairKey = cheerer.UserId .. ":" .. discoverer.UserId
		local last = pairLast[pairKey]
		if last and now - last < RevealConfig.CheerPairCooldownSeconds then
			return
		end
		reveal.cheered[cheerer.UserId] = true
		pairLast[pairKey] = now
		-- fromName only for Roblox friends; fromUserId always, so the client can
		-- respect the local block list (GetBlockedUserIds is client-only).
		cheerArrivedEvent:FireClient(discoverer, {
			fromUserId = cheerer.UserId,
			fromName = if areFriends(discoverer, cheerer) then cheerer.DisplayName else nil,
		})
	end)

	Players.PlayerRemoving:Connect(function(player)
		for id, r in pairs(reveals) do
			if r.player == player then
				reveals[id] = nil
			end
		end
		-- pairLast entries expire by time; the occasional stale key is harmless
		-- and the map is swept alongside reveals to stay tiny.
		local cutoff = os.clock() - RevealConfig.CheerPairCooldownSeconds - 60
		for key, at in pairs(pairLast) do
			if at < cutoff then
				pairLast[key] = nil
			end
		end
	end)
end

return CheerService
