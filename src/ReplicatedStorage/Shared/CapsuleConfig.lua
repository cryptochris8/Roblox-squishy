-- Squishy Smash Roblox - Capsule configuration
-- One Sparkle Capsule per land, each drawing from that land's friend pack. Capsules
-- are opened with EARNED Sparkle Coins (never Robux). pickRarity auto-skips any
-- rarity a pack doesn't contain and renormalizes, so a shared weight table is fine.
local RARITY_WEIGHTS = { common = 50, rare = 26, epic = 14, mythic = 7, legendary = 3 }

return {
    StarterCapsule = {
        DisplayName = "Sparkle Capsule",
        Cost = 100,
        AllowedPackIds = { "launch_squishy_foods" },
        RarityWeights = RARITY_WEIGHTS,
        DuplicateRewardCoins = 25,
    },
    GooCapsule = {
        DisplayName = "Goo Capsule",
        Cost = 100,
        AllowedPackIds = { "goo_fidgets_drop_01" },
        RarityWeights = RARITY_WEIGHTS,
        DuplicateRewardCoins = 25,
    },
    MoonlitCapsule = {
        DisplayName = "Moonlit Capsule",
        Cost = 100,
        AllowedPackIds = { "creepy_cute_pack_01" },
        RarityWeights = RARITY_WEIGHTS,
        DuplicateRewardCoins = 25,
    },
}
