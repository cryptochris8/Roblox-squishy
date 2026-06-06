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

-- Throwing (the football you throw)
GameConfig.ThrowRange = 500 -- how far a throw can reach, in studs
GameConfig.ThrowSpeed = 120 -- how fast the visual ball flies, studs/sec
GameConfig.BallSize = 1.4   -- diameter of the football

-- Targets (what you throw at)
GameConfig.TargetCount = 6        -- how many targets are out at once
GameConfig.TargetSize = 4         -- diameter of each target
GameConfig.TargetRespawnDelay = 1 -- seconds before a hit target reappears
GameConfig.TargetRadius = 26      -- distance of the target ring from the center
GameConfig.TargetHeightMin = 6    -- lowest a target can float
GameConfig.TargetHeightMax = 16   -- highest a target can float

return GameConfig
