--!strict
-- FirstDayService (SERVER)
-- Watches the signals the profile already tracks and pays each "My First Day"
-- step the moment it completes (toast + coins, no claim button). Main calls
-- check() from the relevant hooks; the snapshot carries done/paid per step so
-- the client panel and world markers stay honest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local FirstDayConfig = require(Shared:WaitForChild("FirstDayConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local FirstDayService = {}

local toastEvent: RemoteEvent
-- room visits aren't persisted, so remember them per session (the step pays
-- once and the payment IS persisted, so this only needs to live until paid)
local visitedRoom: { [Player]: boolean } = {}

local function stepDone(player: Player, profile, stepId: string): boolean
	if stepId == "squish1" then
		return profile.TotalSquishes >= 1
	elseif stepId == "wake3" then
		return profile.TotalHappyPops >= 3
	elseif stepId == "capsule" then
		return profile.FirstCapsuleClaimed
	elseif stepId == "buddy" then
		return profile.EquippedBuddyId ~= nil
	elseif stepId == "room" then
		return visitedRoom[player] == true or next(profile.Room.Owned) ~= nil
	end
	return false
end

-- Pays any newly completed steps. Safe to call often.
function FirstDayService.check(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	local changed = false
	for _, step in ipairs(FirstDayConfig.Steps) do
		if not profile.FirstDayPaid[step.id] and stepDone(player, profile, step.id) then
			profile.FirstDayPaid[step.id] = true
			changed = true
			if step.reward > 0 then
				PlayerDataService.addCoins(player, step.reward)
				toastEvent:FireClient(player, step.icon .. " " .. step.text .. "  Done!  +" .. step.reward .. " Sparkle Coins!")
			end
		end
	end
	if changed then
		local allDone = true
		for _, step in ipairs(FirstDayConfig.Steps) do
			if not profile.FirstDayPaid[step.id] then
				allDone = false
				break
			end
		end
		if allDone then
			toastEvent:FireClient(player, "🌟 You finished your First Day list — you're a real Squishy friend now!")
		end
		PlayerDataService.sync(player)
	end
end

function FirstDayService.noteRoomVisit(player: Player)
	visitedRoom[player] = true
	FirstDayService.check(player)
end

function FirstDayService.init()
	toastEvent = Remotes.get(Remotes.Toast)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		visitedRoom[player] = nil
	end)
end

return FirstDayService
