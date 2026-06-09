--!strict
-- SurgeService (SERVER)
-- The server-wide Sparkle Surge meter: every Happy Pop by ANYONE fills one shared
-- meter (the goal scales with how many friends are online). When it fills, a
-- Sparkle Surge starts — DOUBLE Sparkle Coins for everyone for a little while —
-- then the meter starts fresh. Solo-reachable, but it really hums with a crowd.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local SocialConfig = require(Shared:WaitForChild("SocialConfig"))

local SurgeService = {}

local socialSyncEvent: RemoteEvent
local toastEvent: RemoteEvent

local meter = 0
local surgeEndsAt = 0 -- os.clock() when the active surge ends (0 = no surge)

local function goal(): number
	local n = math.max(1, #Players:GetPlayers())
	return math.clamp(n * SocialConfig.SurgePopsPerPlayer, SocialConfig.SurgeGoalMin, SocialConfig.SurgeGoalMax)
end

function SurgeService.isActive(): boolean
	return os.clock() < surgeEndsAt
end

-- What to multiply coin awards by right now (1 outside a surge).
function SurgeService.coinMultiplier(): number
	return if SurgeService.isActive() then SocialConfig.SurgeCoinMultiplier else 1
end

-- A compact snapshot for the client HUD. Sends seconds REMAINING (not clocks),
-- so the client can count down on its own time.
function SurgeService.snapshot()
	return {
		meter = meter,
		goal = goal(),
		active = SurgeService.isActive(),
		remaining = math.max(0, surgeEndsAt - os.clock()),
		multiplier = SocialConfig.SurgeCoinMultiplier,
	}
end

local function broadcast()
	socialSyncEvent:FireAllClients({ surge = SurgeService.snapshot() })
end

function SurgeService.syncTo(player: Player)
	socialSyncEvent:FireClient(player, { surge = SurgeService.snapshot() })
end

-- Starts a surge right now (the meter's payoff; also an owner playtest trigger).
function SurgeService.startNow()
	if SurgeService.isActive() then
		return
	end
	meter = 0
	surgeEndsAt = os.clock() + SocialConfig.SurgeDurationSeconds
	toastEvent:FireAllClients("✨ SPARKLE SURGE! Everyone earns DOUBLE Sparkle Coins — squish squish squish! ✨")
	broadcast()
	task.delay(SocialConfig.SurgeDurationSeconds + 0.05, function()
		broadcast() -- the surge just ended; show everyone the fresh meter
	end)
end

-- Called (via Main) on every Happy Pop anywhere in the world.
function SurgeService.notePop(_player: Player, _def: any)
	if SurgeService.isActive() then
		return -- the meter rests while the surge itself is running
	end
	meter += 1
	if meter >= goal() then
		SurgeService.startNow()
	else
		broadcast()
	end
end

function SurgeService.init()
	socialSyncEvent = Remotes.get(Remotes.SocialSync)
	toastEvent = Remotes.get(Remotes.Toast)

	-- The goal scales with the team size, so keep every HUD honest when it changes
	-- (and if a smaller team means the meter is suddenly full, celebrate it).
	Players.PlayerAdded:Connect(function()
		task.defer(broadcast)
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			if not SurgeService.isActive() and meter >= goal() then
				SurgeService.startNow()
			else
				broadcast()
			end
		end)
	end)
end

return SurgeService
