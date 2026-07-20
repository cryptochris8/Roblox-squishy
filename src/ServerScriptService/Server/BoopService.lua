--!strict
-- BoopService (SERVER)
-- The gentlest hello: walk up to another player and give them a "Boop!". A boop
-- is pure kindness — a heart/sparkle pop, never anything competitive. Every player
-- wears a small Boop prompt (on the HumanoidRootPart; a prompt parented to the
-- Model never renders). Server-authoritative and stranger-safe:
--   • a per-PAIR cooldown, so nobody can be boop-spammed / pile-on'd
--   • friend-vs-stranger split: Roblox friends trade a big heart burst and see
--     each other's names; everyone else gets a plain sparkle from "a kind visitor"
--   (the local block list + hiding your own prompt are handled client-side, where
--    GetBlockedUserIds lives — see BoopFx).
-- Same-server, walk-up only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local BoopService = {}

local BOOP_RANGE = 14      -- studs: how close a boop is valid (server-checked)
local PAIR_COOLDOWN = 40   -- one boop per pair of players per this many seconds
local PROMPT_DISTANCE = 11 -- studs: how close the prompt appears

local boopFxEvent: RemoteEvent
local toastEvent: RemoteEvent

-- pairKey -> last boop os.clock (per-pair rate limit)
local lastBoop: { [string]: number } = {}

-- OWNER debug override so both FX branches are testable solo in Studio, where
-- IsFriendsWith is always empty. nil = use the real friends check.
BoopService.forceFriendTier = nil :: boolean?

local function rootPos(player: Player): Vector3?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return if root then (root :: BasePart).Position else nil
end

local function pairKey(a: number, b: number): string
	return if a < b then a .. "-" .. b else b .. "-" .. a
end

local function areFriends(a: Player, b: Player): boolean
	if BoopService.forceFriendTier ~= nil then
		return BoopService.forceFriendTier
	end
	local ok, result = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	return ok and result == true
end

-- `sender` walked up and booped `owner`.
local function doBoop(sender: Player, owner: Player)
	if sender == owner then
		return
	end
	if not (PlayerDataService.isReady(sender) and PlayerDataService.isReady(owner)) then
		return
	end
	local a, b = rootPos(sender), rootPos(owner)
	if not a or not b or (a - b).Magnitude > BOOP_RANGE then
		return
	end
	local key = pairKey(sender.UserId, owner.UserId)
	local now = os.clock()
	if now - (lastBoop[key] or 0) < PAIR_COOLDOWN then
		return -- gently rate-limited: no boop-spam, no pile-on
	end
	lastBoop[key] = now

	local friend = areFriends(sender, owner)
	-- Names only between Roblox friends; everyone else is "a kind visitor".
	local info = {
		fromUserId = sender.UserId,
		toUserId = owner.UserId,
		tier = if friend then "friend" else "visitor",
		fromName = if friend then sender.DisplayName else "A kind visitor",
	}
	boopFxEvent:FireAllClients(info)
	toastEvent:FireClient(owner, "💖 " .. info.fromName .. " booped you!")
end

local function attachPrompt(owner: Player, character: Model)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root or root.Parent ~= character then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BoopPrompt"
		prompt.ObjectText = owner.DisplayName
		prompt.ActionText = "Boop! 💖"
		prompt.HoldDuration = 0.1
		prompt.MaxActivationDistance = PROMPT_DISTANCE
		prompt.RequiresLineOfSight = false
		-- so the client can hide it on my own character / for a blocked owner
		prompt:SetAttribute("OwnerUserId", owner.UserId)
		prompt.Parent = root
		prompt.Triggered:Connect(function(sender)
			doBoop(sender, owner)
		end)
	end)
end

function BoopService.init()
	boopFxEvent = Remotes.get(Remotes.BoopFx)
	toastEvent = Remotes.get(Remotes.Toast)

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			attachPrompt(player, character)
		end)
		if player.Character then
			attachPrompt(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local uid = player.UserId
		for key in pairs(lastBoop) do
			if key:find("^" .. uid .. "%-") or key:find("%-" .. uid .. "$") then
				lastBoop[key] = nil
			end
		end
	end)
end

return BoopService
