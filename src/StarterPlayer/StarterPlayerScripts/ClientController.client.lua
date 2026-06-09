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
local SparkleBits = require(here:WaitForChild("SparkleBits"))
local DailyUI = require(here:WaitForChild("DailyUI"))
local FinaleUI = require(here:WaitForChild("FinaleUI"))
local SocialUI = require(here:WaitForChild("SocialUI"))

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Remote handles
local equipBuddyRequest = Remotes.get(Remotes.EquipBuddyRequest)
local requestInitialState = Remotes.get(Remotes.RequestInitialState)
local claimDailyCapsule = Remotes.get(Remotes.ClaimDailyCapsule)
local resetProgress = Remotes.get(Remotes.ResetProgress)
local ownerDebug = Remotes.get(Remotes.OwnerDebug)

-- Build the UI. Mount the Book before the HUD so the HUD's button can open it.
ToastUI.mount(playerGui)
CollectionBookUI.mount(playerGui, function(defId)
	equipBuddyRequest:FireServer(defId)
end)
DailyUI.mount(playerGui)
FinaleUI.mount(playerGui)
HudUI.mount(playerGui, function()
	CollectionBookUI.show()
end, function()
	claimDailyCapsule:FireServer()
end, function()
	DailyUI.show()
end, function()
	resetProgress:FireServer()
end, function(action)
	ownerDebug:FireServer(action)
end)
SocialUI.mount(playerGui)
CapsuleRevealUI.mount(playerGui)
SquishFx.init()
SparkleBits.init(function(msg)
	ToastUI.show(msg)
end)

-- Server -> client routing
Remotes.get(Remotes.StateSync).OnClientEvent:Connect(function(state)
	HudUI.update(state)
	CollectionBookUI.update(state)
	DailyUI.update(state)
	SparkleBits.syncCollected(state.sparkleBits)
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

Remotes.get(Remotes.SparkleRestored).OnClientEvent:Connect(function(info)
	FinaleUI.play(info)
end)

Remotes.get(Remotes.SocialSync).OnClientEvent:Connect(function(state)
	SocialUI.update(state)
end)

print("[Squishy Smash] Client ready for " .. localPlayer.Name)

-- Tell the server we're ready for our state + welcome.
requestInitialState:FireServer()
