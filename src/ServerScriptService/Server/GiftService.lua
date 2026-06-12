--!strict
-- GiftService (SERVER)
-- Gifting v1: GIFTS, not trades. Every player's character carries a small
-- "🎁 Give a Gift" prompt; triggering it on someone ELSE opens the sender's
-- gift picker. A gift is either Sparkle Coins (preset amounts only) or SHARING
-- a discovered friend — the recipient gets the discovery + the full card
-- reveal, and the giver keeps theirs (sharing is caring, nothing is ever
-- lost, so nobody can be talked out of their collection). Server-authoritative
-- end to end: the prompt, the daily limit, the distance, the amounts, and the
-- transfer are all validated here. Same-server only in v1 (a cross-server
-- mailbox can ride on the session locks later).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local GiftConfig = require(Shared:WaitForChild("GiftConfig"))
local SquishyData = require(Shared:WaitForChild("SquishyData"))

local PlayerDataService = require(script.Parent.PlayerDataService)
local DailyService = require(script.Parent.DailyService)

local GiftService = {}

local toastEvent: RemoteEvent
local openEvent: RemoteEvent
local receivedEvent: RemoteEvent
local capsuleResultEvent: RemoteEvent

-- Double-tap guard: one gift may land per sender per couple of seconds.
local SEND_COOLDOWN = 2
local lastSentAt: { [Player]: number } = {}

local function rootPos(player: Player): Vector3?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return if root then (root :: BasePart).Position else nil
end

-- The sender walked up and tapped 🎁 on another player: hand their client
-- everything the picker needs (who, what the recipient already knows, and how
-- many gifts the sender has left today).
local function openGiftFor(sender: Player, recipient: Player)
	if sender == recipient then
		return
	end
	if not (PlayerDataService.isReady(sender) and PlayerDataService.isReady(recipient)) then
		return
	end
	local remaining = GiftConfig.DailyGiftLimit - PlayerDataService.giftsSentToday(sender)
	if remaining <= 0 then
		toastEvent:FireClient(sender, "You've shared all your gifts for today — more tomorrow! 💝")
		return
	end
	local rProfile = PlayerDataService.get(recipient)
	openEvent:FireClient(sender, {
		userId = recipient.UserId,
		name = recipient.DisplayName,
		-- so the picker can mark friends the recipient already knows
		theyKnow = rProfile and rProfile.Discovered or {},
		remaining = remaining,
	})
end

-- Every character wears the gift prompt on its HumanoidRootPart (a prompt
-- parented to the Model never renders). The local player hides their OWN
-- prompt client-side so it can't sit in their face or eat their E key.
local function attachPrompt(owner: Player, character: Model)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not root or root.Parent ~= character then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "GiftPrompt"
		prompt.ObjectText = owner.DisplayName
		prompt.ActionText = "🎁 Give a Gift"
		prompt.HoldDuration = 0.25
		prompt.MaxActivationDistance = GiftConfig.PromptDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = root
		prompt.Triggered:Connect(function(sender)
			openGiftFor(sender, owner)
		end)
	end)
end

