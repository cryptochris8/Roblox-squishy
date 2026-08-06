--!strict
-- CollectionService (SERVER)
-- Handles the Squishy Book's "Equip Buddy" action. The collection data itself
-- lives in PlayerDataService; this service just validates equip requests (you
-- can only equip a friend you've discovered) and confirms them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local SquishyData = require(Shared:WaitForChild("SquishyData"))
local PatternConfig = require(Shared:WaitForChild("PatternConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)
local MonetizationService = require(script.Parent.MonetizationService)

local CollectionService = {}

local toastEvent: RemoteEvent

-- Set by Main: notified whenever the equipped buddies change, so BuddyService
-- can respawn the companion models from the profile.
CollectionService.onBuddyChanged = nil :: ((Player) -> ())?

function CollectionService.equipBuddy(player: Player, defId: any)
	if type(defId) ~= "string" then
		return
	end
	local def = SquishyData.getById(defId)
	if not def then
		return
	end
	if not PlayerDataService.hasDiscovered(player, defId) then
		toastEvent:FireClient(player, "Discover " .. def.DisplayName .. " first to make them your buddy!")
		return
	end
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	-- Tapping an equipped friend puts them away (either slot). Otherwise fill
	-- the first free slot — owners of the Extra Buddy Slot pass have two.
	local hasTwoSlots = MonetizationService.ownsPass(player, "BuddySlot")
	if profile.EquippedBuddyId == defId then
		PlayerDataService.setBuddy(player, nil)
		toastEvent:FireClient(player, def.DisplayName .. " is having a little rest now.")
	elseif profile.EquippedBuddyId2 == defId then
		PlayerDataService.setBuddy2(player, nil)
		toastEvent:FireClient(player, def.DisplayName .. " is having a little rest now.")
	elseif profile.EquippedBuddyId == nil then
		PlayerDataService.setBuddy(player, defId)
		toastEvent:FireClient(player, def.DisplayName .. " is now your buddy!")
	elseif hasTwoSlots and profile.EquippedBuddyId2 == nil then
		PlayerDataService.setBuddy2(player, defId)
		toastEvent:FireClient(player, def.DisplayName .. " joins the buddy team! 🧸🧸")
	elseif hasTwoSlots then
		PlayerDataService.setBuddy2(player, defId)
		toastEvent:FireClient(player, def.DisplayName .. " tags in as your second buddy!")
	else
		PlayerDataService.setBuddy(player, defId)
		toastEvent:FireClient(player, def.DisplayName .. " is now your buddy!")
	end
	if CollectionService.onBuddyChanged then
		CollectionService.onBuddyChanged(player)
	end
	PlayerDataService.sync(player)
end

-- Wear an owned Sparkle Pattern (or go back to Classic). Server-validated in
-- PlayerDataService.setWornPattern: only discovered friends, only owned
-- patterns. The buddy re-dresses on the spot if that friend is walking.
function CollectionService.wearPattern(player: Player, friendId: any, patternId: any)
	if type(friendId) ~= "string" or (patternId ~= nil and type(patternId) ~= "string") then
		return
	end
	local def = SquishyData.getById(friendId)
	if not def then
		return
	end
	if not PlayerDataService.setWornPattern(player, friendId, patternId) then
		return
	end
	if patternId == nil or patternId == PatternConfig.ClassicId then
		toastEvent:FireClient(player, def.DisplayName .. " is back to their classic look!")
	else
		toastEvent:FireClient(player, "✨ " .. def.DisplayName .. " is wearing " .. PatternConfig.nameFor(patternId) .. "!")
	end
	local profile = PlayerDataService.get(player)
	if profile and (profile.EquippedBuddyId == friendId or profile.EquippedBuddyId2 == friendId)
		and CollectionService.onBuddyChanged then
		CollectionService.onBuddyChanged(player)
	end
	PlayerDataService.sync(player)
end

function CollectionService.init()
	toastEvent = Remotes.get(Remotes.Toast)

	local equipRequest = Remotes.get(Remotes.EquipBuddyRequest)
	equipRequest.OnServerEvent:Connect(function(player, defId)
		CollectionService.equipBuddy(player, defId)
	end)

	local wearRequest = Remotes.get(Remotes.WearPattern)
	wearRequest.OnServerEvent:Connect(function(player, friendId, patternId)
		CollectionService.wearPattern(player, friendId, patternId)
	end)
end

return CollectionService
