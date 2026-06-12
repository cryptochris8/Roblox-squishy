--!strict
-- CoasterConfig
-- The Sparkle Express: a gentle scenic train that circles the rim of Pudding
-- Hills — past the gate, behind the cherry mountains, through the windmill
-- gap, and along the village edge. Tuned for ages 4-9: a journey, not a
-- thrill ride. Shared so a client-side smoothing pass can someday evaluate
-- the very same path the server drives.

local CoasterConfig = {}

-- Hand-laid rim loop (land-local to Pudding Hills, y = track height).
-- The loop hugs an inset of ~135 studs and bows INWARD around the three
-- cherry pudding mountains, threading the gap between the windmill and the
-- south-west mountain — the scenic highlight of the lap.
CoasterConfig.Waypoints = {
	Vector3.new(10, 6, 138), -- 1: the station (south rim, on the path from spawn)
	Vector3.new(70, 7, 130),
	Vector3.new(112, 8, 108),
	Vector3.new(134, 9, 70),
	Vector3.new(138, 10, 20), -- past the Goo Coast gate
	Vector3.new(136, 12, -30),
	Vector3.new(122, 14, -78), -- bowing inward around the eastern mountain
	Vector3.new(104, 16, -112),
	Vector3.new(56, 17, -134), -- the high point of the lap (north rim)
	Vector3.new(4, 15, -138),
	Vector3.new(-44, 12, -122), -- the windmill needle
	Vector3.new(-88, 13, -124), -- sliding past the south-west mountain
	Vector3.new(-118, 14, -88),
	Vector3.new(-120, 11, -52), -- inside the western mountain
	Vector3.new(-132, 8, -8),
	Vector3.new(-138, 6, 40),
	Vector3.new(-126, 5, 92), -- along the village edge
	Vector3.new(-88, 4, 122),
	Vector3.new(-36, 5, 134),
}

-- Motion (kid-gentle: research says cruise 14-20, accel <= 8, bank <= 12 deg)
CoasterConfig.CruiseSpeed = 16 -- studs/sec (walking speed — scenic)
CoasterConfig.Accel = 6 -- studs/sec^2
CoasterConfig.MaxBank = math.rad(10)
CoasterConfig.LookAhead = 3 -- studs of arc length for orientation

-- Train
CoasterConfig.Cars = 3
CoasterConfig.CarSpacing = 9 -- studs between car pivots (car body ~7 long)

-- Station rhythm
CoasterConfig.DwellSeconds = 14 -- doors-open pause at the station
CoasterConfig.LapsPerRide = 2 -- everyone hops off after this many laps

-- Track build
CoasterConfig.BoardSpacing = 5 -- one ribbon board every N studs of arc
CoasterConfig.SupportSpacing = 28 -- one support post every N studs

return CoasterConfig
