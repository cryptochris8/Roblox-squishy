-- Squishy Smash Roblox - Rarity configuration
-- Weight is the LIVE capsule draw weight (out of 100): CapsuleConfig builds its
-- RarityWeights from this table, so this is the ONE source of truth (unified
-- 2026-08-06; the tables used to diverge — doc 14 §2 landmine). Mythic is the
-- TOP tier (SortOrder 5) and therefore also the RAREST draw (3/100) — these two
-- columns must stay in agreement (they were once swapped; doc 15 §3).
return {
    common = { DisplayName = "Common", Weight = 50, SortOrder = 1, KidFriendlyReveal = "A cozy friend appeared!" },
    rare = { DisplayName = "Rare", Weight = 26, SortOrder = 2, KidFriendlyReveal = "A sparkly friend appeared!" },
    epic = { DisplayName = "Epic", Weight = 14, SortOrder = 3, KidFriendlyReveal = "An amazing friend appeared!" },
    legendary = { DisplayName = "Legendary", Weight = 7, SortOrder = 4, KidFriendlyReveal = "A legendary friend appeared!" },
    mythic = { DisplayName = "Mythic", Weight = 3, SortOrder = 5, KidFriendlyReveal = "A mythic Sparkle friend appeared!" },
    -- Family: the three daughter cards. Weight 0 so a capsule NEVER rolls them
    -- (they're earned by restoring each land's shard, via FamilyService).
    family = { DisplayName = "Family", Weight = 0, SortOrder = 6, KidFriendlyReveal = "A beloved Family friend appeared!" },
}
