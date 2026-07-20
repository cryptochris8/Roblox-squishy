--!strict
-- LeaderboardService (SERVER)
-- Two friendly boards by the Pudding Hills travel hub: "Top Friend Finders"
-- (friends discovered) and "Joy Champions" (Happy Pops given). Backed by
-- OrderedDataStores so they reach across every server. Celebrates collecting
-- and kindness — never combat. Like player data, the stores are pcall-guarded:
-- in an unpublished place the boards simply show a cozy "warming up" note.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local DataStoreService = game:GetService("DataStoreService")
local UserService = game:GetService("UserService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SocialConfig = require(Shared:WaitForChild("SocialConfig"))
local WeeklyConfig = require(Shared:WaitForChild("WeeklyConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local LeaderboardService = {}

type BoardSpec = {
	storeName: string,
	title: string,
	subtitle: string,
	accent: Color3,
	weekly: boolean?, -- true = a per-week store (resets even each week)
	score: (profile: any) -> number,
}

local BOARDS: { BoardSpec } = {
	{
		-- A brand new week of kindness — everyone starts even each week, so the
		-- youngest/newest friend is never buried under tenure. Gifts, not combat.
		storeName = "SquishyBoard_Kindest_v1",
		title = "💝 Kindest Friends",
		subtitle = "gifts given this week",
		accent = Color3.fromRGB(120, 195, 130),
		weekly = true,
		score = function(profile)
			local gw = profile.GiftsWeek
			return (gw and gw.week == WeeklyConfig.weekIndex()) and gw.count or 0
		end,
	},
	{
		storeName = "SquishyBoard_Friends_v1",
		title = "🏆 Top Friend Finders",
		subtitle = "Squishy Friends discovered",
		accent = Color3.fromRGB(240, 160, 40),
		score = function(profile)
			return profile.DiscoveredCount
		end,
	},
	{
		storeName = "SquishyBoard_Pops_v1",
		title = "💖 Joy Champions",
		subtitle = "Happy Pops given",
		accent = Color3.fromRGB(225, 90, 150),
		score = function(profile)
			return profile.TotalHappyPops
		end,
	},
}

-- One OrderedDataStore per board (nil when DataStores are unavailable, e.g. an
-- unpublished place — GetOrderedDataStore THROWS there, same as GetDataStore).
local stores: { [string]: OrderedDataStore } = {}
local storesEnabled = false
do
	local ok = pcall(function()
		for _, spec in ipairs(BOARDS) do
			stores[spec.storeName] = DataStoreService:GetOrderedDataStore(spec.storeName)
		end
	end)
	storesEnabled = ok
	if not ok then
		warn("[Squishy Smash] Leaderboards unavailable this session (place not published / no API access).")
	end
end

-- userId -> the friendly name we show on the boards.
-- Weekly boards live in a per-week OrderedDataStore (name carries the week index),
-- created lazily and cached, so each new week starts everyone at zero.
local weeklyStores: { [string]: OrderedDataStore } = {}
local function activeStore(spec: BoardSpec): (OrderedDataStore?, string)
	if not spec.weekly then
		return stores[spec.storeName], spec.storeName
	end
	local name = spec.storeName .. "_w" .. WeeklyConfig.weekIndex()
	local s = weeklyStores[name]
	if not s and storesEnabled then
		local ok, res = pcall(function()
			return DataStoreService:GetOrderedDataStore(name)
		end)
		if ok then
			s = res
			weeklyStores[name] = s
		end
	end
	return s, name
end

local nameCache: { [number]: string } = {}
-- userId -> { [storeName]: lastWrittenValue } so we skip unchanged writes.
local lastWritten: { [number]: { [string]: number } } = {}
-- userId -> { [storeName]: value } last-known scores, for a safe write when a
-- player leaves (their profile may already be torn down by then).
local scoreCache: { [number]: { [string]: number } } = {}
-- The row TextLabels of each physical board, filled by buildBoards().
local boardRows: { [string]: { { rank: TextLabel, name: TextLabel, value: TextLabel, row: Frame } } } = {}
local boardNotes: { [string]: TextLabel } = {}

local function cacheScores(player: Player)
	local profile = PlayerDataService.get(player)
	if not profile then
		return
	end
	local byStore = scoreCache[player.UserId] or {}
	for _, spec in ipairs(BOARDS) do
		byStore[spec.storeName] = spec.score(profile)
	end
	scoreCache[player.UserId] = byStore
	nameCache[player.UserId] = player.DisplayName
end

-- Write one player's scores (from their live profile, or the cache if they're
-- already gone). Quietly skips values that haven't changed.
local function writeScores(userId: number)
	if not storesEnabled then
		return
	end
	local byStore = scoreCache[userId]
	if not byStore then
		return
	end
	local written = lastWritten[userId] or {}
	for _, spec in ipairs(BOARDS) do
		local value = byStore[spec.storeName]
		local store, activeName = activeStore(spec)
		if store and value and value > 0 and value ~= written[activeName] then
			local ok, err = pcall(function()
				store:SetAsync(tostring(userId), value)
			end)
			if ok then
				written[activeName] = value
			else
				warn("[Squishy Smash] Leaderboard write failed: " .. tostring(err))
			end
		end
	end
	lastWritten[userId] = written
end

-- A friendly display name for a userId: online players answer instantly; others
-- come from UserService (batched would be nicer, but the boards refresh rarely).
local function friendlyName(userId: number): string
	local cached = nameCache[userId]
	if cached then
		return cached
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.DisplayName
		return online.DisplayName
	end
	local name = "A Squishy Friend"
	pcall(function()
		local infos = UserService:GetUserInfosByUserIdsAsync({ userId })
		if infos and infos[1] and infos[1].DisplayName then
			name = infos[1].DisplayName
		end
	end)
	nameCache[userId] = name
	return name
end

-- ── The physical boards ─────────────────────────────────────────────────────

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(p :: any)[key] = value
	end
	return p
end

local RANK_COLORS = {
	Color3.fromRGB(240, 165, 50),  -- gold
	Color3.fromRGB(160, 165, 185), -- silver
	Color3.fromRGB(196, 132, 96),  -- bronze
}

local function buildBoard(parent: Instance, spec: BoardSpec, position: Vector3, lookAt: Vector3)
	local model = Instance.new("Model")
	model.Name = "Board_" .. spec.storeName

	local face = CFrame.lookAt(Vector3.new(position.X, 0, position.Z), Vector3.new(lookAt.X, 0, lookAt.Z))

	local panel = part({
		Name = "Panel", Size = Vector3.new(11, 7.6, 0.7),
		Color = Color3.fromRGB(255, 247, 240),
	})
	panel.CFrame = face + Vector3.new(0, 6.6, 0)
	panel.Parent = model
	for _, sx in ipairs({ -1, 1 }) do
		local leg = part({
			Name = "Leg", Size = Vector3.new(0.9, 4, 0.9),
			Color = Color3.fromRGB(206, 170, 120),
		})
		leg.CFrame = face * CFrame.new(sx * 4.4, 0, 0) + Vector3.new(0, 2, 0)
		leg.Parent = model
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.Brightness = 1.2
	gui.Parent = panel

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(255, 247, 240)
	bg.BorderSizePixel = 0
	bg.Parent = gui

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 78)
	header.BackgroundColor3 = spec.accent
	header.BorderSizePixel = 0
	header.Parent = bg

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -20, 0, 48)
	title.Position = UDim2.fromOffset(10, 4)
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 34
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = spec.title
	title.Parent = header

	local subtitle = Instance.new("TextLabel")
	subtitle.BackgroundTransparency = 1
	subtitle.Size = UDim2.new(1, -20, 0, 24)
	subtitle.Position = UDim2.fromOffset(10, 48)
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextSize = 16
	subtitle.TextColor3 = Color3.fromRGB(255, 240, 246)
	subtitle.Text = spec.subtitle
	subtitle.Parent = header

	local note = Instance.new("TextLabel")
	note.BackgroundTransparency = 1
	note.Size = UDim2.new(1, -30, 1, -90)
	note.Position = UDim2.fromOffset(15, 84)
	note.Font = Enum.Font.GothamMedium
	note.TextSize = 18
	note.TextWrapped = true
	note.TextColor3 = Color3.fromRGB(150, 130, 150)
	note.Text = "✨ Warming up..."
	note.Parent = bg
	boardNotes[spec.storeName] = note

	local rows = {}
	for i = 1, SocialConfig.BoardTopCount do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -24, 0, 27)
		row.Position = UDim2.new(0, 12, 0, 84 + (i - 1) * 29)
		row.BackgroundColor3 = (i % 2 == 1) and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(252, 240, 236)
		row.BackgroundTransparency = 0.25
		row.BorderSizePixel = 0
		row.Visible = false
		row.Parent = bg
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = row

		local rank = Instance.new("TextLabel")
		rank.BackgroundTransparency = 1
		rank.Size = UDim2.fromOffset(44, 27)
		rank.Font = Enum.Font.FredokaOne
		rank.TextSize = 19
		rank.TextColor3 = RANK_COLORS[i] or Color3.fromRGB(150, 130, 150)
		rank.Text = tostring(i)
		rank.Parent = row

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(1, -140, 1, 0)
		name.Position = UDim2.fromOffset(48, 0)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 17
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextColor3 = Color3.fromRGB(96, 74, 96)
		name.Text = ""
		name.Parent = row

		local value = Instance.new("TextLabel")
		value.BackgroundTransparency = 1
		value.Size = UDim2.fromOffset(80, 27)
		value.Position = UDim2.new(1, -88, 0, 0)
		value.Font = Enum.Font.FredokaOne
		value.TextSize = 19
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.TextColor3 = spec.accent
		value.Text = ""
		value.Parent = row

		rows[i] = { rank = rank, name = name, value = value, row = row }
	end
	boardRows[spec.storeName] = rows

	model.Parent = parent
