--!strict
-- ThrowService (SERVER)
-- Turns a validated throw request into two things:
--   1. an AUTHORITATIVE hit test -- a server raycast that can only hit the
--      server's own targets, so a hit cannot be faked by the client, and
--   2. a cosmetic football that slides from the player to the impact point.
-- The client only tells us the DIRECTION it aimed; the server does the geometry.

local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

-- The slices of the other services that ThrowService needs.
type ScoreServiceLike = {
	addScore: (Player, number) -> (),
}
type TargetServiceLike = {
	getFolder: () -> Folder,
	isLiveTarget: (Instance) -> boolean,
	handleHit: (Instance) -> (),
}

local ThrowService = {}

local scoreService: ScoreServiceLike
local targetService: TargetServiceLike
local ballsFolder: Folder

function ThrowService.init(deps: { score: ScoreServiceLike, targets: TargetServiceLike })
	scoreService = deps.score
	targetService = deps.targets
	ballsFolder = Instance.new("Folder")
	ballsFolder.Name = "Balls"
	ballsFolder.Parent = Workspace
end

-- Cosmetic only: a brown ball that glides from the hand to the impact point.
-- It's anchored and CanQuery=false so it never blocks players or aim rays.
local function spawnVisualBall(fromPos: Vector3, toPos: Vector3)
	local ball = Instance.new("Part")
	ball.Name = "Football"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(GameConfig.BallSize, GameConfig.BallSize, GameConfig.BallSize)
	ball.Color = Color3.fromRGB(120, 72, 36)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CFrame = CFrame.new(fromPos)
	ball.Parent = ballsFolder

	local travelTime = math.clamp((toPos - fromPos).Magnitude / GameConfig.ThrowSpeed, 0.05, 0.6)
	TweenService:Create(ball, TweenInfo.new(travelTime, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(toPos),
	}):Play()
	Debris:AddItem(ball, travelTime + 0.1)
end

-- Called by Main once a throw request has been validated (round active, real
-- Vector3, off cooldown).
function ThrowService.throwBall(player: Player, aimPoint: Vector3)
	local character = player.Character
	if not character then
		return -- no character to throw from (e.g. respawning)
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local origin = head.Position
	local toAim = aimPoint - origin
	if toAim.Magnitude < 1 then
		return -- aim point basically on top of us; ignore
	end
	local direction = toAim.Unit

	-- Authoritative hit test: this ray can ONLY intersect live targets.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { targetService.getFolder() }
	local hit = Workspace:Raycast(origin, direction * GameConfig.ThrowRange, params)

	-- Where the visual ball should end up: the target we hit, or just along the
	-- aim direction if we missed.
	local endPoint = origin + direction * math.min(toAim.Magnitude, GameConfig.ThrowRange)
	if hit then
		endPoint = hit.Position
		if targetService.isLiveTarget(hit.Instance) then
			scoreService.addScore(player, GameConfig.PointsPerHit)
			targetService.handleHit(hit.Instance)
		end
	end

	spawnVisualBall(origin, endPoint)
end

return ThrowService
