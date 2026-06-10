--!strict
-- BoutiqueService (SERVER)
-- The Sparkle Boutique: a cute stall in Pudding Hills where buddies get dressed.
-- Items are bought with EARNED Sparkle Coins only and worn by your buddy for
-- everyone to see. Server-authoritative: this validates every purchase (price,
-- catalog, not-already-owned) and every equip (must be owned). Buying something
-- pops it straight onto your buddy — a six-year-old should never need a second
-- step to enjoy her new hat.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local CosmeticsConfig = require(Shared:WaitForChild("CosmeticsConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local BoutiqueService = {}

-- Set by Main: the player's buddy needs re-dressing (cosmetics changed).
BoutiqueService.onCosmeticsChanged = nil :: ((Player) -> ())?

local toastEvent: RemoteEvent
local openEvent: RemoteEvent

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(p :: any)[key] = value
	end
	return p
end

-- A cozy little market stall: counter, striped awning on poles, and a wobbling
-- bow on top. Sits east of spawn so the walk to the Travel Pads passes it.
local function buildStall(parent: Instance)
	local model = Instance.new("Model")
	model.Name = "SparkleBoutique"
	local base = Vector3.new(26, 0, 28)
	-- face the spawn pad
	local face = CFrame.lookAt(Vector3.new(base.X, 0, base.Z), Vector3.new(0, 0, 34))

	local counter = part({
		Name = "Counter", Size = Vector3.new(10, 3.4, 4),
		Color = Color3.fromRGB(255, 240, 224),
	})
	counter.CFrame = face + Vector3.new(0, 1.7, 0)
	counter.Parent = model
	local counterTop = part({
		Name = "CounterTop", Size = Vector3.new(10.6, 0.5, 4.6),
		Color = Color3.fromRGB(255, 196, 178),
	})
	counterTop.CFrame = face + Vector3.new(0, 3.65, 0)
	counterTop.Parent = model

	-- awning poles + a candy-striped roof (alternating slats)
	for _, sx in ipairs({ -1, 1 }) do
		local pole = part({
			Name = "Pole", Size = Vector3.new(0.6, 7.5, 0.6),
			Color = Color3.fromRGB(244, 230, 214),
		})
		pole.CFrame = face * CFrame.new(sx * 4.8, 0, -0.2) + Vector3.new(0, 3.75, 0)
		pole.Parent = model
	end
	for i = 0, 5 do
		local slat = part({
			Name = "Awning", Size = Vector3.new(1.8, 0.4, 6),
			Color = (i % 2 == 0) and Color3.fromRGB(255, 138, 180) or Color3.fromRGB(255, 247, 240),
		})
		slat.CFrame = face * CFrame.new(-4.5 + i * 1.8, 7.6, -0.6) * CFrame.Angles(math.rad(-12), 0, 0)
		slat.Parent = model
	end

	-- a big soft bow perched on the awning
	local bowMid = part({
		Name = "BowKnot", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4),
		Color = Color3.fromRGB(255, 130, 170),
	})
	bowMid.CFrame = face * CFrame.new(0, 9.1, -1.2)
	bowMid.Parent = model
	for _, sx in ipairs({ -1, 1 }) do
		local loop = part({
			Name = "BowLoop", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 1.7, 1.2),
			Color = Color3.fromRGB(255, 150, 185),
		})
		loop.CFrame = face * CFrame.new(sx * 1.5, 9.2, -1.2) * CFrame.Angles(0, 0, math.rad(sx * 18))
		loop.Parent = model
	end

	-- floating sign
	local gui = Instance.new("BillboardGui")
	gui.Name = "Sign"
	gui.Size = UDim2.fromOffset(220, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Parent = counterTop
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 24
	label.TextColor3 = Color3.fromRGB(225, 90, 150)
	label.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.2
	label.Text = "✨ Sparkle Boutique"
	label.Parent = gui

	-- gentle sparkle so it reads as a magical little shop
	local em = Instance.new("ParticleEmitter")
	em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	em.LightEmission = 0.8
	em.Color = ColorSequence.new(Color3.fromRGB(255, 200, 230), Color3.fromRGB(255, 244, 222))
	em.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(1, 0),
	})
	em.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.3), NumberSequenceKeypoint.new(1, 1),
	})
	em.Lifetime = NumberRange.new(1, 1.8)
	em.Rate = 6
	em.Speed = NumberRange.new(1, 2.5)
	em.SpreadAngle = Vector2.new(180, 180)
	em.Parent = counterTop

	-- the bow breathes a little (fire-and-forget loop)
	TweenService:Create(bowMid, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Size = Vector3.new(1.7, 1.7, 1.7),
	}):Play()

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Sparkle Boutique"
	prompt.ActionText = "Browse"
	prompt.HoldDuration = 0.15
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	model.Parent = parent
	return prompt
end

-- A player asked to buy an item. Validates everything, then auto-wears it.
local function onBuy(player: Player, id: any)
	if type(id) ~= "string" then
		return
	end
	local item = CosmeticsConfig.get(id)
	if not item then
		return
	end
	if PlayerDataService.ownsCosmetic(player, id) then
		toastEvent:FireClient(player, "You already have the " .. item.name .. "! Tap it to wear it.")
		return
	end
	if not PlayerDataService.spendCoins(player, item.price) then
		toastEvent:FireClient(player, "You need " .. item.price .. " Sparkle Coins for the " .. item.name .. " — happy squishing!")
		return
	end
	PlayerDataService.grantCosmetic(player, id)
	PlayerDataService.setEquippedCosmetic(player, item.type, id)
	toastEvent:FireClient(player, item.icon .. " You got the " .. item.name .. "! Your buddy is wearing it!")
	PlayerDataService.sync(player)
	if BoutiqueService.onCosmeticsChanged then
		BoutiqueService.onCosmeticsChanged(player)
	end
end

-- A player asked to wear an owned item (id) or take the slot's item off (nil).
local function onEquip(player: Player, slot: any, id: any)
	if type(slot) ~= "string" then
		return
	end
	if id ~= nil then
		if type(id) ~= "string" then
			return
		end
		local item = CosmeticsConfig.get(id)
		if not item or item.type ~= slot or not PlayerDataService.ownsCosmetic(player, id) then
			return
		end
	end
	PlayerDataService.setEquippedCosmetic(player, slot, id)
	PlayerDataService.sync(player)
	if BoutiqueService.onCosmeticsChanged then
		BoutiqueService.onCosmeticsChanged(player)
	end
end

function BoutiqueService.init()
	toastEvent = Remotes.get(Remotes.Toast)
	openEvent = Remotes.get(Remotes.OpenBoutique)
	Remotes.get(Remotes.BuyCosmetic).OnServerEvent:Connect(onBuy)
	Remotes.get(Remotes.EquipCosmetic).OnServerEvent:Connect(onEquip)

	-- Build the stall once Pudding Hills exists; browsing just opens the client shop.
	task.spawn(function()
		local home = Workspace:WaitForChild("PuddingHills", 30) or Workspace
		local prompt = buildStall(home)
		prompt.Triggered:Connect(function(player)
			openEvent:FireClient(player)
		end)
	end)
end

return BoutiqueService
