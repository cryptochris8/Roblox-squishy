--!strict
-- CollectionService (SERVER)
-- Handles the Squishy Book's "Equip Buddy" action. The collection data itself
-- lives in PlayerDataService; this service just validates equip requests (you
-- can only equip a friend you've discovered) and confirms them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local SquishyData = require(Shared:WaitForChild("SquishyData"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local CollectionService = {}

local toastEvent: RemoteEvent

-- Set by Main: notified with (player, defId | nil) whenever the equipped buddy
-- changes, so BuddyService can spawn / replace / remove the companion model.
CollectionService.onBuddyChanged = nil :: ((Player, string?) -> ())?

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
	-- Tapping the friend who's already your buddy puts them away again (toggle).
	local profile = PlayerDataService.get(player)
	local alreadyBuddy = profile ~= nil and profile.EquippedBuddyId == defId
	local newId: string? = if alreadyBuddy then nil else (defId :: string)

	PlayerDataService.setBuddy(player, newId)
	if newId then
		toastEvent:FireClient(player, def.DisplayName .. " is now your buddy!")
	else
		toastEvent:FireClient(player, def.DisplayName .. " is having a little rest now.")
	end
	if CollectionService.onBuddyChanged then
		CollectionService.onBuddyChanged(player, newId)
	end
	PlayerDataService.sync(player)
end

function CollectionService.init()
	toastEvent = Remotes.get(Remotes.Toast)

	local equipRequest = Remotes.get(Remotes.EquipBuddyRequest)
	equipRequest.OnServerEvent:Connect(function(player, defId)
		CollectionService.equipBuddy(player, defId)
	end)
end

return CollectionService
