--!strict
-- CodesConfig (SERVER-side only — never put this in ReplicatedStorage)
-- The magic-word table, extracted from CodeService so adding a code is a
-- one-line edit here + the weekly Friday publish (doc 15 §7.2: codes are a
-- PRESS CHANNEL — 2 scheduled codes/month + one per named update, and codes
-- NEVER expire, which is both the Law's no-LAST-CHANCE rule and our best
-- editorial hook: every codes article about us stays evergreen).
--
-- Reward shape: { coins: number, cosmetic: string? } — small, safe coin gifts
-- (no power), optionally a keepsake cosmetic that stays redeemable forever.

export type CodeReward = { coins: number, cosmetic: string? }

local CODES: { [string]: CodeReward } = {
	-- Storybook words (printed in the picture books). The two BOOK words each
	-- grant the exclusive Storybook Halo — a keepsake you can't get any other way.
	SPLOINK = { coins = 150 },
	THUP = { coins = 150 },
	PMF = { coins = 200 },
	EVERYSQUISH = { coins = 250 },
	LOSTSPARKLE = { coins = 300, cosmetic = "hat_storybook_halo" }, -- Book 2 "The Lost Sparkle"
	MEETTHESQUISHIES = { coins = 300, cosmetic = "hat_storybook_halo" }, -- Book 1 "Meet the Squishies"
	-- Channel words (end-cards on the videos) — coins only; redemptions per code
	-- tell us which channel actually drives real plays.
	TIKTOK = { coins = 250 },
	SHORTS = { coins = 250 },
	YOUTUBE = { coins = 250 },
	DISCORD = { coins = 250 },
	SPARKLE = { coins = 200 },
	-- Named-update words (added with each update's press beat; never expire).
	SPARKLEPATTERNS = { coins = 250 }, -- The Sparkle Patterns Update
	ALLABOARD = { coins = 250 }, -- The Switcheroo Station opening
}

return CODES
