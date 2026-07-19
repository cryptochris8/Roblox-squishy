--!strict
-- BadgeService (SERVER)
-- Awards the achievement badges — free platform trophies that live on a kid's
-- Roblox profile (playground bragging rights outside the game). Ported from
-- Gnarly Nutmeg's proven pattern: ids come from BadgeConfig (Chris pastes them
-- from Creator Hub; 0 = not created yet and that badge silently no-ops),
-- every call is fire-and-forget and pcall-guarded, and awarding never touches
-- game flow.
--
-- A per-server session cache keeps repeat calls (e.g. FirstHappyPop on every
-- pop) from hitting UserHasBadgeAsync more than once per player per key.

local Players = game:GetService("Players")
local RobloxBadgeService = game:GetService("BadgeService")

local BadgeConfig = require(script.Parent.BadgeConfig)

local BadgeService = {}

-- player -> { [badgeKey]: true } — "already awarded or confirmed this session"
local sessionDone: { [Player]: { [string]: boolean } } = {}

Players.PlayerRemoving:Connect(function(player)
	sessionDone[player] = nil
end)

function BadgeService.award(player: Player, key: string)
	local id = (BadgeConfig :: { [string]: number })[key]
	if type(id) ~= "number" or id == 0 then
		return
	end
	local done = sessionDone[player]
	if not done then
		done = {}
		sessionDone[player] = done
	end
	if done[key] then
		return
	end
	done[key] = true
	task.spawn(function()
		pcall(function()
			if not RobloxBadgeService:UserHasBadgeAsync(player.UserId, id) then
				RobloxBadgeService:AwardBadgeAsync(player.UserId, id)
			end
		end)
	end)
end

-- The discovery ladder in one call (Main passes the current DiscoveredCount).
function BadgeService.discoveryCount(player: Player, count: number)
	if count >= 1 then
		BadgeService.award(player, "FirstDiscovery")
	end
	if count >= 10 then
		BadgeService.award(player, "Friends10")
	end
	if count >= 25 then
		BadgeService.award(player, "Friends25")
	end
	if count >= 48 then
		BadgeService.award(player, "Friends48")
	end
end

-- "Pudding Hills" -> the ShardPuddingHills badge, etc.
function BadgeService.shard(player: Player, zoneName: string)
	BadgeService.award(player, "Shard" .. zoneName:gsub(" ", ""))
end

return BadgeService
