-- RevealConfig
-- The Sparkle Capsule ceremony, tier by tier ("The Wobble Count", doc 15 §5).
-- Shared so the client ceremony and the server beacon threshold always agree.
--
-- THE HONESTY RULE (never violate): every telegraph channel — wobble count,
-- glow colour, chime pitch — is a pure monotone function of the rarity the
-- player ACTUALLY got. Nothing may ever overshoot the true tier, reference a
-- tier the player didn't get, or fake a near-miss. Suspense comes only from
-- not knowing whether another wobble is coming. There are no misses.

local RevealConfig = {}

-- One chime per wobble, rising: pitch(i) = ChimeBasePitch + (i-1) * ChimePitchStep.
RevealConfig.ChimeBasePitch = 1.0
RevealConfig.ChimePitchStep = 0.12
RevealConfig.GiftChimeBasePitch = 0.9 -- gift reveals ring a warmer interval

-- Per tier:
--   wobbles     how many times the capsule rocks (THE telegraph — countable)
--   wobbleDur   seconds per rock
--   dimT        background dim's final BackgroundTransparency (lower = deeper hush)
--   risePx      how far the capsule levitates before the pop (0 = stays put)
--   preHold     held-breath pause after the last wobble (seconds)
--   slowMo      slow-motion inflate duration before the pop (legendary+ only)
--   cardStyle   "pop" | "flip" | "slowflip"
--   flipDur     card flip duration (flip/slowflip styles)
--   shineDur    shine-sweep duration across the landed card (0 = none)
--   rayLayers   rotating ray-wheel layers behind the risen capsule (0/1/2)
--   starRain    drifting star motes during the ceremony
--   burst       sparkle-burst size at the pop (RevealFx budget still applies)
--   afterBurst  a second, smaller delayed burst (0 = none)
--   total       approx seconds to the buttons row (drives the tier-aware watchdog)
RevealConfig.Tiers = {
	common = {
		wobbles = 1, wobbleDur = 0.22, dimT = 0.65, risePx = 0, preHold = 0,
		slowMo = 0, cardStyle = "pop", flipDur = 0, shineDur = 0, rayLayers = 0,
		starRain = false, burst = 12, afterBurst = 0, total = 1.2,
	},
	rare = {
		wobbles = 2, wobbleDur = 0.24, dimT = 0.55, risePx = 0, preHold = 0.12,
		slowMo = 0, cardStyle = "pop", flipDur = 0, shineDur = 0.35, rayLayers = 0,
		starRain = false, burst = 22, afterBurst = 8, total = 2.2,
	},
	epic = {
		wobbles = 3, wobbleDur = 0.26, dimT = 0.45, risePx = 20, preHold = 0.25,
		slowMo = 0, cardStyle = "flip", flipDur = 0.45, shineDur = 0.35, rayLayers = 0,
		starRain = false, burst = 36, afterBurst = 12, total = 3.6,
	},
	legendary = {
		wobbles = 4, wobbleDur = 0.28, dimT = 0.30, risePx = 60, preHold = 0,
		slowMo = 0.5, cardStyle = "slowflip", flipDur = 0.8, shineDur = 0.6, rayLayers = 1,
		starRain = true, burst = 60, afterBurst = 0, total = 5.8,
	},
	mythic = {
		wobbles = 5, wobbleDur = 0.28, dimT = 0.28, risePx = 60, preHold = 0,
		slowMo = 0.6, cardStyle = "slowflip", flipDur = 0.9, shineDur = 0.6, rayLayers = 2,
		starRain = true, burst = 60, afterBurst = 40, total = 6.4,
	},
	-- The three daughter cards: the full legendary ceremony in heart-rose, with
	-- hearts falling instead of stars (used if a Family grant ever routes here).
	family = {
		wobbles = 4, wobbleDur = 0.28, dimT = 0.30, risePx = 60, preHold = 0,
		slowMo = 0.5, cardStyle = "slowflip", flipDur = 0.8, shineDur = 0.6, rayLayers = 1,
		starRain = true, hearts = true, burst = 60, afterBurst = 0, total = 5.8,
	},
}

-- The social beat: a NEW discovery at this SortOrder or above (see RarityConfig;
-- 3 = epic) — or a Rainbow shine-up — fires the in-world Sparkle Beacon plus the
-- one-tap Cheer toast instead of the plain text shout-out.
RevealConfig.BeaconMinSortOrder = 3

-- Cheer validation (server) + aggregation (client). Love-bombing is mechanically
-- impossible: one cheer per person per reveal, a per-pair cooldown on top, and
-- the discoverer's screen aggregates ("3 friends cheered!") instead of stacking.
RevealConfig.CheerWindowSeconds = 60 -- a reveal accepts cheers this long
RevealConfig.CheerPairCooldownSeconds = 30 -- same pair can't re-cheer sooner (across reveals)
RevealConfig.CheerAggregateSeconds = 10 -- client folds cheers this close into one line

return RevealConfig
