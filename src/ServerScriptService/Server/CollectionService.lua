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

local buddyEquippedEvent: RemoteEvent
local toastEvent: RemoteEvent

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
	PlayerDataService.setBuddy(player, defId)
	buddyEquippedEvent:FireClient(player, defId)
	toastEvent:FireClient(player, def.DisplayName .. " is now your buddy!")
	PlayerDataService.sync(player)
end

function CollectionService.init()
	buddyEquippedEvent = Remotes.get(Remotes.BuddyEquipped)
	toastEvent = Remotes.get(Remotes.Toast)

	local equipRequest = Remotes.get(Remotes.EquipBuddyRequest)
	equipRequest.OnServerEvent:Connect(function(player, defId)
		CollectionService.equipBuddy(player, defId)
	end)
end

return CollectionService
