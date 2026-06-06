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
GameConfig.PointsPerHit = 1 -- points for one successful throw (temporary stand-in)

return GameConfig
