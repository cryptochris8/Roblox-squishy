-- BeaconFx (CLIENT)
-- The Sparkle Beacon + Cheer loop (doc 15 §5): when anyone in the server
-- discovers an epic+ friend (or shines one up to Rainbow), a tall soft light
-- beam rises from that land's Sparkle Capsule — a lighthouse saying "something
-- wonderful happened over there" — and everyone ELSE gets a small toast with a
-- one-tap Cheer button. Cheers arriving at the discoverer aggregate ("3 friends
-- cheered!") so even a whole excited server can't flood a child's screen.
--
-- Pure client cosmetics + one preset button. The server (CheerService)
-- validates every cheer; names pass through StreamerMode.mask at render time.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local UiTheme = require(script.Parent.UiTheme)
local StreamerMode = require(script.Parent.StreamerMode)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local RevealConfig = require(Shared:WaitForChild("RevealConfig"))
local SoundConfig = require(Shared:WaitForChild("SoundConfig"))

local BeaconFx = {}

local localPlayer = Players.LocalPlayer
local screen
local onCheer = nil -- fn(revealId), wired by ClientController
local cheeredReveals = {} -- revealId -> true (this client already cheered it)
local activeToast = nil -- the current cheer-invite toast frame
local cheerAgg = nil -- { frame, label, count, at } — aggregated inbound cheers
local chimeTemplate = nil -- pre-warmed at mount (same-frame SoundId landmine)

local WHITE = Color3.fromRGB(255, 255, 255)

-- The local block list (BoopFx/WaterFx's pattern — GetBlockedUserIds is
-- client-only, so this respect has to live here). Best-effort: an empty set on
-- failure just means no filtering, same as the rest of the game.
local function blockedIds()
	local set = {}
	local ok, list = pcall(function()
		return StarterGui:GetCore("GetBlockedUserIds")
	end)
	if ok and type(list) == "table" then
		for _, id in ipairs(list) do
			set[id] = true
		end
	end
	return set
end

-- ── The in-world beam ────────────────────────────────────────────────────────
local function beam(pos, color)
	if typeof(pos) ~= "Vector3" then
		return
	end
	local part = Instance.new("Part")
	part.Name = "SparkleBeacon"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.2
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(90, 3.5, 3.5) -- cylinder height runs along X...
	part.CFrame = CFrame.new(pos + Vector3.new(0, 45, 0)) * CFrame.Angles(0, 0, math.rad(90)) -- ...stood upright
	part.Parent = Workspace

	local att = Instance.new("Attachment")
	att.Position = Vector3.new(44, 0, 0) -- the top of the upright beam
	att.Parent = part
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(color, WHITE)
	sparkle.Lifetime = NumberRange.new(0.8, 1.6)
	sparkle.Speed = NumberRange.new(4, 9)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Rate = 0
	sparkle.Parent = att
	-- Same courtesy scaling every other FX site applies: halved in the compact
	-- layout, halved again in Calm Sparkles mode.
	local perBurst = 14
	if UiTheme.isCompact() then
		perBurst = math.ceil(perBurst / 2)
	end
	if localPlayer:GetAttribute("CalmSparkles") == true then
		perBurst = math.ceil(perBurst / 2)
	end
	task.spawn(function()
		for _ = 1, 3 do
			sparkle:Emit(perBurst)
			task.wait(0.9)
		end
	end)

	TweenService:Create(part, TweenInfo.new(8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
	}):Play()
	Debris:AddItem(part, 9)
end

-- ── The cheer-invite toast (everyone except the discoverer) ──────────────────
local function cheerToast(info)
	if activeToast then
		activeToast:Destroy()
		activeToast = nil
	end
	local frame = UiTheme.panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -86),
		Size = UDim2.fromOffset(340, 58),
		BackgroundColor3 = UiTheme.Colors.Panel,
		radius = 18,
	})
	frame.ZIndex = 30
	frame.Parent = screen
	UiTheme.stroke(UiTheme.rarityColor(info.rarity), 3, frame)
	activeToast = frame

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromOffset(14, 0)
	text.Size = UDim2.new(1, -124, 1, 0)
	text.Font = UiTheme.BodyFont
	text.TextSize = 15
	text.TextWrapped = true
	text.TextColor3 = UiTheme.Colors.Ink
	text.TextXAlignment = Enum.TextXAlignment.Left
	-- Honest copy per beacon kind: a Rainbow shine-up is not a discovery.
	local who = StreamerMode.mask(info.byName or "A friend")
	if info.kind == "shined" then
		text.Text = "🌈 " .. who .. "'s " .. (info.friendName or "friend") .. " turned Rainbow!"
	else
		text.Text = "✨ " .. who .. " discovered " .. (info.friendName or "a friend") .. "!"
	end
	text.ZIndex = 31
	text.Parent = frame

	local btn = Instance.new("TextButton")
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -10, 0.5, 0)
	btn.Size = UDim2.fromOffset(100, 38)
	btn.BackgroundColor3 = UiTheme.Colors.AccentDeep
	btn.BorderSizePixel = 0
	btn.Font = UiTheme.HeaderFont
	btn.TextSize = 17
	btn.TextColor3 = WHITE
	btn.Text = "Cheer! 🎉"
	btn.ZIndex = 31
	btn.Active = true
	btn.Parent = frame
	UiTheme.corner(19, btn)
	local revealId = info.revealId
	btn.Activated:Connect(function()
		if cheeredReveals[revealId] then
			return
		end
		cheeredReveals[revealId] = true
		btn.Text = "Sent 💖"
		btn.BackgroundColor3 = UiTheme.Colors.Accent
		if onCheer then
			onCheer(revealId)
		end
	end)

	frame.Position = UDim2.new(0.5, 0, 1, 0)
	TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -86),
	}):Play()
	task.delay(8, function()
		if frame.Parent then
			TweenService:Create(frame, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 1, 70) }):Play()
			Debris:AddItem(frame, 0.35)
		end
		if activeToast == frame then
			activeToast = nil
		end
	end)
