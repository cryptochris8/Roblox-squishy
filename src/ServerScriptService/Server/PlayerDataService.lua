--!strict
-- PlayerDataService (SERVER)
-- The single owner of each player's progress: Sparkle Coins, discovered friends,
-- totals, equipped buddy, and tutorial state. Everything is server-side and
-- validated. Progress is persisted with DataStores: load on join, save on leave,
-- a periodic autosave, and a flush on server shutdown.
--
-- SESSION LOCKING (ProfileStore-style, built in): every save blob carries a
-- `_lock = { id, ts }`. A server only adopts a profile after stamping its own
-- lock via UpdateAsync, REFUSES to adopt one freshly locked by another server
-- (that player plays on a temporary profile instead — e.g. a Studio session
-- while the same account is in the live game), steals locks that have gone
-- stale (a crashed server), refreshes its lock on every autosave, aborts any
-- write the moment another server has taken the lock over, and releases the
-- lock on leave/shutdown. This kills the two-sessions-last-writer-wins hazard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local VariantConfig = require(Shared:WaitForChild("VariantConfig"))
local ZoneConfig = require(Shared:WaitForChild("ZoneConfig"))

-- Bump the version suffix only if the saved shape changes incompatibly.
local DATASTORE_NAME = "SquishyPlayerData_v1"
local DATA_VERSION = 1
local MAX_RETRIES = 4
local AUTOSAVE_INTERVAL = 90 -- seconds between background saves of active players

