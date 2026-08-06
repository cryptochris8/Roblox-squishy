-- SwitcherooConfig
-- The Switcheroo Station (doc 15 §6): kid-safe swaps under the amended doc-14
-- Law. Only SPARE copies travel (copies beyond what discovery + variant
-- progression consumed — the last copy is unswappable by ARITHMETIC, not
-- policy), rarity is always exact-matched, every swap ends in something
-- (discovery, variant step, or coins + a banked spare), and there is no
-- counterparty in Phase 1 at all — the Sparkle Express carries spares between
-- worlds. Shared so the server validator and the client UI always agree.

local SwitcherooConfig = {}

-- Adventures (deposits) per UTC day. Enough for the ritual, no farm. The cap
-- message always promises tomorrow ("The Express is resting its wheels —
-- more adventures tomorrow!"); nothing on screen ever counts down.
SwitcherooConfig.DailyCap = 3

-- Cross-server pools: one DataStore key per rarity tier. Entries age out
-- silently past the cap (no player is ever owed a pool entry).
SwitcherooConfig.PoolStoreName = "SwitcherooPools_v1"
SwitcherooConfig.PoolKeyPrefix = "pool_"
SwitcherooConfig.PoolMaxEntries = 150

-- The mystery draw prefers friends the depositor hasn't discovered, 4:1.
SwitcherooConfig.UndiscoveredWeight = 4

-- Travel Stamp tiers — additive badges on a friend's card, never lost.
SwitcherooConfig.StampTiers = {
	{ travels = 3, name = "Well-Traveled" },
	{ travels = 7, name = "World Wanderer" },
}

-- The Swap Stories ring buffer kept in the profile (a future Book journal page).
SwitcherooConfig.StoriesMax = 30

function SwitcherooConfig.stampTierName(travels: number): string?
	local best = nil
	for _, tier in ipairs(SwitcherooConfig.StampTiers) do
		if travels >= tier.travels then
			best = tier.name
		end
	end
	return best
end

return SwitcherooConfig