end

-- Re-read the top list for one board and repaint its rows.
local function refreshBoard(spec: BoardSpec)
	local rows = boardRows[spec.storeName]
	local note = boardNotes[spec.storeName]
	if not rows then
		return
	end
	if not storesEnabled then
		if note then
			note.Text = "💤 The board is napping — it wakes up in the real game!"
		end
		return
	end

	local store = activeStore(spec)
	if not store then
		return
	end
	local entries: { { key: string, value: number } } = {}
	local ok, err = pcall(function()
		local pages = store:GetSortedAsync(false, SocialConfig.BoardTopCount)
		entries = pages:GetCurrentPage()
	end)
	if not ok then
		warn("[Squishy Smash] Leaderboard read failed: " .. tostring(err))
		return
	end

	if note then
		note.Text = (#entries == 0) and "Be the first friend on the board! ✨" or ""
	end
	for i, slot in ipairs(rows) do
		local entry = entries[i]
		if entry then
			local userId = tonumber(entry.key)
			slot.name.Text = userId and friendlyName(userId) or "A Squishy Friend"
			slot.value.Text = tostring(entry.value)
			slot.row.Visible = true
		else
			slot.row.Visible = false
		end
	end
end

local function refreshAll()
	for _, player in ipairs(Players:GetPlayers()) do
		cacheScores(player)
		writeScores(player.UserId)
	end
	for _, spec in ipairs(BOARDS) do
		refreshBoard(spec)
	end
end

function LeaderboardService.init()
	-- The boards flank the Travel Plaza on the eastern rise (districts pass),
	-- so every trip to the Travel Pads walks past them. Built once the land exists.
	task.spawn(function()
		local home = Workspace:WaitForChild("PuddingHills", 30) or Workspace
		local lookAt = Vector3.new(116, 0, 23) -- face the plaza the pads sit on
		buildBoard(home, BOARDS[2], Vector3.new(96, 0, 35), lookAt)  -- Top Friend Finders
		buildBoard(home, BOARDS[1], Vector3.new(116, 0, 35), lookAt)  -- Kindest Friends (center)
		buildBoard(home, BOARDS[3], Vector3.new(136, 0, 35), lookAt)  -- Joy Champions

		-- First refresh soon after startup (so a solo Studio run sees itself fast),
		-- then the gentle long cycle.
		task.wait(8)
		refreshAll()
		while true do
			task.wait(SocialConfig.BoardRefreshSeconds)
			refreshAll()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- Their profile may already be torn down — cacheScores no-ops then, and we
		-- write the last scores we saw.
		cacheScores(player)
		writeScores(player.UserId)
		task.delay(5, function()
			scoreCache[player.UserId] = nil
			lastWritten[player.UserId] = nil
		end)
	end)
end

return LeaderboardService
