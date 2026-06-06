--!strict
-- GameConfig
-- Central place for tunable numbers. Change values HERE instead of hunting
-- through the game code. Both the server and the client can read this module.

local GameConfig = {}

-- Round timing (in seconds)
GameConfig.IntermissionDuration = 10 -- waiting time between rounds
GameConfig.RoundDuration = 60        -- how long an active round lasts
GameConfig.EndScreenDuration = 5     -- how long the "round over" state shows

-- Scoring
GameConfig.PointsPerHit = 1    -- points for hitting one target
GameConfig.ThrowCooldown = 0.3 -- min seconds between throws (server anti-spam)

-- Throwing (a real football with a gravity arc and adjustable power)
GameConfig.MinThrowSpeed = 55  -- launch speed at the lightest tap (studs/sec)
GameConfig.MaxThrowSpeed = 150 -- launch speed at full charge (studs/sec)
GameConfig.ThrowGravity = 110  -- downward pull on the ball (studs/sec^2); higher = more arc
GameConfig.BallLifetime = 5    -- seconds before a thrown ball gives up and despawns
GameConfig.BallSize = 1.4      -- diameter of the football
GameConfig.MaxChargeTime = 1.0 -- seconds of holding to reach full power
GameConfig.MinPowerFrac = 0.15 -- even a quick tap throws with at least this much power

-- Targets (what you throw at)
GameConfig.TargetCount = 6        -- how many targets are out at once
GameConfig.TargetSize = 4         -- diameter of each target
GameConfig.TargetRespawnDelay = 1 -- seconds before a hit target reappears
GameConfig.TargetRadius = 26      -- distance of the target ring from the center
GameConfig.TargetHeightMin = 6    -- lowest a target can float
GameConfig.TargetHeightMax = 16   -- highest a target can float

return GameConfig
