-- SparkleBitService (SERVER)
-- Hidden Sparkle Bits reward exploring Pudding Hills. The CLIENT renders the bits
-- the player hasn't found yet and notices when they walk up to one; the SERVER is
-- the authority for the award: it checks the bit is real, not already collected,
-- and that the player's character is genuinely near it, then grants Sparkle Coins
-- (plus a bonus for finding them all) and persists it on the profile.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local SparkleBitConfig = require(Shared:WaitForChild("SparkleBitConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local SparkleBitService = {}

local collectedEvent: RemoteEvent
local total = SparkleBitConfig.count()

-- id -> world position, for the range check.
local bitPos: { [string]: Vector3 } = {}
for _, b in ipairs(SparkleBitConfig.Bits) do
	bitPos[b.id] = b.position
end

local function onCollect(player: Player, id: any)
	if type(id) ~= "string" then
		return
	end
	local pos = bitPos[id]
	if not pos then
		return
	end
	if not PlayerDataService.isReady(player) then
		return
	end
	if PlayerDataService.hasSparkleBit(player, id) then
		return
	end

	-- Range sanity (anti-cheat-lite): the character must actually be near the bit.
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	if (root.Position - pos).Magnitude > GameConfig.SparkleBitClaimRange then
		return
	end

	local newly, count = PlayerDataService.collectSparkleBit(player, id)
	if not newly then
		return
	end

	PlayerDataService.addCoins(player, GameConfig.SparkleBitCoins)
	local all = count >= total
	local bonus = 0
	if all then
		bonus = GameConfig.SparkleBitAllBonus
		PlayerDataService.addCoins(player, bonus)
	end

	collectedEvent:FireClient(player, {
		id = id,
		count = count,
		total = total,
		coins = GameConfig.SparkleBitCoins,
		all = all,
		bonus = bonus,
	})
	PlayerDataService.sync(player)
	if SparkleBitService.onCollected then
		SparkleBitService.onCollected(player, all)
	end
end

function SparkleBitService.init()
	collectedEvent = Remotes.get(Remotes.SparkleBitCollected)
	local collect = Remotes.get(Remotes.CollectSparkleBit)
	collect.OnServerEvent:Connect(onCollect)
end

return SparkleBitService