-- The sender confirmed a gift. Validate EVERYTHING, then move the joy.
local function onSendGift(sender: Player, recipientUserId: any, kind: any, value: any)
	if type(recipientUserId) ~= "number" or type(kind) ~= "string" then
		return
	end
	local now = os.clock()
	if now - (lastSentAt[sender] or 0) < SEND_COOLDOWN then
		return -- double-tap; the first gift's feedback is already on screen
	end
	if not PlayerDataService.isReady(sender) then
		return
	end
	local recipient = Players:GetPlayerByUserId(recipientUserId)
	if not recipient or not PlayerDataService.isReady(recipient) then
		toastEvent:FireClient(sender, "They've wandered off — maybe next time! 💝")
		return
	end
	if recipient == sender then
		toastEvent:FireClient(sender, "You can't gift yourself — but you're still a great friend! 😄")
		return
	end
	if PlayerDataService.giftsSentToday(sender) >= GiftConfig.DailyGiftLimit then
		toastEvent:FireClient(sender, "You've shared all your gifts for today — more tomorrow! 💝")
		return
	end
	local a, b = rootPos(sender), rootPos(recipient)
	if not a or not b or (a - b).Magnitude > GiftConfig.SendRange then
		toastEvent:FireClient(sender, "Walk closer to " .. recipient.DisplayName .. " to give your gift!")
		return
	end

	local shoutText: string
	if kind == "coins" then
		local amount = if type(value) == "number" then value else nil
		local isPreset = false
		for _, preset in ipairs(GiftConfig.CoinPresets) do
			if amount == preset then
				isPreset = true
				break
			end
		end
		if not amount or not isPreset then
			return -- the picker only offers presets; anything else is a forged call
		end
		if not PlayerDataService.spendCoins(sender, amount) then
			toastEvent:FireClient(sender, "You don't have " .. amount .. " Sparkle Coins yet — happy squishing!")
			return
		end
		PlayerDataService.addCoins(recipient, amount)
		toastEvent:FireClient(sender, "💝 You gave " .. amount .. " Sparkle Coins to " .. recipient.DisplayName .. "!")
		receivedEvent:FireClient(recipient, {
			kind = "coins",
			fromName = sender.DisplayName,
			amount = amount,
		})
		shoutText = "💝 " .. sender.DisplayName .. " gave " .. recipient.DisplayName .. " a gift!"
	elseif kind == "friend" then
		local defId = if type(value) == "string" then value else nil
		local def = defId and SquishyData.getById(defId)
		if not def or not defId then
			return
		end
		if not PlayerDataService.hasDiscovered(sender, defId) then
			return -- the picker only offers the sender's own friends
		end
		if PlayerDataService.hasDiscovered(recipient, defId) then
			toastEvent:FireClient(sender, recipient.DisplayName .. " already knows " .. def.DisplayName .. " — pick another friend to share!")
			return
		end
		PlayerDataService.discoverCard(recipient, defId)
		DailyService.noteEvent(recipient, "discover")
		toastEvent:FireClient(sender, "💝 You shared " .. def.DisplayName .. " with " .. recipient.DisplayName .. " — sharing is caring!")
		toastEvent:FireClient(recipient, "💝 " .. sender.DisplayName .. " shared " .. def.DisplayName .. " with you!")
		-- the recipient gets the same warm card reveal a capsule plays, with a
		-- "gift from" headline (the giver keeps their own friend AND its shine)
		capsuleResultEvent:FireClient(recipient, {
			defId = def.Id,
			displayName = def.DisplayName,
			cardNumber = def.CardNumber,
			rarity = def.Rarity,
			imageAssetId = def.ImageAssetId,
			isNew = true,
			bonusCoins = 0,
			wasFree = true,
			variantLevel = 0,
			variantUpgraded = false,
			giftFrom = sender.DisplayName,
		})
		shoutText = "💝 " .. sender.DisplayName .. " shared " .. def.DisplayName .. " with " .. recipient.DisplayName .. "!"
	else
		return
	end

	lastSentAt[sender] = now
	PlayerDataService.noteGiftSent(sender)
	PlayerDataService.sync(sender)
	PlayerDataService.sync(recipient)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= sender and other ~= recipient then
			toastEvent:FireClient(other, shoutText)
		end
	end
end

function GiftService.init()
	toastEvent = Remotes.get(Remotes.Toast)
	openEvent = Remotes.get(Remotes.OpenGiftUI)
	receivedEvent = Remotes.get(Remotes.GiftReceived)
	capsuleResultEvent = Remotes.get(Remotes.CapsuleResult)
	Remotes.get(Remotes.SendGift).OnServerEvent:Connect(onSendGift)

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			attachPrompt(player, character)
		end)
		if player.Character then
			attachPrompt(player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastSentAt[player] = nil
	end)
end

return GiftService
