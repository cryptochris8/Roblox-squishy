-- DailyService (SERVER)
-- "Daily reasons to return" — currently a free Sparkle Capsule each day. Daily
-- quests + a gentle streak will live here too. All resets are UTC-day based and
-- server-authoritative; the capsule stays FREE (opened as a gift, never Robux).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local DailyQuestConfig = require(Shared:WaitForChild("DailyQuestConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)
local CapsuleService = require(script.Parent.CapsuleService)

local DailyService = {}

local toastEvent: RemoteEvent

local function todayIndex(): number
	return math.floor(os.time() / 86400)
end

local function pinnedIdsFor(dayIndex: number): { string }
	local ids = {}
	for _, q in ipairs(DailyQuestConfig.forDay(dayIndex)) do
		ids[#ids + 1] = q.id
	end
	return ids
end

-- Reset a player's daily quest progress when the UTC day rolls over, and PIN
-- the day's three quests into the profile.
--
-- Pinning matters because forDay() derives the set from `dayIndex % #Quests`:
-- the moment the roster grows (it went 6 -> 7 when the Switcheroo shipped) the
-- CURRENT day silently re-rolls to a different three for everyone mid-session,
-- while `claimed` — keyed by quest id — carries over. Every live player could
-- then claim a second full set of the day's rewards. Pinned, the set is a
-- property of the day she actually played, and adding quest #8 later is safe.
local function ensureToday(profile)
	local dq = profile.DailyQuests
	if dq.day ~= todayIndex() then
		dq.day = todayIndex()
		dq.progress = {}
		dq.claimed = {}
		dq.ids = pinnedIdsFor(dq.day)
	elseif type(dq.ids) ~= "table" or #dq.ids == 0 then
		-- saved before pinning existed: adopt today's set as-is
		dq.ids = pinnedIdsFor(dq.day)
	end
end

-- The quests actually active for this profile today (pinned ids, resolved).
local function activeQuests(profile)
	local out = {}
	for _, id in ipairs(profile.DailyQuests.ids) do
		local q = DailyQuestConfig.byId(id)
		if q then
			out[#out + 1] = q
		end
	end
	return out
end

-- Advances any matching daily quest when a tracked thing happens (pop, bit,
-- capsule open, new discovery) and auto-awards coins on completion.
function DailyService.noteEvent(player: Player, eventType: string)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	ensureToday(profile)
	local dq = profile.DailyQuests
	local changed = false
	for _, q in ipairs(activeQuests(profile)) do
		if q.type == eventType and not dq.claimed[q.id] then
			local cur = (dq.progress[q.id] or 0) + 1
			dq.progress[q.id] = cur
			changed = true
			if cur >= q.goal then
				dq.claimed[q.id] = true
				PlayerDataService.addCoins(player, q.reward)
				toastEvent:FireClient(player, "Daily Quest done — " .. string.format(q.text, q.goal) .. "!  +" .. q.reward .. " Sparkle Coins")
			end
		end
	end
	if changed then
		PlayerDataService.sync(player)
	end
end

-- On arrival: count the lifetime Sparkle Day + give the login bonus (once per
-- day). The consecutive-day streak is INTERNAL — it only sizes the bonus (with
-- a grace day, so one missed day never shrinks it). Nothing the player sees
-- ever goes down: the visible number is SparkleDays, which only counts up.
function DailyService.onJoin(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	ensureToday(profile)
	local today = todayIndex()
	if today <= profile.LastPlayDay then
		return
	end
	-- gap of 1 = consecutive, gap of 2 = the grace day; both keep the bonus ramp
	if profile.LastPlayDay > 0 and today <= profile.LastPlayDay + 2 then
		profile.StreakDays += 1
	else
		profile.StreakDays = 1
	end
	profile.LastPlayDay = today
	profile.SparkleDays += 1
	-- Fresh Sparkle Bits scattered for the new day, so the hunt (and the daily
	-- "find Sparkle Bits" quest) renews. The friends Book is the lasting collection.
	profile.SparkleBits = {}
	local steps = math.min(profile.StreakDays, GameConfig.StreakMaxForBonus) - 1
	local bonus = GameConfig.StreakBaseBonus + GameConfig.StreakPerDay * steps
	PlayerDataService.addCoins(player, bonus)
	toastEvent:FireClient(player, "⭐ Sparkle Day " .. profile.SparkleDays .. "!  +" .. bonus .. " Sparkle Coins")
	PlayerDataService.sync(player)
end

function DailyService.claimDailyCapsule(player: Player)
	if not PlayerDataService.isReady(player) then
		return
	end
	if not PlayerDataService.isDailyCapsuleReady(player) then
		toastEvent:FireClient(player, "Your free Sparkle Capsule will be ready again tomorrow!")
		return
	end
	-- Open a FREE capsule; only spend the day's claim if it actually opened.
	-- atCapsule = false: this is the HUD 🎁 button, claimable from any land.
	if CapsuleService.tryOpen(player, "StarterCapsule", true, false) then
		PlayerDataService.markDailyCapsuleClaimed(player)
		PlayerDataService.sync(player)
	end
end

function DailyService.init()
	toastEvent = Remotes.get(Remotes.Toast)
	local claim = Remotes.get(Remotes.ClaimDailyCapsule)
	claim.OnServerEvent:Connect(function(player)
		DailyService.claimDailyCapsule(player)
	end)
end

return DailyService
