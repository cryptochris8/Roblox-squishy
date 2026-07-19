-- MilestoneService (SERVER)
-- Celebrates collection milestones with FIXED, KNOWN rewards, awarded once and
-- persisted in profile.Milestones. Before this, hitting 48/48 showed nothing
-- at all. Never random, never purchasable — these are thank-yous for finishing
-- sets (per-land discovery, the whole Book, all-Sparkly lands, the full
-- Rainbow Book -> the Rainbow Keeper Crown).
--
-- check(player) is cheap + idempotent: call it after anything that can change
-- the Discovered/Variants sets. checkOwed(player) is the join-time catch-up so
-- kids who finished sets BEFORE this feature shipped still get their moment.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local SquishyData = require(Shared:WaitForChild("SquishyData"))
local VariantConfig = require(Shared:WaitForChild("VariantConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local MilestoneService = {}

-- Main wires this to BuddyService.refresh so a granted crown appears instantly.
MilestoneService.onCosmeticsChanged = nil :: ((Player) -> ())?

local ZONE_COMPLETE_COINS = 150
local ZONE_SPARKLY_COINS = 250
local BOOK_COMPLETE_COINS = 500
local CROWN_ID = "hat_rainbow_keeper"

local toastEvent: RemoteEvent

-- zone -> that land's LAUNCH friends (event/family friends never pollute the
-- counts: the sets are built from the launch roster only).
local zoneRosters: { [string]: { any } }? = nil
local function rosters()
	if zoneRosters then
		return zoneRosters
	end
	local built: { [string]: { any } } = {}
	for _, def in ipairs(SquishyData.getLaunchRoster()) do
		local zone = def.Zone or "the Squishy world"
		built[zone] = built[zone] or {}
		table.insert(built[zone], def)
	end
	zoneRosters = built
	return built
end

local function shoutToOthers(player: Player, message: string)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			toastEvent:FireClient(other, message, "social")
		end
	end
end

local function allDiscovered(profile, defs): boolean
	for _, def in ipairs(defs) do
		if not profile.Discovered[def.Id] then
			return false
		end
	end
	return true
end

local function allAtVariant(profile, defs, level: number): boolean
	for _, def in ipairs(defs) do
		if (profile.Variants[def.Id] or 0) < level then
			return false
		end
	end
	return true
end

-- Award a milestone once. Returns true if it was newly awarded.
local function award(player: Player, profile, id: string, coins: number, toastMsg: string, shoutMsg: string?): boolean
	if profile.Milestones[id] then
		return false
	end
	profile.Milestones[id] = true
	if coins > 0 then
		PlayerDataService.addCoins(player, coins)
	end
	toastEvent:FireClient(player, toastMsg, "celebration")
	if shoutMsg then
		shoutToOthers(player, shoutMsg)
	end
	return true
end

function MilestoneService.check(player: Player)
	if not PlayerDataService.isReady(player) then
		return
	end
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	local changed = false
	local launch = SquishyData.getLaunchRoster()

	for zone, defs in pairs(rosters()) do
		if allDiscovered(profile, defs) then
			changed = award(player, profile, "zone_discovered_" .. zone, ZONE_COMPLETE_COINS,
				"🌟 All " .. #defs .. " " .. zone .. " friends discovered!  +" .. ZONE_COMPLETE_COINS .. " Sparkle Coins") or changed
		end
		if allAtVariant(profile, defs, 1) then
			changed = award(player, profile, "zone_sparkly_" .. zone, ZONE_SPARKLY_COINS,
				"✨ Every " .. zone .. " friend is Sparkly!  +" .. ZONE_SPARKLY_COINS .. " Sparkle Coins") or changed
		end
	end

	if allDiscovered(profile, launch) then
		changed = award(player, profile, "book_discovered_all", BOOK_COMPLETE_COINS,
			"⭐ You discovered ALL " .. #launch .. " Squishy Friends!  +" .. BOOK_COMPLETE_COINS .. " Sparkle Coins",
			"⭐ " .. player.DisplayName .. " has discovered ALL " .. #launch .. " Squishy Friends!") or changed
	end

	-- The long-tail crown: every launch friend at max variant (Rainbow).
	if allAtVariant(profile, launch, VariantConfig.Max) and not profile.Milestones["book_rainbow_all"] then
		profile.Milestones["book_rainbow_all"] = true
		profile.Cosmetics.Owned[CROWN_ID] = true
		profile.Cosmetics.Equipped.hat = CROWN_ID -- auto-wear, like premium grants
		toastEvent:FireClient(player, "🌈 Your whole Book is RAINBOW! The Rainbow Keeper Crown is yours!", "celebration")
		shoutToOthers(player, "🌈 " .. player.DisplayName .. " completed the RAINBOW Book — a true Rainbow Keeper!")
		if MilestoneService.onCosmeticsChanged then
			MilestoneService.onCosmeticsChanged(player)
		end
		changed = true
	end

	if changed then
		PlayerDataService.sync(player)
	end
end

-- Join-time catch-up (same pattern as FamilyService.checkOwed): waits for the
-- profile to finish its DataStore load, then runs one check. A kid who was
-- already a completionist gets the celebration burst — the toast queue drains
-- it in order rather than piling banners.
function MilestoneService.checkOwed(player: Player)
	task.spawn(function()
		local deadline = os.clock() + 30
		while not PlayerDataService.isReady(player) and player.Parent and os.clock() < deadline do
			task.wait(0.5)
		end
		if player.Parent and PlayerDataService.isReady(player) then
			MilestoneService.check(player)
		end
	end)
end

function MilestoneService.init()
	toastEvent = Remotes.get(Remotes.Toast)
end

return MilestoneService
