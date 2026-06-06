--!strict
-- ThrowService (SERVER)
-- Simulates the thrown football on the server: a real gravity arc, with reliable
-- hit detection done by raycasting along the ball's path every frame (a "swept"
-- ray), so even a fast ball can never tunnel through a target. Because the whole
-- simulation runs on the server, scoring is authoritative -- the client only
-- sends the aim DIRECTION and a POWER (0..1); the server does the physics.

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

-- The slices of the other services that ThrowService needs.
type ScoreServiceLike = {
	addScore: (Player, number) -> (),
}
type TargetServiceLike = {
	-- Returns true if this part WAS a live target (and consumes it).
	consumeTarget: (Instance) -> boolean,
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

local function makeBall(position: Vector3): BasePart
	local ball = Instance.new("Part")
	ball.Name = "Football"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(GameConfig.BallSize, GameConfig.BallSize, GameConfig.BallSize)
	ball.Color = Color3.fromRGB(120, 72, 36)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Anchored = true -- the server moves it by hand each frame (no physics ownership headaches)
	ball.CanCollide = false
	ball.CanQuery = false -- the ball must never show up in its own path ray
	ball.CFrame = CFrame.new(position)
	ball.Parent = ballsFolder
	return ball
end

-- Called by Main once a throw request has been validated (round active, real
-- Vector3 direction, real number power that's been clamped to 0..1).
function ThrowService.throwBall(player: Player, aimDir: Vector3, power: number)
	local character = player.Character
	if not character then
		return -- no character to throw from (e.g. respawning)
	end
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local direction = aimDir.Unit
	local speed = GameConfig.MinThrowSpeed
		+ power * (GameConfig.MaxThrowSpeed - GameConfig.MinThrowSpeed)

	local position = head.Position + direction * 2 -- start just in front of the player
	local velocity = direction * speed
	local ball = makeBall(position)

	-- The ball's path ray ignores the thrower and the balls folder; everything
	-- else (the targets AND the world) can stop the ball.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ballsFolder, character }

	local gravity = Vector3.new(0, -GameConfig.ThrowGravity, 0)
	local elapsed = 0
	local connection: RBXScriptConnection? = nil

	local function stop()
		if connection then
			connection:Disconnect()
		end
		ball:Destroy()
	end

	connection = RunService.Heartbeat:Connect(function(rawDt: number)
		local dt = math.min(rawDt, 0.05) -- never take a giant step after a lag spike
		elapsed += dt
		if elapsed > GameConfig.BallLifetime then
			stop()
			return
		end

		velocity += gravity * dt
		local nextPos = position + velocity * dt

		-- Did the ball's path cross anything between last frame and now?
		local hit = Workspace:Raycast(position, nextPos - position, params)
		if hit then
			-- consumeTarget returns true only if it really was a live target.
			if targetService.consumeTarget(hit.Instance) then
				scoreService.addScore(player, GameConfig.PointsPerHit)
			end
			ball.CFrame = CFrame.new(hit.Position)
			stop() -- target or ground -- either way the throw is finished
			return
		end

		position = nextPos
		ball.CFrame = CFrame.new(position)
	end)
end

return ThrowService