end

-- A beacon fired somewhere in the server.
function BeaconFx.play(info)
	if type(info) ~= "table" then
		return
	end
	beam(info.pos, UiTheme.rarityColor(info.rarity))
	-- The nameless beam is for everyone; the named toast never renders for
	-- someone this player has blocked (doc 14 §1 — the block list lives here).
	if info.byUserId ~= localPlayer.UserId and not blockedIds()[info.byUserId] then
		cheerToast(info)
	end
end

-- A validated cheer arrived for MY discovery. First one gets its own warm line;
-- friends piling on within the window just tick the count up.
function BeaconFx.cheerArrived(info)
	if type(info) ~= "table" then
		return
	end
	-- A blocked player's cheer never reaches the screen. fromName arrives only
	-- for Roblox friends (CheerService gates it); strangers are kind visitors.
	if info.fromUserId and blockedIds()[info.fromUserId] then
		return
	end
	local now = os.clock()
	if cheerAgg and cheerAgg.frame.Parent and now - cheerAgg.at < RevealConfig.CheerAggregateSeconds then
		cheerAgg.count += 1
		cheerAgg.at = now
		cheerAgg.label.Text = "🎉 " .. cheerAgg.count .. " friends cheered your discovery!"
		return
	end
	local frame = UiTheme.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 76),
		Size = UDim2.fromOffset(330, 44),
		BackgroundColor3 = UiTheme.Colors.Panel,
		radius = 16,
	})
	frame.ZIndex = 30
	frame.Parent = screen
	UiTheme.stroke(UiTheme.Colors.Accent, 2, frame)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = UiTheme.BodyFont
	label.TextSize = 15
	label.TextColor3 = UiTheme.Colors.Ink
	label.Text = "🎉 " .. StreamerMode.mask(info.fromName or "A kind visitor") .. " cheered your discovery!"
	label.ZIndex = 31
	label.Parent = frame
	cheerAgg = { frame = frame, label = label, count = 1, at = now }
	if chimeTemplate then
		local s = chimeTemplate:Clone()
		s.Volume = 0.3
		s.PlaybackSpeed = 1.4
		s.Parent = screen
		s:Play()
		Debris:AddItem(s, 3)
	end
	task.delay(6, function()
		if frame.Parent and cheerAgg and cheerAgg.frame == frame and os.clock() - cheerAgg.at >= 5 then
			TweenService:Create(frame, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -60) }):Play()
			Debris:AddItem(frame, 0.35)
			cheerAgg = nil
		elseif frame.Parent then
			-- still collecting cheers — check again soon
			task.delay(4, function()
				if frame.Parent then
					TweenService:Create(frame, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -60) }):Play()
					Debris:AddItem(frame, 0.35)
					if cheerAgg and cheerAgg.frame == frame then
						cheerAgg = nil
					end
				end
			end)
		end
	end)
end

function BeaconFx.mount(playerGui, cheerFn)
	onCheer = cheerFn
	screen = Instance.new("ScreenGui")
	screen.Name = "SparkleBeacon"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 55 -- under the reveal (60): your own ceremony outranks the server's news
	screen.Parent = playerGui
	-- Warm the cheer chime so the first one isn't eaten mid-stream (doc 14 §2).
	chimeTemplate = Instance.new("Sound")
	chimeTemplate.Name = "CheerChimeTemplate"
	chimeTemplate.SoundId = SoundConfig.Chime
	chimeTemplate.Volume = 0
	chimeTemplate.Parent = screen
end

return BeaconFx
