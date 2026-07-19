--!strict
-- Telemetry (SERVER) — THE one wrapper over AnalyticsService. Ported from the
-- Rewind Files' proven module; nothing else in Squishy Smash touches
-- AnalyticsService, so engine API drift has exactly one file to break.
--
-- PRIVACY: this logs to Roblox's own first-party AnalyticsService ONLY — no
-- HttpService, no external endpoints, no PII in event names or values. The
-- audience is under 13; keep it that way.
--
-- NAMING CONVENTIONS (Creator Hub dashboards key on these strings):
--   · Funnel "ftue" — the once-ever new-player journey. Steps: 1 first_squish,
--     2 first_capsule, 3 first_shard, 4 first_travel, 5 sparkle_restored.
--     Pass sessionId = tostring(player.UserId) so the funnel is once-ever per
--     player (Roblox drops step repeats within a session server-side).
--   · Currency: "SparkleCoins" — the game's one currency, exact spelling.
--   · Transaction types ride as strings but MUST be
--     Enum.AnalyticsEconomyTransactionType member names ("Gameplay", "Shop",
--     "TimedReward") — validated here; typos warn instead of erroring.
--
-- FAILURE POLICY: telemetry is observability, and observability must never
-- take a server down. Every engine touch is pcall-guarded — INCLUDING the
-- method-existence probe, because indexing a service with a dead member name
-- throws. A distinct failure reason warns ONCE and then goes silent (a bad
-- call on a hot path would otherwise firehose the log every event), and the
-- call degrades to a no-op.

local AnalyticsService = game:GetService("AnalyticsService")

local Telemetry = {}

local warned: { [string]: boolean } = {}

local function warnOnce(reason: string)
	if warned[reason] then
		return
	end
	warned[reason] = true
	warn(`[SquishySmash] Telemetry: {reason} — further identical failures are silent`)
end

-- API-drift probe: resolve the method fresh each call (cheap — telemetry fires
-- a handful of times a minute, not per frame); a missing member yields nil
-- instead of throwing.
local function method(name: string): ((...any) -> ...any)?
	local ok, fn = pcall(function(): any
		return (AnalyticsService :: any)[name]
	end)
	if ok and typeof(fn) == "function" then
		return fn
	end
	return nil
end

local function callGuarded(methodName: string, ...: any)
	local fn = method(methodName)
	if fn == nil then
		warnOnce(`AnalyticsService.{methodName} is missing (engine API drift) — event dropped`)
		return
	end
	local ok, err = pcall(fn, AnalyticsService, ...)
	if not ok then
		warnOnce(`AnalyticsService.{methodName} rejected an event: {tostring(err)}`)
	end
end

-- Engine order is (player, funnelName, sessionId, step, stepName) — sessionId
-- sits in the MIDDLE, hence the reordered public signature (step is the field
-- every caller has; sessionId only matters for multi-session funnels).
function Telemetry.funnelStep(player: Player, funnelName: string, step: number, stepName: string?, sessionId: string?)
	callGuarded("LogFunnelStepEvent", player, funnelName, sessionId, step, stepName)
end

function Telemetry.economy(
	player: Player,
	flow: "Source" | "Sink",
	currency: string,
	amount: number,
	endingBalance: number,
	transactionType: string,
	sku: string?
)
	-- enum lookups throw on unknown members, so even validation is pcall'd
	local okFlow, flowItem = pcall(function(): any
		return (Enum.AnalyticsEconomyFlowType :: any)[flow]
	end)
	if not okFlow or typeof(flowItem) ~= "EnumItem" then
		warnOnce(`"{flow}" is not an AnalyticsEconomyFlowType — economy event dropped`)
		return
	end
	local okTx, txItem = pcall(function(): any
		return (Enum.AnalyticsEconomyTransactionType :: any)[transactionType]
	end)
	if not okTx or typeof(txItem) ~= "EnumItem" then
		warnOnce(`"{transactionType}" is not an AnalyticsEconomyTransactionType name — economy event dropped`)
		return
	end
	callGuarded("LogEconomyEvent", player, flowItem, currency, amount, endingBalance, transactionType, sku)
end

function Telemetry.custom(player: Player, eventName: string, value: number?)
	callGuarded("LogCustomEvent", player, eventName, value)
end

return Telemetry
