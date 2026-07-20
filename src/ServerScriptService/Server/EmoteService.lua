--!strict
-- EmoteService (SERVER)
-- Gives every player a curated, Squishy-renamed emote wheel on each spawn (via
-- HumanoidDescription — the server-authoritative path, so the same registration
-- lets the server auto-play a cheer). All animation ids are built-in Roblox R15
-- defaults, so ZERO uploads / zero moderation risk. An exclusive "Sparkle Dance!"
-- appears only after a player has Restored the Sparkle (the finale).

local Players = game:GetService("Players")

local PlayerDataService = require(script.Parent.PlayerDataService)

local EmoteService = {}

-- Built-in R15 default emote animation ids (free).
local WAVE, POINT, CHEER, LAUGH, DANCE1, DANCE3 = 507770239, 507770453, 507770677, 507770818, 507771019, 507777268

local function buildWheel(restored: boolean)
	local emotes = {
		["Boop Hello!"] = { WAVE },
		["Sparkle Cheer!"] = { CHEER },
		["Giggle!"] = { LAUGH },
		["Happy Dance!"] = { DANCE1 },
		["Point the Way!"] = { POINT },
	}
	local equipped = {
		{ Slot = 1, Name = "Boop Hello!" },
		{ Slot = 2, Name = "Sparkle Cheer!" },
		{ Slot = 3, Name = "Giggle!" },
		{ Slot = 4, Name = "Happy Dance!" },
		{ Slot = 5, Name = "Point the Way!" },
	}
	if restored then
		emotes["Sparkle Dance!"] = { DANCE3 }
		table.insert(equipped, { Slot = 6, Name = "Sparkle Dance!" })
	end
	return emotes, equipped
end

-- Re-apply the wheel onto the current avatar. GetAppliedDescription returns a COPY
-- of the FULL current description, so we only mutate the emote fields — no
-- appearance reload / flicker, and we never strip the avatar.
local function applyTo(player: Player, character: Model)
	local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	local ok, desc = pcall(function()
		return hum:GetAppliedDescription()
	end)
	if not ok or not desc then
		return
	end
	local emotes, equipped = buildWheel(PlayerDataService.isSparkleRestored(player))
	desc:SetEmotes(emotes)
	desc:SetEquippedEmotes(equipped)
	pcall(function()
		hum:ApplyDescription(desc)
	end)
end

-- Re-apply on the current character (after the profile loads / after the finale).
function EmoteService.refresh(player: Player)
	local c = player.Character
	if c then
		task.spawn(applyTo, player, c)
	end
end

function EmoteService.play(player: Player, emoteName: string)
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum:PlayEmote(emoteName)
		end)
	end
end

-- A happy little cheer the server plays on a shard recovery.
function EmoteService.autoCheer(player: Player)
	EmoteService.play(player, "Sparkle Cheer!")
end

-- Restoring the Sparkle unlocks + reveals the exclusive Sparkle Dance.
function EmoteService.onSparkleRestored(player: Player)
	EmoteService.refresh(player) -- registers + equips Sparkle Dance now
	task.delay(0.3, function()
		EmoteService.play(player, "Sparkle Dance!")
	end)
end

function EmoteService.init()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(c)
			task.spawn(applyTo, player, c)
		end)
		if player.Character then
			task.spawn(applyTo, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in ipairs(Players:GetPlayers()) do
		hook(p)
	end
end

return EmoteService
