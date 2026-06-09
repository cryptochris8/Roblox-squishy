--!strict
-- VariantConfig
-- Friends you already own can be discovered again to "shine them up": a duplicate
-- upgrades that friend's variant (Discovered -> Sparkly -> Rainbow) instead of being
-- a miss. Long-tail collection depth with NO new art. Shared so the client (book +
-- reveal visuals) and server (award logic) always agree.

local VariantConfig = {}

VariantConfig.Max = 2 -- 0 = normal Discovered, 1 = Sparkly, 2 = Rainbow

-- Per level: display name, an accent colour, a little icon, and how many bonus
-- Sparkle Coins the upgrade grants.
VariantConfig.Levels = {
	[0] = { name = "", icon = "", color = Color3.fromRGB(255, 255, 255), bonusCoins = 0 },
	[1] = { name = "Sparkly", icon = "✨", color = Color3.fromRGB(120, 220, 255), bonusCoins = 30 },
	[2] = { name = "Rainbow", icon = "🌈", color = Color3.fromRGB(255, 140, 205), bonusCoins = 60 },
}

-- Coins for a duplicate of a friend who's already Rainbow (nothing left to upgrade).
VariantConfig.MaxDuplicateCoins = 25

function VariantConfig.nameFor(level: number): string
	local l = VariantConfig.Levels[level]
	return (l and l.name) or ""
end

function VariantConfig.iconFor(level: number): string
	local l = VariantConfig.Levels[level]
	return (l and l.icon) or ""
end

function VariantConfig.colorFor(level: number): Color3
	local l = VariantConfig.Levels[level]
	return (l and l.color) or Color3.fromRGB(255, 255, 255)
end

return VariantConfig
