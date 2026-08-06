-- Squishy Smash Roblox - Capsule configuration
-- One Sparkle Capsule per land, each drawing from that land's friend pack. Capsules
-- are opened with EARNED Sparkle Coins (never Robux). pickRarity auto-skips any
-- rarity a pack doesn't contain and renormalizes, so a shared weight table is fine.
-- Weights come from RarityConfig (the one source of truth — unified 2026-08-06);
-- family stays out of every capsule via its Weight = 0.
local RarityConfig = require(script.Parent.RarityConfig)

local RARITY_WEIGHTS: { [string]: number } = {}
for rarity, cfg in pairs(RarityConfig) do
    if cfg.Weight and cfg.Weight > 0 then
        RARITY_WEIGHTS[rarity] = cfg.Weight
    end
end

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
