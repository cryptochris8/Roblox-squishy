--!strict
-- BuddyService (SERVER)
-- Spawns the player's equipped Squishy Friend as a cute companion that floats and
-- gently bobs along behind them. Purely cosmetic, server-spawned (so everyone sees
-- each other's buddies) and never collides with or blocks anything.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SquishyData = require(Shared:WaitForChild("SquishyData"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local BuddyService = {}

-- Soft pastel body color per rarity (matches the world squishies).
local RARITY_COLORS = {
	common = Color3.fromRGB(255, 196, 212),
	rare = Color3.fromRGB(176, 196, 255),
	epic = Color3.fromRGB(214, 176, 255),
	legendary = Color3.fromRGB(255, 226, 150),
	mythic = Color3.fromRGB(255, 210, 170),
}
local EYE_COLOR = Color3.fromRGB(64, 48, 64)

local buddies: { [Player]: Model } = {}
local buddyFolder: Folder

local function roundFrame(parent: Instance, radius: number): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = f
	f.Parent = parent
	return f
end

-- A cute, always-happy face (eyes + shine, rosy cheeks, a smile).
local function addFace(body: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Face"
	gui.Size = UDim2.fromOffset(66, 56)
	gui.StudsOffset = Vector3.new(0, 0.1, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Parent = body

	local function eye(px: number)
		local e = roundFrame(gui, 6)
		e.AnchorPoint = Vector2.new(0.5, 0.5)
		e.Position = UDim2.fromScale(px, 0.42)
		e.Size = UDim2.fromOffset(13, 15)
		e.BackgroundColor3 = EYE_COLOR
		local shine = roundFrame(e, 3)
		shine.AnchorPoint = Vector2.new(0.5, 0.5)
		shine.Position = UDim2.fromScale(0.35, 0.3)
		shine.Size = UDim2.fromOffset(4, 4)
		shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	end
	eye(0.3)
	eye(0.7)

	local function cheek(px: number)
		local c = roundFrame(gui, 5)
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Position = UDim2.fromScale(px, 0.58)
		c.Size = UDim2.fromOffset(11, 8)
		c.BackgroundColor3 = Color3.fromRGB(255, 150, 175)
		c.BackgroundTransparency = 0.35
	end
	cheek(0.15)
	cheek(0.85)

	local mouth = roundFrame(gui, 5)
	mouth.AnchorPoint = Vector2.new(0.5, 0.5)
	mouth.Position = UDim2.fromScale(0.5, 0.64)
	mouth.Size = UDim2.fromOffset(17, 10)
	mouth.BackgroundColor3 = EYE_COLOR
end

local function buildBuddy(def): Model
	local model = Instance.new("Model")
	model.Name = "Buddy"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(2.6, 2.6, 2.6)
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false -- never blocks clicks/raycasts (so squishing still works)
	body.CanTouch = false
	body.Massless = true
	body.Material = Enum.Material.SmoothPlastic
	body.Color = RARITY_COLORS[def.Rarity] or RARITY_COLORS.common
	body.Parent = model
	model.PrimaryPart = body

	addFace(body)

	local nameGui = Instance.new("BillboardGui")
	nameGui.Name = "BuddyName"
	nameGui.Size = UDim2.fromOffset(140, 24)
	nameGui.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	nameGui.AlwaysOnTop = true
	nameGui.MaxDistance = 60
	nameGui.Parent = body
	local nameLbl = Instance.new("TextLabel")
	nameLbl.BackgroundTransparency = 1
	nameLbl.Size = UDim2.fromScale(1, 1)
	nameLbl.Font = Enum.Font.FredokaOne
	nameLbl.TextSize = 16
	nameLbl.TextColor3 = Color3.fromRGB(110, 80, 110)
	nameLbl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	nameLbl.TextStrokeTransparency = 0.2
	nameLbl.Text = def.DisplayName
	nameLbl.Parent = nameGui

	return model
end

-- Where the buddy wants to be: behind, to the side, and a little above the owner.
local function targetPosition(hrp: BasePart): Vector3
	local cf = hrp.CFrame * CFrame.new(2.4, 0.6, 4.2)
	return cf.Position
end

local function clearBuddy(player: Player)
	local m = buddies[player]
	if m then
		m:Destroy()
		buddies[player] = nil
	end
end

-- Spawn (or replace) a player's buddy. Pass nil to remove it.
function BuddyService.setBuddy(player: Player, defId: string?)
	clearBuddy(player)
	if not defId then
		return
	end
	local def = SquishyData.getById(defId)
	if not def then
		return
	end
	local model = buildBuddy(def)
	model.Parent = buddyFolder
	buddies[player] = model

	-- Snap it next to the character right away so it doesn't fly in from origin.
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		model:PivotTo(CFrame.new(targetPosition(hrp)))
	end
end

local function update(dt: number)
	for player, model in pairs(buddies) do
		if not model.Parent then
			buddies[player] = nil
		else
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				local bob = math.sin(os.clock() * 4 + #player.Name) * 0.4
				local goal = targetPosition(hrp) + Vector3.new(0, bob, 0)
				local current = model:GetPivot().Position
				-- Snap if we somehow got far away (teleport / respawn), else ease.
				local newPos = if (current - goal).Magnitude > 60
					then goal
					else current:Lerp(goal, math.clamp(dt * 8, 0, 1))
				model:PivotTo(CFrame.new(newPos))
			end
		end
	end
end

function BuddyService.init()
	buddyFolder = Instance.new("Folder")
	buddyFolder.Name = "Buddies"
	buddyFolder.Parent = Workspace

	local function spawnFromProfile(player: Player)
		-- The profile loads asynchronously (DataStore) and can lag behind
		-- CharacterAdded, so wait until it's ready — otherwise a returning player's
		-- saved buddy silently won't spawn until they next respawn.
		local deadline = os.clock() + 15
		while not PlayerDataService.isReady(player) and player.Parent ~= nil and os.clock() < deadline do
			task.wait(0.1)
		end
		if player.Parent == nil then
			return
		end
		local profile = PlayerDataService.get(player)
		BuddyService.setBuddy(player, profile and profile.EquippedBuddyId or nil)
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(0.2) -- let the HumanoidRootPart exist
			spawnFromProfile(player)
		end)
		if player.Character then
			task.spawn(spawnFromProfile, player) -- don't block init while waiting for readiness
		end
	end

	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(clearBuddy)

	RunService.Heartbeat:Connect(update)
end

return BuddyService
