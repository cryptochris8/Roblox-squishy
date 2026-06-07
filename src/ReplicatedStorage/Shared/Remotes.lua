--!strict
-- Remotes
-- One source of truth for our RemoteEvent names, plus helpers so the server and
-- client never disagree. The SERVER calls setupServer() once at startup to create
-- a folder of RemoteEvents in ReplicatedStorage; either side calls get(name).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

Remotes.FOLDER_NAME = "SquishyRemotes"

-- client -> server
Remotes.RequestInitialState = "RequestInitialState" -- "I'm ready, send me my state"
Remotes.EquipBuddyRequest = "EquipBuddyRequest"      -- defId: equip a discovered friend

-- server -> client
Remotes.StateSync = "StateSync"         -- full player snapshot (coins, discovered, quest...)
Remotes.SquishResult = "SquishResult"   -- a friend was squished / Happy Popped (to everyone)
Remotes.CapsuleResult = "CapsuleResult" -- a Sparkle Capsule reveal result
Remotes.BuddyEquipped = "BuddyEquipped" -- confirm an equipped buddy
Remotes.Toast = "Toast"                 -- a small friendly message

local ALL_EVENTS = {
	Remotes.RequestInitialState,
	Remotes.EquipBuddyRequest,
	Remotes.StateSync,
	Remotes.SquishResult,
	Remotes.CapsuleResult,
	Remotes.BuddyEquipped,
	Remotes.Toast,
}

-- SERVER ONLY: build the folder + RemoteEvents, then parent the folder LAST so
-- clients never see a half-built folder.
function Remotes.setupServer(): Folder
	local folder = Instance.new("Folder")
	folder.Name = Remotes.FOLDER_NAME
	for _, eventName in ipairs(ALL_EVENTS) do
		local event = Instance.new("RemoteEvent")
		event.Name = eventName
		event.Parent = folder
	end
	folder.Parent = ReplicatedStorage
	return folder
end

-- EITHER SIDE: get a RemoteEvent by name (waits until it exists).
function Remotes.get(eventName: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(Remotes.FOLDER_NAME)
	return folder:WaitForChild(eventName) :: RemoteEvent
end

return Remotes
