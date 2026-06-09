--!strict
-- ZoneConfig
-- The three lands of Squishy Smash and the shard-quest chain that links them.
-- Single source of truth for zone setup: which friend pack + Sparkle Capsule each
-- zone uses, where it sits in the world, its shard quest (wake N friends -> shard
-- appears -> recover -> unlock the next land), and how the lands are ordered.
-- Shared so the server (world build, quests, capsules, travel) and the client
-- (HUD objective, travel UI) all agree.
--
-- Lands are laid out far apart on their own ground plates (600 studs between
-- centers, grounds are 320 wide) and connected by Travel Pads, unlocked by
-- recovering each land's Sparkle shard in order.

local ZoneConfig = {}

export type Zone = {
	name: string,
	packId: string,
	capsuleKey: string,
	center: Vector3,
	spawn: Vector3,
	shardSpot: Vector3,
	shardWakeGoal: number,
	shardRewardCoins: number,
	friendCount: number,
	unlocksNext: string?,
	alwaysUnlocked: boolean?,
}

-- The progression order (also the travel order).
ZoneConfig.Order = { "Pudding Hills", "Goo Coast", "Moonlit Hollow" }

ZoneConfig.Zones = {
	["Pudding Hills"] = {
		name = "Pudding Hills",
		packId = "launch_squishy_foods",
		capsuleKey = "StarterCapsule",
		center = Vector3.new(0, 0, 0),
		spawn = Vector3.new(0, 0.5, 34),
		shardSpot = Vector3.new(47, 0, -40),
		shardWakeGoal = 8,
		shardRewardCoins = 150,
		friendCount = 12,
		unlocksNext = "Goo Coast",
		alwaysUnlocked = true,
	},
	["Goo Coast"] = {
		name = "Goo Coast",
		packId = "goo_fidgets_drop_01",
		capsuleKey = "GooCapsule",
		center = Vector3.new(600, 0, 0),
		spawn = Vector3.new(600, 0.5, 34),
		shardSpot = Vector3.new(647, 0, -40),
		shardWakeGoal = 10,
		shardRewardCoins = 250,
		friendCount = 12,
		unlocksNext = "Moonlit Hollow",
	},
	["Moonlit Hollow"] = {
		name = "Moonlit Hollow",
		packId = "creepy_cute_pack_01",
		capsuleKey = "MoonlitCapsule",
		center = Vector3.new(1200, 0, 0),
		spawn = Vector3.new(1200, 0.5, 34),
		shardSpot = Vector3.new(1247, 0, -40),
		shardWakeGoal = 12,
		shardRewardCoins = 400,
		friendCount = 12,
		unlocksNext = nil, -- last land: recovering this shard triggers the finale
	},
}

function ZoneConfig.get(name: string): Zone?
	return ZoneConfig.Zones[name]
end

-- Zone configs in progression order.
function ZoneConfig.ordered(): { Zone }
	local list = {}
	for _, name in ipairs(ZoneConfig.Order) do
		list[#list + 1] = ZoneConfig.Zones[name]
	end
	return list
end

-- The land immediately before `name` in the chain (nil for the first).
function ZoneConfig.priorZone(name: string): string?
	for i, zoneName in ipairs(ZoneConfig.Order) do
		if zoneName == name then
			return ZoneConfig.Order[i - 1]
		end
	end
	return nil
end

return ZoneConfig
