-- PhotoSpotService (SERVER)
-- Sparkle Photo Spots: each land has a picture frame with glowing stand-pads
-- (tagged "PhotoPad" by WorldService.buildPhotoFrame). When 2+ players are
-- standing in one frame, the server names that group and ONE shared "GO" time,
-- then fires a PhotoMoment to each of them. Their CLIENTS run the synchronized
-- 3-2-1 "say sparkle!" cheer + confetti + screenshot nudge (the client owns its
-- character, so the cheer is performed client-side and replicates to everyone).
-- There is NO reward and NO client->server remote, so it's pile-on / stranger-
-- safe by construction: the worst anyone can do is trigger a free group cheer.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local PhotoSpotService = {}

local PAD_R = 5      -- how close to a pad centre counts as "standing on it" (X/Z)
local PAD_Y = 8      -- generous vertical window (pads are CanCollide off)
local MIN = 2        -- players needed to trigger a group photo
local LEAD = 3.2     -- seconds of 3-2-1 countdown before "say sparkle!"
local COOLDOWN = 25  -- per-frame re-arm so one frame can't spam moments
local TICK = 0.4     -- occupancy-scan cadence

type Frame = { pads: { BasePart }, land: string, cdUntil: number }

local frames: { [string]: Frame } = {}
local photoMoment: RemoteEvent

-- Collect the tagged PhotoPad parts into per-frame buckets. Called once at init
-- (the pads are built by WorldService.build() before init runs).
local function gatherFrames()
	for _, pad in ipairs(CollectionService:GetTagged("PhotoPad")) do
		if pad:IsA("BasePart") then
			local id = pad:GetAttribute("PhotoFrameId")
			if typeof(id) == "string" then
				local f = frames[id]
				if not f then
					f = { pads = {}, land = pad:GetAttribute("Land") or "", cdUntil = 0 }
					frames[id] = f
				end
				table.insert(f.pads, pad)
			end
		end
	end
end

local function occupantsOf(f: Frame): { Player }
	local occ = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char.PrimaryPart
		if root then
			local pos = root.Position
			for _, pad in ipairs(f.pads) do
				local d = pos - pad.Position
				if math.abs(d.X) < PAD_R and math.abs(d.Z) < PAD_R and math.abs(d.Y) < PAD_Y then
					occ[#occ + 1] = player
					break
				end
			end
		end
	end
	return occ
end

-- Name one group + one shared server-clock "GO" time and hand it to each of them.
local function fireMoment(frameId: string, land: string, players: { Player })
	local at = workspace:GetServerTimeNow() + LEAD
	local ids = {}
	for _, p in ipairs(players) do
		ids[#ids + 1] = p.UserId
	end
	for _, p in ipairs(players) do
		photoMoment:FireClient(p, { frameId = frameId, land = land, at = at, occupants = ids })
	end
end

-- OWNER DEBUG: fire a solo photo moment so it's testable with one player in
-- Studio (a real moment needs 2+ characters standing together).
function PhotoSpotService.debugSolo(player: Player, frameId: string)
	local f = frames[frameId]
	fireMoment(frameId, f and f.land or "Pudding Hills", { player })
end

function PhotoSpotService.init()
	photoMoment = Remotes.get(Remotes.PhotoMoment)
	gatherFrames()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TICK then
			return
		end
		acc = 0
		local now = os.clock()
		for id, f in pairs(frames) do
			if now >= f.cdUntil then
				local occ = occupantsOf(f)
				if #occ >= MIN then
					f.cdUntil = now + COOLDOWN
					fireMoment(id, f.land, occ)
				end
			end
		end
	end)
end

return PhotoSpotService
