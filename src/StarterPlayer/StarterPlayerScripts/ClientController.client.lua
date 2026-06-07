-- ClientController (CLIENT ENTRY POINT)
-- Boots the Squishy Smash client: builds the HUD, Squishy Book, capsule reveal,
-- and toast UIs, sets up the in-world squish feedback, and routes the server's
-- messages to the right place. The server stays the authority for everything
-- that matters (coins, discoveries, Joy); the client just makes it feel cozy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local here = script.Parent
local UiTheme = require(here:WaitForChild("UiTheme"))
local ToastUI = require(here:WaitForChild("ToastUI"))
local HudUI = require(here:WaitForChild("HudUI"))
local CollectionBookUI = require(here:WaitForChild("CollectionBookUI"))
local CapsuleRevealUI = require(here:WaitForChild("CapsuleRevealUI"))
local SquishFx = require(here:WaitForChild("SquishFx"))

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Remote handles
local equipBuddyRequest = Remotes.get(Remotes.EquipBuddyRequest)
local requestInitialState = Remotes.get(Remotes.RequestInitialState)

-- Build the UI. Mount the Book before the HUD so the HUD's button can open it.
ToastUI.mount(playerGui)
CollectionBookUI.mount(playerGui, function(defId)
	equipBuddyRequest:FireServer(defId)
end)
HudUI.mount(playerGui, function()
	CollectionBookUI.show()
end)
CapsuleRevealUI.mount(playerGui)
SquishFx.init()

-- Server -> client routing
Remotes.get(Remotes.StateSync).OnClientEvent:Connect(function(state)
	HudUI.update(state)
	CollectionBookUI.update(state)
end)

Remotes.get(Remotes.SquishResult).OnClientEvent:Connect(function(result)
	SquishFx.handle(result)
end)

Remotes.get(Remotes.CapsuleResult).OnClientEvent:Connect(function(result)
	CapsuleRevealUI.play(result)
end)

Remotes.get(Remotes.Toast).OnClientEvent:Connect(function(text)
	ToastUI.show(text)
end)

print("[Squishy Smash] Client ready for " .. localPlayer.Name)

-- Tell the server we're ready for our state + welcome.
requestInitialState:FireServer()
