-- ClientController (CLIENT ENTRY POINT)
-- Boots the Squishy Smash client: builds the HUD, Squishy Book, capsule reveal,
-- and toast UIs, sets up the in-world squish feedback, and routes the server's
-- messages to the right place. The server stays the authority for everything
-- that matters (coins, discoveries, Joy); the client just makes it feel cozy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local SoundConfig = require(Shared:WaitForChild("SoundConfig"))

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
local BoutiqueUI = require(here:WaitForChild("BoutiqueUI"))
local CodesUI = require(here:WaitForChild("CodesUI"))
local RoomUI = require(here:WaitForChild("RoomUI"))
local FirstDayUI = require(here:WaitForChild("FirstDayUI"))
local StoryPagesUI = require(here:WaitForChild("StoryPagesUI"))
local GiftUI = require(here:WaitForChild("GiftUI"))
local BouncePads = require(here:WaitForChild("BouncePads"))
local SoundScape = require(here:WaitForChild("SoundScape"))

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
end, function()
	CodesUI.show()
end, function()
	StoryPagesUI.show()
end)
SocialUI.mount(playerGui)
CodesUI.mount(playerGui, function(text)
	Remotes.get(Remotes.RedeemCode):FireServer(text)
end)
RoomUI.mount(playerGui, function(slotId, itemId)
	Remotes.get(Remotes.PlaceRoomItem):FireServer(slotId, itemId)
end)
FirstDayUI.mount(playerGui)
StoryPagesUI.mount(playerGui, function(msg)
	ToastUI.show(msg)
end)
GiftUI.mount(playerGui, function(recipientUserId, kind, value)
	Remotes.get(Remotes.SendGift):FireServer(recipientUserId, kind, value)
end)
BoutiqueUI.mount(playerGui, function(id)
	Remotes.get(Remotes.BuyCosmetic):FireServer(id)
end, function(slot, id)
	Remotes.get(Remotes.EquipCosmetic):FireServer(slot, id)
end, function(id)
	Remotes.get(Remotes.BuyPremium):FireServer(id)
end, function(passKey)
	Remotes.get(Remotes.BuyPass):FireServer(passKey)
end)
CapsuleRevealUI.mount(playerGui)
SquishFx.init()
BouncePads.init()
SoundScape.init()
SparkleBits.init(function(msg)
	ToastUI.show(msg)
end)

-- A short 2D sound for celebratory moments not tied to a 3D spot.
local function playUiSound(id, volume)
	if not id or id == "" then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, 5)
end

-- Server -> client routing
local prevShards = nil
Remotes.get(Remotes.StateSync).OnClientEvent:Connect(function(state)
	HudUI.update(state)
	CollectionBookUI.update(state)
	DailyUI.update(state)
	BoutiqueUI.update(state)
	RoomUI.update(state)
	FirstDayUI.update(state)
	GiftUI.update(state)
	SparkleBits.syncCollected(state.sparkleBits)
	StoryPagesUI.syncCollected(state.storyPages)
	-- Ring the shard chime the moment a land's Sparkle shard is newly recovered
	-- (skipped on the first sync so already-recovered shards stay silent).
	if state.shards then
		if prevShards then
			for zone, info in pairs(state.shards) do
				local was = prevShards[zone] and prevShards[zone].collected
				if info.collected and not was then
					playUiSound(SoundConfig.ShardRecovered, 0.6)
					break
				end
			end
		end
		prevShards = state.shards
	end
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

Remotes.get(Remotes.OpenBoutique).OnClientEvent:Connect(function()
	BoutiqueUI.show()
end)

Remotes.get(Remotes.OpenRoomCatalog).OnClientEvent:Connect(function(info)
	RoomUI.open(info)
end)

Remotes.get(Remotes.OpenGiftUI).OnClientEvent:Connect(function(info)
	GiftUI.open(info)
end)

Remotes.get(Remotes.GiftReceived).OnClientEvent:Connect(function(info)
	GiftUI.playReceived(info)
end)

-- Bounce pads and slides launch the character; without this, hard landings can
-- trip/ragdoll little avatars. SetStateEnabled doesn't replicate, so it must
-- run here on the owning client, once per spawn. (No damage in this game —
-- nothing wholesome is lost by never falling down.)
local function softenLandings(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	end
end
localPlayer.CharacterAdded:Connect(softenLandings)
if localPlayer.Character then
	task.spawn(softenLandings, localPlayer.Character)
end

print("[Squishy Smash] Client ready for " .. localPlayer.Name)

-- Tell the server we're ready for our state + welcome.
requestInitialState:FireServer()
