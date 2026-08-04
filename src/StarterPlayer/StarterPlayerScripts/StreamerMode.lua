-- StreamerMode (CLIENT)
-- The "safe to put on camera" switch.
--
-- Squishy Smash is played by little kids, and a Roblox username is a real
-- identifier — so anyone recording or streaming the game needs a way to keep
-- OTHER players' names out of the video. Flip this on and, ON YOUR SCREEN ONLY,
-- every other player becomes a warm storybook alias ("Bubble Friend", "Cozy
-- Friend", ...). Covered surfaces:
--
--   * the Roblox player list (hidden outright — it is nothing but usernames)
--   * overhead character names + health bars
--   * chat: the sender prefix AND any name inside a message
--   * every toast the server sends (discoveries, shards, gifts, VIP arrivals...)
--   * world text: buddy name tags, gift/boop prompts, garden plot signs
--   * the leaderboard boards — including names from OTHER servers, which we
--     can't look up, so those get aliased by their own text instead
--
-- An alias is stable for the whole session, so you can still say "nice find,
-- Bubble Friend!" on stream and mean one particular person.
--
-- Pure client cosmetics. Nothing here talks to the server, nothing here changes
-- anyone else's game, and no gameplay depends on it. Your OWN name is left
-- alone — it's your channel.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local StreamerMode = {}

-- Storybook aliases, straight out of the game's own vocabulary. One per player;
-- 24 covers a full server with room to spare (see aliasFor for the overflow).
local ALIASES = {
	"Sparkle Friend", "Bubble Friend", "Cozy Friend", "Bouncy Friend",
	"Twinkle Friend", "Marshmallow Friend", "Jellybean Friend", "Peppermint Friend",
	"Honey Friend", "Cloud Friend", "Berry Friend", "Pudding Friend",
	"Moonbeam Friend", "Sunbeam Friend", "Cinnamon Friend", "Blossom Friend",
	"Caramel Friend", "Gumdrop Friend", "Sprinkle Friend", "Lullaby Friend",
	"Meadow Friend", "Starlight Friend", "Snuggle Friend", "Waffle Friend",
}

-- Every piece of world text gets a property listener, so a repaint (the
-- leaderboards refresh in place, a garden sign changes hands) is re-masked on
-- the same frame rather than flashing a real name at the camera. The sweep is
-- only a backstop for anything that was set before we could listen.
local SWEEP_SECONDS = 5

-- Only these classes can carry a name. Matched by exact ClassName, not IsA —
-- DescendantAdded fires for every part that streams in, so the filter has to be
-- as cheap as possible.
local NAME_PROPS = {
	TextLabel = { "Text" },
	TextButton = { "Text" },
	ProximityPrompt = { "ObjectText", "ActionText" },
}

local localPlayer = Players.LocalPlayer

local enabled = false
local aliasByUserId = {}   -- userId -> alias
local aliasByText = {}     -- arbitrary name string -> alias (leaderboard rows)
local aliasTaken = {}      -- alias -> true
local aliasCount = 0
local names = {}           -- { pattern, alias, len }, longest first
local tracked = {}         -- inst -> { [prop] = { original, wrote } }
local seenText = {}        -- inst -> last text we looked at (skip unchanged)
local candidates = {}      -- inst -> true
local propConns = {}       -- inst -> { connection }
local generation = 0       -- so a re-enable can't leave two sweep loops running
local origDisplayType = {} -- Humanoid -> its DisplayDistanceType before we hid it
local hookConns = {}
local onChanged = nil

-- Escape Lua pattern magic so a display name like "a+b (real)" matches literally.
local function escapePattern(s)
	return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- Pick the next free alias. Seeded from the id/text so the same person tends to
-- get the same alias across sessions, then linear-probed so two people never
-- share one. Past 24 players we start numbering.
local function claimAlias(seed)
	local start = (seed % #ALIASES) + 1
	for i = 0, #ALIASES - 1 do
		local candidate = ALIASES[((start - 1 + i) % #ALIASES) + 1]
		if not aliasTaken[candidate] then
			aliasTaken[candidate] = true
			aliasCount += 1
			return candidate
		end
	end
	aliasCount += 1
	return ALIASES[start] .. " " .. tostring(aliasCount)
end

function StreamerMode.aliasFor(player)
	local existing = aliasByUserId[player.UserId]
	if existing then
		return existing
	end
	local alias = claimAlias(math.abs(player.UserId))
	aliasByUserId[player.UserId] = alias
	return alias
end

-- For a bare name string with no player behind it (a leaderboard entry from
-- another server). Hashed off the text so the same name keeps the same alias
-- every time the board refreshes.
function StreamerMode.aliasForName(text)
	local existing = aliasByText[text]
	if existing then
		return existing
	end
	local hash = 0
	for i = 1, #text do
		hash = (hash * 31 + string.byte(text, i)) % 1000003
	end
	local alias = claimAlias(hash)
	aliasByText[text] = alias
	return alias
end

-- Rebuild the replace-list from everyone currently in the server. Both the
-- username and the display name are masked (they differ for most kids, and
-- different surfaces show different ones).
local function rebuildNames()
	names = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer then
			local alias = StreamerMode.aliasFor(player)
			local seen = {}
			for _, raw in ipairs({ player.Name, player.DisplayName }) do
				-- Roblox enforces a 3-character minimum on both; the length guard
				-- keeps a freak 1-letter name from rewriting every word on screen.
				if type(raw) == "string" and #raw >= 3 and not seen[raw] then
					seen[raw] = true
					table.insert(names, { pattern = escapePattern(raw), alias = alias, len = #raw })
				end
			end
		end
	end
	-- Longest first, so "Sam" can't chew a hole in "Sammy".
	table.sort(names, function(a, b)
		return a.len > b.len
	end)
end

function StreamerMode.isOn()
	return enabled
end

-- Replace every known player name in a string. Safe to call when the mode is
-- off (returns the text untouched), so callers need no branch of their own.
function StreamerMode.mask(text)
	if not enabled or type(text) ~= "string" or text == "" then
		return text
	end
	local out = text
	for _, entry in ipairs(names) do
		-- function replacement: the alias is inserted literally, never read as a
		-- %-capture reference
		out = out:gsub(entry.pattern, function()
			return entry.alias
		end)
	end
	return out
end

-- A leaderboard row's name cell. Its whole text IS a name, and the player is
-- usually on another server (so `names` can't know them) — alias it wholesale.
local function isBoardEntry(inst)
	return inst.Name == "EntryName" and inst:FindFirstAncestor("BoardGui") ~= nil
end

local function maskFor(inst, text)
	local masked = StreamerMode.mask(text)
	if masked == text and text ~= "" and isBoardEntry(inst) then
		return StreamerMode.aliasForName(text)
	end
	return masked
end

local function applyTo(inst)
	local props = NAME_PROPS[inst.ClassName]
	if not props then
		return
	end
	for _, prop in ipairs(props) do
		local current = inst[prop]
		if type(current) == "string" and current ~= "" then
			local record = tracked[inst] and tracked[inst][prop]
			-- If the server repainted this label since we masked it, the new text
			-- is the truth and our old "original" is stale.
			if record and current ~= record.wrote then
				record = nil
			end
			local source = record and record.original or current
			local masked = maskFor(inst, source)
			if masked ~= source then
				if masked ~= current then
					inst[prop] = masked
				end
				tracked[inst] = tracked[inst] or {}
				tracked[inst][prop] = { original = source, wrote = masked }
			end
		end
	end
end

local function forget(inst)
	local conns = propConns[inst]
	if conns then
		for _, conn in ipairs(conns) do
			conn:Disconnect()
		end
	end
	propConns[inst] = nil
	candidates[inst] = nil
	tracked[inst] = nil
	seenText[inst] = nil
end

-- Cheap per-instance gate: skip anything whose text hasn't moved since we last
-- looked and that we've never masked. First sighting also wires the listeners
-- that keep a repaint from ever reaching the screen unmasked.
local function considerCandidate(inst)
	local props = NAME_PROPS[inst.ClassName]
	if not props then
		return
	end
	if not candidates[inst] then
		candidates[inst] = true
		local conns = {}
		for _, prop in ipairs(props) do
			-- Re-masking our own write is a no-op (the text already equals what we
			-- wrote), so this can't feed back on itself.
			conns[#conns + 1] = inst:GetPropertyChangedSignal(prop):Connect(function()
				if enabled then
					applyTo(inst)
					seenText[inst] = inst[props[1]]
				end
			end)
		end
		propConns[inst] = conns
	end
	local first = inst[props[1]]
	if seenText[inst] == first and not tracked[inst] then
		return
	end
	applyTo(inst)
	seenText[inst] = inst[props[1]]
end

local function sweep()
	for inst in pairs(candidates) do
		if inst.Parent == nil then
			forget(inst)
		else
			considerCandidate(inst)
		end
	end
end

local function scanWorld()
	-- One full pass on toggle-on. The world is big, but this only runs when a
	-- human flips the switch, and DescendantAdded keeps it current after that.
	for _, inst in ipairs(Workspace:GetDescendants()) do
		if NAME_PROPS[inst.ClassName] then
			considerCandidate(inst)
		end
	end
end

local function restoreWorld()
	for inst, props in pairs(tracked) do
		if inst.Parent ~= nil then
			for prop, record in pairs(props) do
				-- Only undo our own edit. If something rewrote the label since, that
				-- newer text wins.
				if inst[prop] == record.wrote then
					inst[prop] = record.original
				end
			end
		end
	end
	for inst in pairs(candidates) do
		local conns = propConns[inst]
		if conns then
			for _, conn in ipairs(conns) do
				conn:Disconnect()
			end
		end
	end
	propConns = {}
	tracked = {}
	seenText = {}
	candidates = {}
end

-- Overhead names + health bars on everyone else's character.
local function hideOverhead(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if origDisplayType[humanoid] == nil then
		origDisplayType[humanoid] = humanoid.DisplayDistanceType
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
end

local function applyOverheadAll()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= localPlayer and player.Character then
			hideOverhead(player.Character)
		end
	end
end

local function restoreOverhead()
	for humanoid, original in pairs(origDisplayType) do
		if humanoid.Parent ~= nil then
			humanoid.DisplayDistanceType = original
		end
	end
	origDisplayType = {}
end

local function watchPlayer(player)
	if player == localPlayer then
		return
	end
	table.insert(hookConns, player.CharacterAdded:Connect(function(character)
		if enabled then
			-- the Humanoid lands a moment after the model does
			task.delay(0.4, function()
				if enabled and character.Parent then
					hideOverhead(character)
				end
			end)
		end
	end))
end

function StreamerMode.setEnabled(on)
	on = on == true
	if on == enabled then
		return
	end
	enabled = on

	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not on)
	end)

	if on then
		rebuildNames()
		scanWorld()
		applyOverheadAll()

		table.insert(hookConns, Workspace.DescendantAdded:Connect(function(inst)
			if enabled and NAME_PROPS[inst.ClassName] then
				considerCandidate(inst)
			end
		end))
		table.insert(hookConns, Players.PlayerAdded:Connect(function(player)
			if enabled then
				rebuildNames()
				watchPlayer(player)
			end
		end))
		table.insert(hookConns, Players.PlayerRemoving:Connect(function()
			-- The alias stays claimed on purpose: if they come back mid-stream they
			-- are the same "Bubble Friend" the chat already knows.
			if enabled then
				task.defer(rebuildNames)
			end
		end))
		for _, player in ipairs(Players:GetPlayers()) do
			watchPlayer(player)
		end

		-- Tagged with the generation so an off-then-on can never leave two loops
		-- sweeping at once.
		generation += 1
		local myGeneration = generation
		task.spawn(function()
			while enabled and generation == myGeneration do
				task.wait(SWEEP_SECONDS)
				if enabled and generation == myGeneration then
					sweep()
				end
			end
		end)
	else
		for _, conn in ipairs(hookConns) do
			conn:Disconnect()
		end
		hookConns = {}
		restoreWorld()
		restoreOverhead()
	end

	if onChanged then
		onChanged(enabled)
	end
end

function StreamerMode.toggle()
	StreamerMode.setEnabled(not enabled)
	return enabled
end

-- Let the UI hear about changes it didn't make.
function StreamerMode.onChanged(callback)
	onChanged = callback
end

function StreamerMode.init()
	-- Chat runs through here whether or not the mode is on, so the callback is
	-- installed once and simply passes messages through while it's off.
	pcall(function()
		TextChatService.OnIncomingMessage = function(message)
			if not enabled then
				return nil
			end
			local props = Instance.new("TextChatMessageProperties")
			local changed = false

			local source = message.TextSource
			if source then
				local sender = Players:GetPlayerByUserId(source.UserId)
				if sender and sender ~= localPlayer then
					props.PrefixText = StreamerMode.aliasFor(sender) .. ":"
					changed = true
				end
			end

			-- Names can also appear inside the message body, and in the system
			-- "so-and-so has joined" lines (which have no TextSource at all).
			local maskedText = StreamerMode.mask(message.Text)
			if maskedText ~= message.Text then
				props.Text = maskedText
				changed = true
			end

			return changed and props or nil
		end
	end)
end

return StreamerMode
