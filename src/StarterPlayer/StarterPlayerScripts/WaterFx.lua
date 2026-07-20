-- WaterFx (CLIENT)
-- The client half of the Sparkle Garden's kindness watering:
--   • keeps each garden plot's prompts kind — you only ever see "Tend" on YOUR
--     plot and "Water" on someone ELSE's (never your own), and a plot owned by
--     anyone you've blocked shows no water prompt (GetBlockedUserIds is client-only)
--   • plays a gentle sparkle-heart burst when a garden gets watered
-- The server still authorises every water; this is purely visibility + FX.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local WaterFx = {}

local localPlayer = Players.LocalPlayer
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

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

local function gardenFolder(): Instance?
	local land = Workspace:FindFirstChild("PuddingHills")
	return land and land:FindFirstChild("SparkleGarden")
end

-- Show "Tend" only on my own plot; "Water" only on others' (and never a blocked
-- owner's). Cheap to run on a timer — there are only a handful of plots.
local function refreshPrompts()
	local folder = gardenFolder()
	if not folder then
		return
	end
	local blocked = blockedIds()
	for _, prompt in ipairs(folder:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			local soil = prompt.Parent
			local ownerId = soil and soil:GetAttribute("OwnerUserId")
			if type(ownerId) == "number" then
				local mine = ownerId == localPlayer.UserId
				if prompt.Name == "TendPrompt" then
					prompt.Enabled = mine
				elseif prompt.Name == "WaterPrompt" then
					prompt.Enabled = ownerId ~= 0 and not mine and not blocked[ownerId]
				end
			end
		end
	end
end

local function heartBurst(part: BasePart)
	if not part or not part.Parent then
		return
	end
	local em = Instance.new("ParticleEmitter")
	em.Texture = SPARKLE
	em.LightEmission = 0.8
	em.Rate = 0
	em.Lifetime = NumberRange.new(0.6, 1.1)
	em.Speed = NumberRange.new(2.5, 6)
	em.SpreadAngle = Vector2.new(180, 180)
	em.Acceleration = Vector3.new(0, 3, 0)
	em.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.4, 1.0),
		NumberSequenceKeypoint.new(1, 0),
	})
	em.Color = ColorSequence.new(Color3.fromRGB(150, 220, 255), Color3.fromRGB(255, 210, 235))
	em.Parent = part
	em:Emit(18)
	Debris:AddItem(em, 1.4)
end

local function floatDrop(part: BasePart)
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
	lbl.Text = "💧"
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.Parent = gui
	TweenService:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, 6.5, 0),
	}):Play()
	TweenService:Create(lbl, TweenInfo.new(0.9), { TextTransparency = 1 }):Play()
	Debris:AddItem(gui, 1)
end

-- Find the soil part of the plot currently owned by a given userId.
local function plotSoilOf(userId: number): BasePart?
	local folder = gardenFolder()
	if not folder then
		return nil
	end
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") then
			local soil = model:FindFirstChild("Soil")
			if soil and soil:IsA("BasePart") and soil:GetAttribute("OwnerUserId") == userId then
				return soil
			end
		end
	end
	return nil
end

local function charRoot(userId: number): BasePart?
	local p = Players:GetPlayerByUserId(userId)
	local char = p and p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root and (root :: BasePart) or nil
end

local function onWater(info)
	if type(info) ~= "table" then
		return
	end
	local soil = if type(info.toUserId) == "number" then plotSoilOf(info.toUserId) else nil
	if soil then
		heartBurst(soil)
		floatDrop(soil)
	end
	local visitorRoot = if type(info.fromUserId) == "number" then charRoot(info.fromUserId) else nil
	if visitorRoot then
		heartBurst(visitorRoot)
	end
end

function WaterFx.init()
	Remotes.get(Remotes.WaterFx).OnClientEvent:Connect(onWater)
	Players.PlayerAdded:Connect(function()
		task.wait(0.5)
		refreshPrompts()
	end)
	-- catches plot claim/release, block-list changes, and late-streamed prompts
	task.spawn(function()
		while true do
			refreshPrompts()
			task.wait(3)
		end
	end)
end

return WaterFx
