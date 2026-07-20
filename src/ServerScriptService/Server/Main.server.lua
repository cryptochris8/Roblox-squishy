--!strict
-- Main (SERVER ENTRY POINT)
-- Wires Squishy Smash together in the right order and starts Pudding Hills.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

-- 1) Create the RemoteEvents first, before anything tries to use them.
Remotes.setupServer()

-- 2) Load the services (they live next to this script).
local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldService = require(script.Parent.WorldService)
local SquishService = require(script.Parent.SquishService)
local CapsuleService = require(script.Parent.CapsuleService)
local CollectionService = require(script.Parent.CollectionService)
local TutorialService = require(script.Parent.TutorialService)
local BuddyService = require(script.Parent.BuddyService)
local QuestService = require(script.Parent.QuestService)
local SparkleBitService = require(script.Parent.SparkleBitService)
local DailyService = require(script.Parent.DailyService)
local TravelService = require(script.Parent.TravelService)
local FinaleService = require(script.Parent.FinaleService)
local SurgeService = require(script.Parent.SurgeService)
local GroupEventService = require(script.Parent.GroupEventService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local BoutiqueService = require(script.Parent.BoutiqueService)
local WeeklyService = require(script.Parent.WeeklyService)
local CodeService = require(script.Parent.CodeService)
local RoomService = require(script.Parent.RoomService)
local FirstDayService = require(script.Parent.FirstDayService)
local StoryPageService = require(script.Parent.StoryPageService)
local GiftService = require(script.Parent.GiftService)
local MonetizationService = require(script.Parent.MonetizationService)
local CoasterService = require(script.Parent.CoasterService)
local PlaygroundService = require(script.Parent.PlaygroundService)
local FamilyService = require(script.Parent.FamilyService)
local MilestoneService = require(script.Parent.MilestoneService)
local Telemetry = require(script.Parent.Telemetry)
local BadgeService = require(script.Parent.BadgeService)
local BoopService = require(script.Parent.BoopService)
local EmoteService = require(script.Parent.EmoteService)
local RidePrefs = require(script.Parent.RidePrefs)
local PhotoSpotService = require(script.Parent.PhotoSpotService)

-- 3) Initialize player data + the systems that need remotes ready.
PlayerDataService.init()
CapsuleService.init()
CollectionService.init()
TutorialService.init()
BuddyService.init()
SparkleBitService.init()
DailyService.init()
TravelService.init()
FinaleService.init()
SurgeService.init()
GroupEventService.init()
LeaderboardService.init()
BoutiqueService.init()
WeeklyService.init()
CodeService.init()
RoomService.init()
FirstDayService.init()
StoryPageService.init()
GiftService.init()
MonetizationService.init()
MilestoneService.init()
BoopService.init()
EmoteService.init()
RidePrefs.init()

-- 4) Build all the lands, then spawn each land's sleepy friends on its pads.
local world = WorldService.build()
QuestService.init()
CoasterService.init() -- the Sparkle Express needs the land (and its riders) in place
PlaygroundService.init() -- slides, bounce bog, swings, seesaw, mushroom hops
FamilyService.init() -- the three daughter guardians, one per land
PhotoSpotService.init() -- Sparkle Photo Spots need the land's tagged pads in place

local zoneGroups = {}
for _, z in ipairs(world.zones) do
	zoneGroups[#zoneGroups + 1] = { zone = z.zone, packId = z.packId, pads = z.pads }
end
SquishService.init(zoneGroups)

-- 5) Wire the world up.
-- A friendly note to everyone EXCEPT the player it's about (they get their own).
local toastEvent = Remotes.get(Remotes.Toast)
local function shoutToOthers(player: Player, message: string)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			toastEvent:FireClient(other, message)
		end
	end
end

-- FTUE funnel (Telemetry): the once-ever new-player journey. The per-session
-- dedupe keeps analytics calls off the hot paths (every squish hits step 1);
-- sessionId = UserId makes each step once-ever per player server-side too.
local ftueSent: { [Player]: { [number]: boolean } } = {}
local function ftue(player: Player, step: number, name: string)
	local sent = ftueSent[player]
	if not sent then
		sent = {}
		ftueSent[player] = sent
	end
	if sent[step] then
		return
	end
	sent[step] = true
	Telemetry.funnelStep(player, "ftue", step, name, tostring(player.UserId))
end
Players.PlayerRemoving:Connect(function(player)
	ftueSent[player] = nil
end)

