-- SoundScape (CLIENT)
-- Each land has its own music and its own nature: ukulele + songbirds in
-- Pudding Hills, lazy calypso + ocean waves on Goo Coast, a music box +
-- crickets in Moonlit Hollow. This watches where the local character is
-- (lands sit at x = 0 / 600 / 1200) and gently crossfades both layers when
-- they travel — the audio version of the lands feeling truly different.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundConfig"))

local SoundScape = {}

local localPlayer = Players.LocalPlayer
local FADE_SECONDS = 2.5

local function zoneForX(x: number): string
	if x < 300 then
		return "Pudding Hills"
	elseif x < 900 then
		return "Goo Coast"
	end
	return "Moonlit Hollow"
end

-- one fading dual-layer channel (music or ambient)
local function makeChannel(name: string, idsByZone: { [string]: string }, volume: number)
	local sounds: { [string]: Sound } = {}
	for zone, id in pairs(idsByZone) do
		local s = Instance.new("Sound")
		s.Name = name .. "_" .. zone
		s.SoundId = id
		s.Looped = true
		s.Volume = 0
		s.Parent = SoundService
		sounds[zone] = s
	end
	local current: string? = nil
	return function(zone: string)
		if zone == current then
			return
		end
		current = zone
		for z, s in pairs(sounds) do
			local target = if z == zone then volume else 0
			if target > 0 and not s.IsPlaying then
				s:Play()
			end
			local tween = TweenService:Create(s, TweenInfo.new(FADE_SECONDS, Enum.EasingStyle.Sine), { Volume = target })
			tween.Completed:Connect(function()
				if s.Volume <= 0.01 and s.IsPlaying then
					s:Stop() -- don't keep silent tracks decoding
				end
			end)
			tween:Play()
		end
	end
end

function SoundScape.init()
	local setMusic = makeChannel("Music", SoundConfig.MusicByZone, SoundConfig.MusicVolume)
	local setAmbient = makeChannel("Ambient", SoundConfig.AmbientByZone, SoundConfig.AmbientVolume)

	task.spawn(function()
		while true do
			local char = localPlayer.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root then
				local zone = zoneForX((root :: BasePart).Position.X)
				setMusic(zone)
				setAmbient(zone)
			end
			task.wait(1.5)
		end
	end)
end

return SoundScape
