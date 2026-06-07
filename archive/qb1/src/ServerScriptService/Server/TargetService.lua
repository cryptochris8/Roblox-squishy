--!strict
-- TargetService (SERVER)
-- Spawns the glowing targets you throw at -- in a ring around the play area so
-- they're visible whichever way you face -- and handles what happens when one is
-- hit. The server owns the targets, which is what lets ThrowService's hit test
-- be authoritative (un-fakeable).

local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local TargetService = {}

local targetsFolder: Folder
local active: { [BasePart]: boolean } = {} -- the targets that are currently live
local roundLive = false

-- A world position on the ring at the given angle, with a random float height.
local function positionForAngle(angle: number): Vector3
	local height = GameConfig.TargetHeightMin
		+ math.random() * (GameConfig.TargetHeightMax - GameConfig.TargetHeightMin)
	return Vector3.new(
		math.cos(angle) * GameConfig.TargetRadius,
		height,
		math.sin(angle) * GameConfig.TargetRadius
	)
end

local function createTarget(angle: number)
	local target = Instance.new("Part")
	target.Name = "Target"
	target.Shape = Enum.PartType.Ball
	target.Size = Vector3.new(GameConfig.TargetSize, GameConfig.TargetSize, GameConfig.TargetSize)
	target.Color = Color3.fromRGB(255, 170, 40)
	target.Material = Enum.Material.Neon
	target.Anchored = true
	target.CanCollide = false -- players pass through; the ball's path ray still hits it
	target.Position = positionForAngle(angle)
	target.Parent = targetsFolder
	active[target] = true
end

-- Create the Workspace folder once at server startup.
function TargetService.init()
	targetsFolder = Instance.new("Folder")
	targetsFolder.Name = "Targets"
	targetsFolder.Parent = Workspace
end

-- Spawn a fresh ring of targets (called when a round goes Active).
function TargetService.spawnTargets()
	TargetService.clearTargets()
	roundLive = true
	for i = 1, GameConfig.TargetCount do
		local angle = (i / GameConfig.TargetCount) * math.pi * 2
		createTarget(angle)
	end
end

-- Remove every target (called when a round ends).
function TargetService.clearTargets()
	roundLive = false
	for part in pairs(active) do
		active[part] = nil
	end
	if targetsFolder then
		targetsFolder:ClearAllChildren()
	end
end

-- Try to "score" a part. Returns true only if it really was a live target; in
-- that case we flash it green, remove it, and -- if the round is still going --
-- pop a replacement somewhere new so there's always something to aim at.
-- Returning a bool lets ThrowService award points and consume the target in one
-- atomic step, so a target can never be scored twice.
function TargetService.consumeTarget(part: Instance): boolean
	local target = part :: BasePart
	if not active[target] then
		return false
	end
	active[target] = nil
	target.Color = Color3.fromRGB(120, 255, 120)
	Debris:AddItem(target, 0.06)

	task.delay(GameConfig.TargetRespawnDelay, function()
		if roundLive then
			createTarget(math.random() * math.pi * 2)
		end
	end)
	return true
end

return TargetService
