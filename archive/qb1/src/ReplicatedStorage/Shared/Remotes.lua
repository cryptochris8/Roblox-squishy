--!strict
-- Remotes
-- A single source of truth for the names of our RemoteEvents, plus small
-- helpers so the server and client never disagree on spelling or location.
--
-- HOW IT WORKS:
--   * The SERVER calls Remotes.setupServer() once at startup. That creates a
--     Folder named "Remotes" in ReplicatedStorage and fills it with RemoteEvents.
--   * Roblox automatically replicates (copies) that folder to every client.
--   * Either side calls Remotes.get(name) to grab a RemoteEvent. On the client
--     this waits until the server has created it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

-- The name of the folder that will hold every RemoteEvent.
Remotes.FOLDER_NAME = "Remotes"

-- Event names. Use these constants everywhere so spelling can never drift.
Remotes.RoundUpdate = "RoundUpdate"   -- server -> all clients: round state + time
Remotes.ScoreUpdate = "ScoreUpdate"   -- server -> one client: their score
Remotes.ThrowRequest = "ThrowRequest" -- client -> server: "I tried to throw"

-- Every event name in one list, used by setupServer().
local ALL_EVENTS = {
	Remotes.RoundUpdate,
	Remotes.ScoreUpdate,
	Remotes.ThrowRequest,
}

-- SERVER ONLY: create the Remotes folder and its RemoteEvents.
-- Build everything first, then parent the folder LAST so clients never see a
-- half-built folder.
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

-- EITHER SIDE: get a RemoteEvent by name. Waits if it does not exist yet.
function Remotes.get(eventName: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(Remotes.FOLDER_NAME)
	return folder:WaitForChild(eventName) :: RemoteEvent
end

return Remotes
