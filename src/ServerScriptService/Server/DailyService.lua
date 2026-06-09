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

-- Reset a player's daily quest progress when the UTC day rolls over.
local function ensureToday(profile)
	if profile.DailyQuests.day ~= todayIndex() then
		profile.DailyQuests.day = todayIndex()
		profile.DailyQuests.progress = {}
		profile.DailyQuests.claimed = {}
	end
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
	for _, q in ipairs(DailyQuestConfig.forDay(dq.day)) do
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

-- On arrival: roll the gentle streak + give the login bonus (once per day).
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
	if profile.LastPlayDay > 0 and today == profile.LastPlayDay + 1 then
		profile.StreakDays += 1
	else
		profile.StreakDays = 1
	end
	profile.LastPlayDay = today
	local steps = math.min(profile.StreakDays, GameConfig.StreakMaxForBonus) - 1
	local bonus = GameConfig.StreakBaseBonus + GameConfig.StreakPerDay * steps
	PlayerDataService.addCoins(player, bonus)
	toastEvent:FireClient(player, "🔥 Day " .. profile.StreakDays .. " streak!  +" .. bonus .. " Sparkle Coins")
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
	if CapsuleService.tryOpen(player, true) then
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
