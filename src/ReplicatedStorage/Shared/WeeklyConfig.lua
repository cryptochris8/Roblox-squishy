--!strict
-- WeeklyConfig
-- "Friend of the Week": every week one of the special event friends comes to
-- visit Pudding Hills, and can be befriended DIRECTLY for Sparkle Coins — a
-- known price, never a gamble (doc 09's non-random direct-buy, coins-only).
-- Shared so the server (rotation + validation) and any client UI agree.

local WeeklyConfig = {}

-- Befriending the visitor costs earned Sparkle Coins only.
WeeklyConfig.Cost = 400

-- UTC week index (epoch-based). Everyone worldwide sees the same visitor.
function WeeklyConfig.weekIndex(): number
	return math.floor(os.time() / 604800)
end

-- Seconds until the next visitor arrives.
function WeeklyConfig.secondsLeft(): number
	return 604800 - (os.time() % 604800)
end

return WeeklyConfig
