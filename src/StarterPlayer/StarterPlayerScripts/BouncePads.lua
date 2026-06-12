-- BouncePads (CLIENT)
-- Applies bounce launches for the LOCAL character. The character is always
-- client-owned, so velocity writes and humanoid state changes only stick
-- when made here (the server's job is detection juice: squash, sparkles,
-- and the Bounce Bog's "together" bonus window, which it publishes via
-- attributes). Pads are tagged SquishyBouncy and carry:
--   BounceVelocity (Vector3)  — the launch, in world space
--   PartyUntil (number?)      — server time; while now < this, use PartyVelocity
--   PartyVelocity (Vector3?)  — the boosted together-launch

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local BouncePads = {}

local localPlayer = Players.LocalPlayer
local lastBounce = 0

local function onTouched(pad: BasePart, hit: BasePart)
	local char = localPlayer.Character
	if not char or hit.Parent ~= char then
		return
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	if now - lastBounce < 0.45 then
		return
	end
	lastBounce = now

	local velocity = pad:GetAttribute("BounceVelocity")
	if typeof(velocity) ~= "Vector3" then
		return
	end
	local partyUntil = pad:GetAttribute("PartyUntil")
	local partyVelocity = pad:GetAttribute("PartyVelocity")
	if typeof(partyUntil) == "number" and typeof(partyVelocity) == "Vector3"
		and workspace:GetServerTimeNow() < partyUntil then
		velocity = partyVelocity
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	root.AssemblyLinearVelocity = velocity :: Vector3
end

local function hookPad(pad: Instance)
	if pad:IsA("BasePart") then
		pad.Touched:Connect(function(hit)
			onTouched(pad, hit)
		end)
	end
end

function BouncePads.init()
	for _, pad in ipairs(CollectionService:GetTagged("SquishyBouncy")) do
		hookPad(pad)
	end
	-- streamed-in pads arrive later under StreamingEnabled
	CollectionService:GetInstanceAddedSignal("SquishyBouncy"):Connect(hookPad)
end

return BouncePads