-- Session lock tuning. TTL must comfortably exceed the autosave interval (the
-- autosave is what keeps a live session's lock fresh); a lock older than TTL
-- belongs to a dead server and may be stolen.
local SESSION_ID = HttpService:GenerateGUID(false)
local LOCK_TTL = 240
local ACQUIRE_ATTEMPTS = 7
local ACQUIRE_WAIT = 5

-- GetDataStore THROWS in an unpublished place ("You must publish this place to
-- the web to access DataStore"), which would take down the whole server on load.
-- Guard it: if it fails, we fall back to an in-memory session and the game still
-- runs — it just won't persist until the place is published + API access is on.
local playerStore: DataStore? = nil
local dataStoreEnabled = false
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		playerStore = result
		dataStoreEnabled = true
	else
		warn("[Squishy Smash] DataStore unavailable — progress will NOT persist this session. "
			.. "Publish the place and turn on Studio Access to API Services to save. (" .. tostring(result) .. ")")
	end
end

local PlayerDataService = {}

export type Profile = {
	SparkleCoins: number,
	TotalSquishes: number,
	TotalHappyPops: number,
	Discovered: { [string]: boolean },
	DiscoveredCount: number,
	EquippedBuddyId: string?,
	TutorialDone: boolean,
	FirstCapsuleClaimed: boolean,
	Shards: { [string]: { progress: number, collected: boolean } },
	SparkleBits: { [string]: boolean },
	Variants: { [string]: number },
	LastDailyCapsuleDay: number,
	StreakDays: number,
	LastPlayDay: number,
	DailyQuests: { day: number, progress: { [string]: number }, claimed: { [string]: boolean } },
	SparkleRestored: boolean,
	Cosmetics: { Owned: { [string]: boolean }, Equipped: { [string]: string } },
	RedeemedCodes: { [string]: boolean },
}

local profiles: { [Player]: Profile } = {}
-- loadedOk[player] == false means the load *errored* (DataStore unreachable), so
-- we must NOT save over what might be good saved data. nil/true means safe to save.
local loadedOk: { [Player]: boolean } = {}
local ready: { [Player]: boolean } = {}
local stateSyncEvent: RemoteEvent

-- Fresh per-zone shard quest state, built from the zone chain.
local function newShards()
	local s = {}
	for _, name in ipairs(ZoneConfig.Order) do
		s[name] = { progress = 0, collected = false }
	end
	return s
end

local function newProfile(): Profile
	return {
		SparkleCoins = GameConfig.StartingSparkleCoins,
		TotalSquishes = 0,
		TotalHappyPops = 0,
		Discovered = {},
		DiscoveredCount = 0,
		EquippedBuddyId = nil,
		TutorialDone = false,
		FirstCapsuleClaimed = false,
		Shards = newShards(),
		SparkleBits = {},
		Variants = {},
		LastDailyCapsuleDay = 0,
		StreakDays = 0,
		LastPlayDay = 0,
		DailyQuests = { day = 0, progress = {}, claimed = {} },
		SparkleRestored = false,
		Cosmetics = { Owned = {}, Equipped = {} },
		RedeemedCodes = {},
	}
end

-- Count the keys in a small set table.
local function countKeys(t: { [string]: boolean }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

-- UTC day index, for once-a-day resets (daily capsule, daily quests, streak).
local function todayIndex(): number
	return math.floor(os.time() / 86400)
end

-- Turn a live Profile into a plain, DataStore-safe table.
local function serialize(p: Profile)
	return {
		version = DATA_VERSION,
		SparkleCoins = p.SparkleCoins,
		TotalSquishes = p.TotalSquishes,
		TotalHappyPops = p.TotalHappyPops,
		Discovered = p.Discovered,
		EquippedBuddyId = p.EquippedBuddyId,
		TutorialDone = p.TutorialDone,
		FirstCapsuleClaimed = p.FirstCapsuleClaimed,
		Shards = p.Shards,
		SparkleBits = p.SparkleBits,
		Variants = p.Variants,
		LastDailyCapsuleDay = p.LastDailyCapsuleDay,
		StreakDays = p.StreakDays,
		LastPlayDay = p.LastPlayDay,
		DailyQuests = p.DailyQuests,
		SparkleRestored = p.SparkleRestored,
		Cosmetics = p.Cosmetics,
		RedeemedCodes = p.RedeemedCodes,
	}
end

-- Rebuild a Profile from saved data, filling any missing fields with fresh
-- defaults so older saves stay forward-compatible.
local function deserialize(data: any): Profile
	local p = newProfile()
	if type(data) ~= "table" then
		return p
	end
	p.SparkleCoins = tonumber(data.SparkleCoins) or p.SparkleCoins
	p.TotalSquishes = tonumber(data.TotalSquishes) or p.TotalSquishes
	p.TotalHappyPops = tonumber(data.TotalHappyPops) or p.TotalHappyPops
	p.TutorialDone = data.TutorialDone == true
	p.FirstCapsuleClaimed = data.FirstCapsuleClaimed == true
	-- Per-zone shards. Migrate the old single-shard fields into Pudding Hills.
	if type(data.Shards) == "table" then
		for _, name in ipairs(ZoneConfig.Order) do
			local s = data.Shards[name]
			if type(s) == "table" then
				p.Shards[name] = { progress = tonumber(s.progress) or 0, collected = s.collected == true }
			end
		end
	elseif data.FirstShardProgress ~= nil or data.FirstShardCollected ~= nil then
		p.Shards["Pudding Hills"] = { progress = tonumber(data.FirstShardProgress) or 0, collected = data.FirstShardCollected == true }
	end
	if type(data.EquippedBuddyId) == "string" then
		p.EquippedBuddyId = data.EquippedBuddyId
	end
	if type(data.Discovered) == "table" then
		local discovered = {}
		local count = 0
		for id, owned in pairs(data.Discovered) do
			if type(id) == "string" and owned == true then
				discovered[id] = true
				count += 1
			end
		end
		p.Discovered = discovered
		p.DiscoveredCount = count -- recomputed from the set, never trusted blindly
	end
	if type(data.SparkleBits) == "table" then
		local bits = {}
		for id, got in pairs(data.SparkleBits) do
			if type(id) == "string" and got == true then
				bits[id] = true
			end
		end
		p.SparkleBits = bits
	end
	if type(data.Variants) == "table" then
		local variants = {}
		for id, lvl in pairs(data.Variants) do
			local n = tonumber(lvl)
			if type(id) == "string" and n then
				variants[id] = math.clamp(math.floor(n), 1, VariantConfig.Max)
			end
		end
		p.Variants = variants
	end
	p.LastDailyCapsuleDay = tonumber(data.LastDailyCapsuleDay) or 0
	p.StreakDays = tonumber(data.StreakDays) or 0
	p.LastPlayDay = tonumber(data.LastPlayDay) or 0
	p.SparkleRestored = data.SparkleRestored == true
	if type(data.Cosmetics) == "table" then
		local owned, equipped = {}, {}
		if type(data.Cosmetics.Owned) == "table" then
			for id, has in pairs(data.Cosmetics.Owned) do
				if type(id) == "string" and has == true then
					owned[id] = true
				end
			end
		end
		if type(data.Cosmetics.Equipped) == "table" then
			for slot, id in pairs(data.Cosmetics.Equipped) do
				-- only keep an equip that the player actually owns
				if type(slot) == "string" and type(id) == "string" and owned[id] then
					equipped[slot] = id
				end
			end
		end
		p.Cosmetics = { Owned = owned, Equipped = equipped }
	end
	if type(data.RedeemedCodes) == "table" then
		local codes = {}
		for code, used in pairs(data.RedeemedCodes) do
			if type(code) == "string" and used == true then
				codes[code] = true
			end
		end
		p.RedeemedCodes = codes
	end
	if type(data.DailyQuests) == "table" then
		local dq = { day = tonumber(data.DailyQuests.day) or 0, progress = {}, claimed = {} }
		if type(data.DailyQuests.progress) == "table" then
			for k, v in pairs(data.DailyQuests.progress) do
				local n = tonumber(v)
				if type(k) == "string" and n then
					dq.progress[k] = n
				end
			end
		end
		if type(data.DailyQuests.claimed) == "table" then
			for k, v in pairs(data.DailyQuests.claimed) do
				if type(k) == "string" and v == true then
					dq.claimed[k] = true
				end
			end
		end
		p.DailyQuests = dq
	end
	return p
end

local function keyFor(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

-- Loads a player's data AND acquires their session lock, in one UpdateAsync.
-- Returns (ok, data, acquired):
--   ok=false                 -> DataStore errored (must not overwrite later)
--   ok=true, acquired=false  -> another live server holds the lock (play on a
--                               temporary profile; never write)
--   ok=true, acquired=true   -> data is ours (nil = brand-new player)
local function loadData(player: Player): (boolean, any, boolean)
	local store = playerStore
	if not (dataStoreEnabled and store) then
		return false, nil, false -- in-memory session: behave like a brand-new, unsavable profile
	end
	local key = keyFor(player)
	local sawForeignLock = false
	for attempt = 1, ACQUIRE_ATTEMPTS do
		local lockedElsewhere = false
		local loaded: any = nil
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				local lock = type(old) == "table" and old._lock
				if type(lock) == "table" and lock.id ~= SESSION_ID
					and os.time() - (tonumber(lock.ts) or 0) < LOCK_TTL then
					lockedElsewhere = true
					return nil -- abort: another live server owns this profile
				end
				-- ours (fresh player, our own lock, or a stale lock we steal)
				loaded = old
				local stamped: any = if type(old) == "table" then old else { version = DATA_VERSION }
				stamped._lock = { id = SESSION_ID, ts = os.time() }
				return stamped
			end)
		end)
		if ok and not lockedElsewhere then
			return true, loaded, true
		end
		if ok then
			-- locked by another live session. A normal server hop releases within
			-- seconds, so wait and retry; a session that NEVER releases (e.g. the
			-- same account playing elsewhere) leaves us on a temp profile.
			sawForeignLock = true
			if player.Parent == nil then
				return true, nil, false -- they left while we waited
			end
		else
			warn(string.format("[Squishy Smash] DataStore load failed for %s (attempt %d/%d): %s", player.Name, attempt, ACQUIRE_ATTEMPTS, tostring(err)))
		end
		if attempt < ACQUIRE_ATTEMPTS then
			task.wait(ACQUIRE_WAIT)
		end
	end
	if sawForeignLock then
		return true, nil, false
	end
	return false, nil, false
end

-- Atomically saves a player's current profile (skipped if their load errored or
-- this server doesn't own their session). `releasing` frees the lock (used on
-- leave/shutdown); otherwise the save also refreshes our lock's heartbeat.
local function saveData(player: Player, releasing: boolean?): boolean
	local p = profiles[player]
	if not p then
		return false
	end
	local store = playerStore
	if not (dataStoreEnabled and store) then
		return false -- in-memory session: nothing to persist
	end
	if loadedOk[player] == false then
		warn(string.format("[Squishy Smash] Skipping save for %s — this session doesn't own their saved profile.", player.Name))
		return false
	end
	local key = keyFor(player)
	local payload = serialize(p)
	for attempt = 1, MAX_RETRIES do
		local lostLock = false
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old)
				local lock = type(old) == "table" and old._lock
				if type(lock) == "table" and lock.id ~= SESSION_ID
					and os.time() - (tonumber(lock.ts) or 0) < LOCK_TTL then
					lostLock = true
					return nil -- abort: another server took this profile over
				end
				local outgoing: any = payload
				outgoing._lock = if releasing then nil else { id = SESSION_ID, ts = os.time() }
				return outgoing
			end)
		end)
		if ok then
			if lostLock then
				-- We were superseded (e.g. our lock went stale during an outage and
				-- another server stole it). Never write again this session.
				loadedOk[player] = false
				warn(string.format("[Squishy Smash] Session lock for %s was taken by another server — this session stops saving.", player.Name))
				return false
			end
			return true
		end
		warn(string.format("[Squishy Smash] DataStore save failed for %s (attempt %d/%d): %s", player.Name, attempt, MAX_RETRIES, tostring(err)))
		task.wait(attempt * 1.5)
	end
	return false
