-- BoopFx (CLIENT)
-- Plays the friendly Boop FX (a heart/sparkle pop between two players) and keeps
-- the Boop prompts kind:
--   • your OWN Boop prompt is hidden (so it never sits in your face)
--   • a prompt is hidden for anyone on your Roblox block list (GetBlockedUserIds
--     is client-only, so this respect has to live here)
--   • incoming boop FX are capped per character (~2) so nobody gets pile-on'd

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local BoopFx = {}

local localPlayer = Players.LocalPlayer
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- character -> count of incoming boop FX currently playing (cap = 2). Weak keys so
-- a booped character that respawns/leaves drops out on GC.
local activeFx = setmetatable({}, { __mode = "k" }) :: { [Model]: number }

local function blockedIds(): { [number]: boolean }
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

-- Hide the Boop prompt on my OWN character and on anyone I've blocked.
local function refreshPrompts()
	local blocked = blockedIds()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local prompt = root and root:FindFirstChild("BoopPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			local ownerId = prompt:GetAttribute("OwnerUserId")
			local hide = ownerId == localPlayer.UserId or (type(ownerId) == "number" and blocked[ownerId] == true)
			prompt.Enabled = not hide
		end
	end
end

local function heartBurst(part: BasePart, tier: string)
	if not part or not part.Parent then
		return
	end
	local em = Instance.new("ParticleEmitter")
	em.Texture = SPARKLE
	em.LightEmission = 0.8
	em.Rate = 0
	em.Lifetime = NumberRange.new(0.6, 1.0)
	em.Speed = NumberRange.new(3, 7)
	em.SpreadAngle = Vector2.new(180, 180)
	em.Acceleration = Vector3.new(0, 3, 0)
	em.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.4, 1.0), NumberSequenceKeypoint.new(1, 0),
	})
	if tier == "friend" then
		em.Color = ColorSequence.new(Color3.fromRGB(255, 120, 170), Color3.fromRGB(255, 210, 230))
	else
		em.Color = ColorSequence.new(Color3.fromRGB(255, 236, 200))
	end
	em.Parent = part
	em:Emit(if tier == "friend" then 22 else 12)
	Debris:AddItem(em, 1.3)
end

local function floatHeart(part: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(60, 60)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.Parent = part
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextSize = 40
	lbl.Text = "💖"
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.Parent = gui
	TweenService:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0),
	}):Play()
	TweenService:Create(lbl, TweenInfo.new(0.9), { TextTransparency = 1 }):Play()
	Debris:AddItem(gui, 1)
end

local function charOf(userId: number): Model?
	local p = Players:GetPlayerByUserId(userId)
	return p and p.Character or nil
end

local function onBoop(info)
	if type(info) ~= "table" then
		return
	end
	local toChar = charOf(info.toUserId)
	local root = toChar and toChar:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local count = activeFx[toChar] or 0
	if count >= 2 then
		return -- already got a couple of boops this beat; don't pile on
	end
	activeFx[toChar] = count + 1
	task.delay(1.0, function()
		local left = math.max(0, (activeFx[toChar] or 1) - 1)
		activeFx[toChar] = if left > 0 then left else nil
	end)

	heartBurst(root, info.tier)
	floatHeart(root)
	-- richer FX between Roblox friends: sparkle the SENDER too (a two-way hello)
	if info.tier == "friend" then
		local fromChar = charOf(info.fromUserId)
		local fromRoot = fromChar and fromChar:FindFirstChild("HumanoidRootPart")
		if fromRoot then
			heartBurst(fromRoot, "friend")
		end
	end
end

function BoopFx.init()
	Remotes.get(Remotes.BoopFx).OnClientEvent:Connect(onBoop)

	local function hookPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.3) -- let the server attach the prompt first
			refreshPrompts()
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		hookPlayer(player)
	end
	Players.PlayerAdded:Connect(function(player)
		hookPlayer(player)
		task.wait(0.5)
		refreshPrompts()
	end)
	-- also catches block-list changes and any prompt that streamed in late
	task.spawn(function()
		while true do
			refreshPrompts()
			task.wait(6)
		end
	end)
end

return BoopFx
