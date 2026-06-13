-- Squishy Smash Roblox - Rarity configuration
return {
    common = { DisplayName = "Common", Weight = 55, SortOrder = 1, KidFriendlyReveal = "A cozy friend appeared!" },
    rare = { DisplayName = "Rare", Weight = 25, SortOrder = 2, KidFriendlyReveal = "A sparkly friend appeared!" },
    epic = { DisplayName = "Epic", Weight = 12, SortOrder = 3, KidFriendlyReveal = "An amazing friend appeared!" },
    legendary = { DisplayName = "Legendary", Weight = 6, SortOrder = 4, KidFriendlyReveal = "A legendary friend appeared!" },
    mythic = { DisplayName = "Mythic", Weight = 2, SortOrder = 5, KidFriendlyReveal = "A mythic Sparkle friend appeared!" },
    -- Family: the three daughter cards. Weight 0 so a capsule NEVER rolls them
    -- (they're earned by restoring each land's shard, via FamilyService).
    family = { DisplayName = "Family", Weight = 0, SortOrder = 6, KidFriendlyReveal = "A beloved Family friend appeared!" },
}