end

-- A friendly leaderboard so kids see their Sparkle Coins, friends, and pops.
local function setupLeaderstats(player: Player, profile: Profile)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Sparkle Coins"
	coins.Value = profile.SparkleCoins
	coins.Parent = stats
	local discovered = Instance.new("IntValue")
	discovered.Name = "Friends"
	discovered.Value = profile.DiscoveredCount
	discovered.Parent = stats
	local pops = Instance.new("IntValue")
	pops.Name = "Happy Pops"
	pops.Value = profile.TotalHappyPops
	pops.Parent = stats
	stats.Parent = player
end

local function refreshLeaderstats(player: Player, profile: Profile)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end
	local coins = stats:FindFirstChild("Sparkle Coins") :: IntValue?
	if coins then coins.Value = profile.SparkleCoins end
	local discovered = stats:FindFirstChild("Friends") :: IntValue?
	if discovered then discovered.Value = profile.DiscoveredCount end
	local pops = stats:FindFirstChild("Happy Pops") :: IntValue?
	if pops then pops.Value = profile.TotalHappyPops end
end

function PlayerDataService.get(player: Player): Profile?
	return profiles[player]
end

-- Build the snapshot the client needs to draw the HUD + Squishy Book.
function PlayerDataService.snapshot(player: Player)
	local p = profiles[player]
	if not p then
		return nil
	end
	return {
		coins = p.SparkleCoins,
		totalSquishes = p.TotalSquishes,
		totalHappyPops = p.TotalHappyPops,
		discovered = p.Discovered,
		discoveredCount = p.DiscoveredCount,
		equippedBuddyId = p.EquippedBuddyId,
		zone = GameConfig.ZoneName,
		tutorial = {
			popped = math.min(p.TotalHappyPops, GameConfig.TutorialPopGoal),
			goal = GameConfig.TutorialPopGoal,
			done = p.TutorialDone,
			firstCapsuleClaimed = p.FirstCapsuleClaimed,
		},
		shards = p.Shards,
		-- the set of hidden Sparkle Bits this player has already found (so the
		-- client never re-renders one they've collected)
		sparkleBits = p.SparkleBits,
		-- per-friend variant level (1 = Sparkly, 2 = Rainbow) for the Book + reveal
		variants = p.Variants,
		-- whether today's free Sparkle Capsule is available to claim
		dailyCapsuleReady = todayIndex() > p.LastDailyCapsuleDay,
		-- daily quests + gentle streak (the client derives the active set from `day`)
		daily = {
			streak = p.StreakDays,
			day = p.DailyQuests.day,
			progress = p.DailyQuests.progress,
			claimed = p.DailyQuests.claimed,
		},
		sparkleRestored = p.SparkleRestored,
		-- the Sparkle Boutique: what they own + what their buddy is wearing
		cosmetics = {
			owned = p.Cosmetics.Owned,
			equipped = p.Cosmetics.Equipped,
		},
	}
end

function PlayerDataService.sync(player: Player)
	local snap = PlayerDataService.snapshot(player)
	if snap then
		stateSyncEvent:FireClient(player, snap)
	end
end

function PlayerDataService.addCoins(player: Player, amount: number)
	local p = profiles[player]
	if not p then return end
	p.SparkleCoins += amount
	refreshLeaderstats(player, p)
end

-- Returns true if the player could afford it (and were charged).
function PlayerDataService.spendCoins(player: Player, amount: number): boolean
	local p = profiles[player]
	if not p or p.SparkleCoins < amount then
		return false
	end
	p.SparkleCoins -= amount
	refreshLeaderstats(player, p)
	return true
end

function PlayerDataService.getCoins(player: Player): number
	local p = profiles[player]
	return p and p.SparkleCoins or 0
end

function PlayerDataService.incSquish(player: Player)
	local p = profiles[player]
	if not p then return end
	p.TotalSquishes += 1
end

function PlayerDataService.incHappyPop(player: Player)
	local p = profiles[player]
	if not p then return end
	p.TotalHappyPops += 1
	refreshLeaderstats(player, p)
end

-- Returns true if this friend was NEWLY discovered.
function PlayerDataService.discoverCard(player: Player, defId: string): boolean
	local p = profiles[player]
	if not p or p.Discovered[defId] then
		return false
	end
	p.Discovered[defId] = true
	p.DiscoveredCount += 1
	refreshLeaderstats(player, p)
	return true
end

function PlayerDataService.hasDiscovered(player: Player, defId: string): boolean
	local p = profiles[player]
	return (p ~= nil) and (p.Discovered[defId] == true)
end

function PlayerDataService.hasSparkleBit(player: Player, id: string): boolean
	local p = profiles[player]
	return (p ~= nil) and (p.SparkleBits[id] == true)
end

-- Marks a hidden Sparkle Bit as found. Returns (newlyCollected, totalFound).
function PlayerDataService.collectSparkleBit(player: Player, id: string): (boolean, number)
	local p = profiles[player]
	if not p then
		return false, 0
	end
	if p.SparkleBits[id] then
		return false, countKeys(p.SparkleBits)
	end
	p.SparkleBits[id] = true
	return true, countKeys(p.SparkleBits)
end

function PlayerDataService.getVariant(player: Player, id: string): number
	local p = profiles[player]
	return (p and p.Variants[id]) or 0
end

-- Upgrade an owned friend's variant one step (Discovered -> Sparkly -> Rainbow).
-- Returns the new level (unchanged if not owned or already maxed).
function PlayerDataService.upgradeVariant(player: Player, id: string): number
	local p = profiles[player]
	if not p or not p.Discovered[id] then
		return 0
	end
	local cur = p.Variants[id] or 0
	if cur >= VariantConfig.Max then
		return cur
	end
	cur += 1
	p.Variants[id] = cur
	return cur
end

function PlayerDataService.isDailyCapsuleReady(player: Player): boolean
	local p = profiles[player]
	return p ~= nil and todayIndex() > p.LastDailyCapsuleDay
end

function PlayerDataService.markDailyCapsuleClaimed(player: Player)
	local p = profiles[player]
	if not p then
		return
	end
	p.LastDailyCapsuleDay = todayIndex()
end

function PlayerDataService.isSparkleRestored(player: Player): boolean
	local p = profiles[player]
	return (p ~= nil) and (p.SparkleRestored == true)
end

function PlayerDataService.markSparkleRestored(player: Player)
	local p = profiles[player]
	if p then
		p.SparkleRestored = true
	end
end

-- OWNER-ONLY playtest tool: wipe a player's profile back to a brand-new start.
-- The fresh profile persists on the next save (the rejoin kick triggers one).
-- The caller MUST gate this to the place owner.
function PlayerDataService.resetProfile(player: Player)
	if not profiles[player] then
		return
	end
	local fresh = newProfile()
	profiles[player] = fresh
	refreshLeaderstats(player, fresh)
	PlayerDataService.sync(player)
end

function PlayerDataService.setBuddy(player: Player, defId: string?)
	local p = profiles[player]
	if not p then return end
	p.EquippedBuddyId = defId
end

-- ── Sparkle Boutique cosmetics ──────────────────────────────────────────────
function PlayerDataService.ownsCosmetic(player: Player, id: string): boolean
	local p = profiles[player]
	return (p ~= nil) and (p.Cosmetics.Owned[id] == true)
end

function PlayerDataService.grantCosmetic(player: Player, id: string)
	local p = profiles[player]
	if p then
		p.Cosmetics.Owned[id] = true
	end
end

-- Wear an owned item in its slot (id = nil takes the slot's item off).
function PlayerDataService.setEquippedCosmetic(player: Player, slot: string, id: string?)
	local p = profiles[player]
	if not p then
		return
	end
	if id ~= nil and not p.Cosmetics.Owned[id] then
		return
	end
	p.Cosmetics.Equipped[slot] = id :: any -- nil clears the slot
end

function PlayerDataService.getEquippedCosmetics(player: Player): { [string]: string }
	local p = profiles[player]
	return (p and p.Cosmetics.Equipped) or {}
end

-- ── Storybook magic words (promo codes) ─────────────────────────────────────
function PlayerDataService.hasRedeemedCode(player: Player, code: string): boolean
	local p = profiles[player]
	return (p ~= nil) and (p.RedeemedCodes[code] == true)
end

function PlayerDataService.markCodeRedeemed(player: Player, code: string)
	local p = profiles[player]
	if p then
		p.RedeemedCodes[code] = true
	end
end

function PlayerDataService.setTutorialDone(player: Player)
	local p = profiles[player]
	if not p then return end
	p.TutorialDone = true
end

function PlayerDataService.isFirstCapsuleClaimed(player: Player): boolean
	local p = profiles[player]
	return (p ~= nil) and (p.FirstCapsuleClaimed == true)
end

function PlayerDataService.markFirstCapsuleClaimed(player: Player)
	local p = profiles[player]
	if not p then return end
	p.FirstCapsuleClaimed = true
end

-- True once a player's profile has finished loading and is safe to read/sync.
function PlayerDataService.isReady(player: Player): boolean
	return ready[player] == true
end

function PlayerDataService.init()
	stateSyncEvent = Remotes.get(Remotes.StateSync)

	local function onAdded(player: Player)
		local ok, data, acquired = loadData(player)
		-- If the player left while we were loading, release anything we took.
		if player.Parent == nil then
			if ok and acquired then
				profiles[player] = deserialize(data)
				loadedOk[player] = true
				saveData(player, true) -- free the lock for their next server
				profiles[player] = nil
				loadedOk[player] = nil
			end
			return
		end
		local owned = ok and acquired
		loadedOk[player] = owned
		local profile = owned and deserialize(data) or newProfile()
		profiles[player] = profile
		setupLeaderstats(player, profile)
		ready[player] = true
		if not ok then
			warn(string.format("[Squishy Smash] %s is playing on a temporary profile — DataStores are unreachable.", player.Name))
		elseif not acquired then
			warn(string.format("[Squishy Smash] %s's profile is in use by ANOTHER session — playing on a temporary profile here (the other session's save stays safe).", player.Name))
		end
		-- Push state now in case the client's RequestInitialState arrived before
		-- the profile finished loading.
		PlayerDataService.sync(player)
	end

	Players.PlayerAdded:Connect(onAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		saveData(player, true) -- final save releases the session lock
		profiles[player] = nil
		loadedOk[player] = nil
		ready[player] = nil
	end)

	-- Background autosave so progress survives crashes between join and leave.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(saveData, player)
			end
		end
	end)

	-- Flush everyone on shutdown. BindToClose blocks the server from closing
	-- (up to ~30s) so these saves have time to land.
	game:BindToClose(function()
		local players = Players:GetPlayers()
		if #players == 0 then
			return
		end
		local remaining = #players
		for _, player in ipairs(players) do
			task.spawn(function()
				saveData(player, true) -- shutdown flush also releases the locks
				remaining -= 1
			end)
		end
		local deadline = os.clock() + 25
		while remaining > 0 and os.clock() < deadline do
			task.wait(0.2)
		end
	end)
end

return PlayerDataService
