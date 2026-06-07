--!strict
-- TutorialService (SERVER)
-- The first cozy quest: Soft Dumpling asks the player to wake up a few sleepy
-- friends. After enough Happy Pops the player gets a pile of Sparkle Coins and a
-- nudge toward their first (free) Sparkle Capsule.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local TutorialService = {}

local toastEvent: RemoteEvent

-- Called by SquishService on every Happy Pop.
function TutorialService.notePop(player: Player, _def: any)
	local profile = PlayerDataService.get(player)
	if not profile or profile.TutorialDone then
		return
	end

	if profile.TotalHappyPops >= GameConfig.TutorialPopGoal then
		PlayerDataService.setTutorialDone(player)
		PlayerDataService.addCoins(player, GameConfig.TutorialRewardCoins)
		toastEvent:FireClient(
			player,
			"You woke up " .. GameConfig.TutorialPopGoal .. " sleepy friends! +"
				.. GameConfig.TutorialRewardCoins .. " Sparkle Coins. Try the Sparkle Capsule!"
		)
		PlayerDataService.sync(player)
	else
		local left = GameConfig.TutorialPopGoal - profile.TotalHappyPops
		toastEvent:FireClient(
			player,
			"Yay! " .. left .. " more sleepy friend" .. (left == 1 and "" or "s") .. " to wake up!"
		)
	end
end

function TutorialService.welcome(player: Player)
	local profile = PlayerDataService.get(player)
	if profile and profile.TutorialDone then
		toastEvent:FireClient(player, "Welcome back to Pudding Hills! Squish friends and open Sparkle Capsules!")
	else
		toastEvent:FireClient(
			player,
			"Welcome to Pudding Hills! Squish the sleepy friends to wake them up — wake up "
				.. GameConfig.TutorialPopGoal .. "!"
		)
	end
end

function TutorialService.init()
	toastEvent = Remotes.get(Remotes.Toast)
end

return TutorialService
