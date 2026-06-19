-- SparkleBits (CLIENT)
-- Renders the hidden Sparkle Bits the local player hasn't found yet, notices when
-- they walk up to one, asks the server to award it, and plays the cozy "found it!"
-- sparkle. The server is the authority (it validates range + persists); a bit the
-- player has already collected is never rendered, so each player explores their own.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local SparkleBitConfig = require(Shared:WaitForChild("SparkleBitConfig"))
local SoundConfig = require(Shared:WaitForChild("SoundConfig"))

local SparkleBits = {}

local localPlayer = Players.LocalPlayer
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local PICKUP = GameConfig.SparkleBitPickupRadius or 7

local folder: Folder         -- local folder holding the gem visuals
local gems = {}              -- id -> Part (live: visible & collectible)
local pending = {}          -- id -> Part (claim sent, awaiting server confirm)
local collected = {}        -- id -> true (known found; never render)
local synced = false        -- becomes true after the first StateSync
local collectRemote: RemoteEvent
local toastCb: ((string) -> ())?

-- id -> world position, so we can burst at the right spot even after the gem's gone.
local bitPos: { [string]: Vector3 } = {}
for _, b in ipairs(SparkleBitConfig.Bits) do
	bitPos[b.id] = b.position
end

local function setGlow(gem: Part, on: boolean)
	gem.Transparency = on and 0 or 1
	for _, d in ipairs(gem:GetChildren()) do
		if d:IsA("ParticleEmitter") or d:IsA("PointLight") then
			d.Enabled = on
		end
	end
end

local function makeGem(id: string, pos: Vector3): Part
	local gem = Instance.new("Part")
	gem.Name = "SparkleBit_" .. id
	gem.Shape = Enum.PartType.Ball
	gem.Size = Vector3.new(1.7, 1.7, 1.7)
	gem.Material = Enum.Material.Neon
	gem.Color = Color3.fromRGB(255, 233, 140)
	gem.Anchored = true
	gem.CanCollide = false
	gem.CanQuery = false
	gem.CanTouch = false
	gem.CastShadow = false
	gem.Position = pos
	gem.Parent = folder

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 226, 150)
	light.Brightness = 2
	light.Range = 11
	light.Parent = gem

	local em = Instance.new("ParticleEmitter")
	em.Texture = SPARKLE
	em.LightEmission = 1
	em.Color = ColorSequence.new(Color3.fromRGB(255, 245, 200), Color3.fromRGB(255, 210, 170))
	em.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 1.1), NumberSequenceKeypoint.new(1, 0),
	})
	em.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(1, 1),
	})
	em.Lifetime = NumberRange.new(0.8, 1.4)
	em.Rate = 10
	em.Speed = NumberRange.new(1, 3)
	em.SpreadAngle = Vector2.new(180, 180)
	em.Parent = gem

	-- gentle bob + slow spin so it twinkles and catches the eye
	TweenService:Create(gem, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		CFrame = CFrame.new(pos) * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, math.rad(160), 0),
	}):Play()

	return gem
end

local function burstAt(pos: Vector3, big: boolean)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = pos
	anchor.Parent = folder

	local em = Instance.new("ParticleEmitter")
	em.Texture = SPARKLE
	em.LightEmission = 1
	em.Color = ColorSequence.new(Color3.fromRGB(255, 244, 200), Color3.fromRGB(255, 200, 150))
	em.Lifetime = NumberRange.new(0.6, 1.1)
	em.Speed = NumberRange.new(8, 18)
	em.SpreadAngle = Vector2.new(180, 180)
	em.Rotation = NumberRange.new(0, 360)
	em.Size = NumberSequence.new(1.5)
	em.Rate = 0
	em.Parent = anchor
	em:Emit(big and 60 or 28)

	local bitSound = SoundConfig.pick(SoundConfig.SparkleBitVariants) or SoundConfig.HappyPop
	if bitSound and bitSound ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = bitSound
		s.Volume = 0.55
		s.Parent = anchor
		s:Play()
	end

	Debris:AddItem(anchor, 2)
end

-- Ask the server to award this bit. Hide it immediately (optimistic) so we don't
-- spam, but keep the part so we can restore it if the server never confirms.
local function claim(id: string, gem: Part)
	gems[id] = nil
	pending[id] = gem
	setGlow(gem, false)
	collectRemote:FireServer(id)

	-- Safety net: if the server never confirms (e.g. a rare rejected claim), bring
	-- the bit back so it's findable again.
	task.delay(2.5, function()
		local g = pending[id]
		if g and g.Parent and not collected[id] then
			pending[id] = nil
			setGlow(g, true)
			gems[id] = g
		end
	end)
end

local function onCollected(info: any)
	if type(info) ~= "table" or type(info.id) ~= "string" then
		return
	end
	local id = info.id
	collected[id] = true
	local gem = pending[id] or gems[id]
	local pos = (gem and gem.Position) or bitPos[id]
	pending[id] = nil
	gems[id] = nil
	if gem then
		gem:Destroy()
	end
	if pos then
		burstAt(pos, info.all == true)
	end

	if toastCb then
		if info.all then
			toastCb("✨ You found every hidden Sparkle Bit!  +" .. tostring(info.bonus or 0) .. " bonus coins!")
		else
			toastCb("✨ Sparkle Bit found!  (" .. tostring(info.count) .. " / " .. tostring(info.total) .. ")")
		end
	end
end

local function onStep()
	if not synced then
		return
	end
	if not next(gems) then
		return
	end
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local here = root.Position
	for id, gem in pairs(gems) do
		if (gem.Position - here).Magnitude <= PICKUP then
			claim(id, gem)
		end
	end
end

-- Called on every StateSync: forget any bits the server says we've already found.
function SparkleBits.syncCollected(set: any)
	if type(set) == "table" then
		for id in pairs(set) do
			if type(id) == "string" then
				collected[id] = true
				local gem = gems[id] or pending[id]
				if gem then
					gem:Destroy()
				end
				gems[id] = nil
				pending[id] = nil
			end
		end
	end
	synced = true
end

function SparkleBits.init(onToast: ((string) -> ())?)
	toastCb = onToast
	collectRemote = Remotes.get(Remotes.CollectSparkleBit)

	folder = Instance.new("Folder")
	folder.Name = "LocalSparkleBits"
	folder.Parent = Workspace

	for _, b in ipairs(SparkleBitConfig.Bits) do
		if not collected[b.id] then
			gems[b.id] = makeGem(b.id, b.position)
		end
	end

	Remotes.get(Remotes.SparkleBitCollected).OnClientEvent:Connect(onCollected)
	RunService.Heartbeat:Connect(onStep)
end

return SparkleBits