-- A Happy Pop nudges the tutorial + the land's shard quest along, and feeds the
-- server-wide Sparkle Surge meter.
SquishService.onHappyPop = function(player, def)
	TutorialService.notePop(player, def)
	QuestService.notePop(player, def)
	DailyService.noteEvent(player, "pop")
	SurgeService.notePop(player, def)
	BadgeService.award(player, "FirstHappyPop")
end

-- During a Sparkle Surge every coin award doubles, and Coin Boost pass owners
-- earn +25% on top (the perks multiply: surge + boost = x2.5).
SquishService.coinMultiplier = function(player)
	return SurgeService.coinMultiplier() * MonetizationService.coinMultiplier(player)
end

-- The First Day list watches its five signals.
SquishService.onSquish = function(player)
	FirstDayService.check(player)
	ftue(player, 1, "first_squish")
end
RoomService.onVisited = function(player)
	FirstDayService.noteRoomVisit(player)
end

-- Golden friends belong to the "Everybody Squish!" event.
SquishService.onGoldenPop = function(player, def, model)
	GroupEventService.noteGoldenPop(player, def, model)
end

-- Equipping/unequipping buddies respawns the floating companions.
CollectionService.onBuddyChanged = function(player)
	BuddyService.refresh(player)
	FirstDayService.check(player)
end

-- Boutique purchases/outfit changes re-dress the buddy on the spot.
BoutiqueService.onCosmeticsChanged = function(player)
	BuddyService.refresh(player)
end

-- Phase D: a premium cosmetic arrived (auto-worn) or a pass changed (VIP
-- crown/aura, second slot) — the companions need a fresh look either way.
MonetizationService.onPremiumGranted = function(player)
	BuddyService.refresh(player)
end
MonetizationService.onPassesChanged = function(player)
	BuddyService.refresh(player)
end

-- Daily-quest tracking: a capsule open (and any new discovery), and Sparkle Bits.
-- A NEW discovery is also a show-off moment for the rest of the server.
CapsuleService.onOpened = function(player, isNew, def)
	FirstDayService.check(player)
	DailyService.noteEvent(player, "capsule")
	if isNew then
		DailyService.noteEvent(player, "discover")
		if def then
			shoutToOthers(player, "🎉 " .. player.DisplayName .. " discovered " .. def.DisplayName .. "!")
		end
	elseif def then
		-- A duplicate may have shined up a friend they have equipped — respawn
		-- the buddies so the ✨/🌈 badge and aura update right away.
		local profile = PlayerDataService.get(player)
		if profile and (profile.EquippedBuddyId == def.Id or profile.EquippedBuddyId2 == def.Id) then
			BuddyService.refresh(player)
		end
	end
	-- Any open can complete a set (new discovery OR a dup's variant shine-up).
	MilestoneService.check(player)
	ftue(player, 2, "first_capsule")
	BadgeService.award(player, "FirstCapsule")
	local prof = PlayerDataService.get(player)
	if prof then
		BadgeService.discoveryCount(player, prof.DiscoveredCount)
	end
	if def then
		local lvl = PlayerDataService.getVariant(player, def.Id)
		if lvl >= 1 then
			BadgeService.award(player, "FirstSparkly")
		end
		if lvl >= 2 then
			BadgeService.award(player, "FirstRainbow")
		end
	end
end

-- A gifted friend can complete the recipient's set too; a granted crown
-- should appear on the buddy right away.
GiftService.onFriendShared = function(recipient)
	MilestoneService.check(recipient)
end
MilestoneService.onCosmeticsChanged = function(player)
	BuddyService.refresh(player)
end
SparkleBitService.onCollected = function(player, all)
	DailyService.noteEvent(player, "bit")
	if all then
		BadgeService.award(player, "AllSparkleBits")
	end
end
StoryPageService.onAllPages = function(player)
	BadgeService.award(player, "AllStoryPages")
end
GiftService.onGiftSent = function(sender)
	BadgeService.award(sender, "KindFriend")
end
TravelService.onTraveled = function(player)
	ftue(player, 4, "first_travel")
end

-- Recovering a land's shard is server news too — and earns that land's
-- Family guardian (Apple Addy / Eggy Ellie / Hot Dog Heidi).
QuestService.onShardRecovered = function(player, zoneName)
	shoutToOthers(player, "✨ " .. player.DisplayName .. " recovered the " .. zoneName .. " Sparkle Shard!")
	FamilyService.grant(player, zoneName)
	EmoteService.autoCheer(player)
	BadgeService.shard(player, zoneName)
	ftue(player, 3, "first_shard")
end

-- Recovering all three Sparkle shards restores the Sparkle (the finale).
QuestService.onAllShardsRecovered = function(player)
	FinaleService.celebrate(player)
	EmoteService.onSparkleRestored(player)
	BadgeService.award(player, "SparkleRestored")
	ftue(player, 5, "sparkle_restored")
end

-- Each land's Sparkle Capsule (draws from that land's pack) + guide (gives that
-- land's shard clue).
for _, z in ipairs(world.zones) do
	if z.capsulePrompt then
		z.capsulePrompt.Triggered:Connect(function(player)
			CapsuleService.tryOpen(player, z.capsuleKey)
		end)
	end
	if z.guidePrompt then
		z.guidePrompt.Triggered:Connect(function(player)
			QuestService.giveClue(player, z.zone)
		end)
	end
	for _, tp in ipairs(z.travelPads or {}) do
		tp.prompt.Triggered:Connect(function(player)
			TravelService.travel(player, tp.destZone, tp.prompt.Parent)
		end)
	end
end

-- 6) When a client says it's ready, send its state + a warm welcome.
local requestState = Remotes.get(Remotes.RequestInitialState)
requestState.OnServerEvent:Connect(function(player)
	BadgeService.award(player, "Welcome")
	DailyService.onJoin(player)
	FirstDayService.check(player)
	PlayerDataService.sync(player)
	EmoteService.refresh(player)
	TutorialService.welcome(player)
	QuestService.checkReveal(player)
	FamilyService.checkOwed(player) -- catch up players who restored a land pre-feature
	MilestoneService.checkOwed(player) -- celebrate sets completed before this shipped
	SurgeService.syncTo(player)
	GroupEventService.syncTo(player)
end)

