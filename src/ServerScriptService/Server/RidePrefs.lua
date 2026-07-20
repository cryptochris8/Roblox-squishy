--!strict
-- RidePrefs (SERVER)
-- The "Faster Rides" toggle. A kid can flip a switch (in Today's Quests, next to
-- Calm Sparkles) to make every ride they're on go faster — a fun but still-gentle
-- 1.5x for the playful rides, and a milder 1.3x for the deliberately-gentle
-- coaster + ferris wheel (they carry lots of little ones, so we keep those kind).
-- Session-scoped (resets on rejoin, like Calm Sparkles). Ride services call
-- RidePrefs.speedFor(rider) / .maxSpeedFor(riders) to scale their motion.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local RidePrefs = {}

local FAST = 1.5        -- playful rides (swings, slides, teacups, zip, river...)
local FAST_GENTLE = 1.3 -- shared, motion-sensitive rides (coaster, ferris wheel)

local fast: { [Player]: boolean } = {}

-- Resolve a rider — a Player, a Humanoid (a Seat.Occupant), or a character Model —
-- to its Player.
function RidePrefs.playerOf(rider: any): Player?
	if typeof(rider) ~= "Instance" then
		return nil
	end
	if rider:IsA("Player") then
		return rider
	end
	local char = if rider:IsA("Humanoid") then rider.Parent else rider
	if char and char:IsA("Model") then
		return Players:GetPlayerFromCharacter(char)
	end
	return nil
end

function RidePrefs.wantsFast(rider: any): boolean
	local player = RidePrefs.playerOf(rider)
	return player ~= nil and fast[player] == true
end

-- Speed multiplier for one rider (1.0 normally, 1.5 if they've turned it on).
function RidePrefs.speedFor(rider: any): number
	return if RidePrefs.wantsFast(rider) then FAST else 1
end

-- The milder multiplier, for the coaster / ferris wheel.
function RidePrefs.speedForGentle(rider: any): number
	return if RidePrefs.wantsFast(rider) then FAST_GENTLE else 1
end

-- The highest multiplier among a set of riders — for SHARED rides (one motion,
-- many riders), so it goes fast if ANYONE aboard wants it. `riders` may contain
-- Players, Humanoids, or nils (skipped).
function RidePrefs.maxSpeedFor(riders: { any }, gentle: boolean?): number
	local best = 1
	-- pairs (not ipairs) so a nil hole in the middle doesn't cut the scan short —
	-- honors the "nils skipped" contract for any future sparse-array caller.
	for _, r in pairs(riders) do
		if r then
			local m = if gentle then RidePrefs.speedForGentle(r) else RidePrefs.speedFor(r)
			if m > best then
				best = m
			end
		end
	end
	return best
end

function RidePrefs.init()
	Remotes.get(Remotes.SetRidePref).OnServerEvent:Connect(function(player, value)
		fast[player] = value == true
	end)
	Players.PlayerRemoving:Connect(function(player)
		fast[player] = nil
	end)
end

return RidePrefs