-- Owner-only playtest triggers, so you can demo the shared-world moments to the
-- kids on cue instead of waiting for the timers. Same double-gate as Reset.
local ownerDebug = Remotes.get(Remotes.OwnerDebug)
ownerDebug.OnServerEvent:Connect(function(player, action)
	if game.CreatorType ~= Enum.CreatorType.User or player.UserId ~= game.CreatorId then
		return
	end
	if action == "startEvent" then
		GroupEventService.startNow()
	elseif action == "startSurge" then
		SurgeService.startNow()
	elseif type(action) == "string" and action:sub(1, 10) == "grantPass:" then
		-- session-only pass demo, e.g. "grantPass:VIP" (owner-gated above)
		MonetizationService.debugGrantPass(player, action:sub(11))
	elseif type(action) == "string" and action:sub(1, 6) == "photo:" then
		-- solo photo-moment demo, e.g. "photo:PH_Photo" (a real one needs 2+ kids)
		PhotoSpotService.debugSolo(player, action:sub(7))
	elseif action == "treatAsFriend" then
		BoopService.forceFriendTier = true -- demo/test the FRIEND boop FX solo
		TravelService.setFriendOverride(player.UserId, "friend")
	elseif action == "treatAsStranger" then
		BoopService.forceFriendTier = false -- demo/test the VISITOR boop FX solo
		TravelService.setFriendOverride(player.UserId, "stranger")
	elseif action == "treatReset" then
		BoopService.forceFriendTier = nil
		TravelService.setFriendOverride(player.UserId, nil)
	elseif action == "restoreRoom610" then
		-- One-time restitution: an old pre-Room server's leave-save dropped the
		-- owner's furniture + buddy on 2026-06-10. Owner-gated; idempotent.
		local profile = PlayerDataService.get(player)
		if profile then
			for _, id in ipairs({ "lamp_mushroom", "rug_rainbow", "window_sunny", "plant_sprout" }) do
				profile.Room.Owned[id] = true
			end
			if profile.Discovered["marshmallow_puff"] and profile.EquippedBuddyId == nil then
				profile.EquippedBuddyId = "marshmallow_puff"
				BuddyService.refresh(player)
			end
			FirstDayService.check(player)
			PlayerDataService.sync(player)
		end
	end
end)

-- Owner-only "Reset My Progress" playtest tool. Double-gated to the place owner so
-- the kids can NEVER wipe their own progress; resets the profile (the fresh save
-- lands on the rejoin kick) and sends them back for a clean first-time run.
local resetProgress = Remotes.get(Remotes.ResetProgress)
resetProgress.OnServerEvent:Connect(function(player)
	if game.CreatorType ~= Enum.CreatorType.User or player.UserId ~= game.CreatorId then
		return
	end
	PlayerDataService.resetProfile(player)
	task.wait(0.15)
	player:Kick("✨ Progress reset — rejoin to start fresh from the beginning!")
end)

print("[Squishy Smash] Server ready — welcome to Pudding Hills!")
