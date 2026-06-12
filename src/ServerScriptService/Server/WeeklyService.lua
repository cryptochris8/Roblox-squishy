--!strict
-- WeeklyService (SERVER)
-- The Friend of the Week: one of the 8 special event friends visits a cozy
-- striped tent by the Pudding Hills travel hub, rotating every UTC week. Talk to
-- them and befriend them for a KNOWN Sparkle Coin price (never random) — they
-- join the Book's Events tab and can be your buddy like anyone else.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local SquishyData = require(Shared:WaitForChild("SquishyData"))
local WeeklyConfig = require(Shared:WaitForChild("WeeklyConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)
local SquishyModelFactory = require(script.Parent.SquishyModelFactory)
local DailyService = require(script.Parent.DailyService)

local WeeklyService = {}

local toastEvent: RemoteEvent
local capsuleResultEvent: RemoteEvent

local tentFolder: Folder? = nil
local visitorModel: Model? = nil
local signLabel: TextLabel? = nil
local currentWeek = -1
local currentDef: any = nil

local TENT_POS = Vector3.new(-49, 0, 75) -- on the village path, west side (spread with the village)

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

-- The week's visitor, by card-number order over the event roster.
local function defForWeek(week: number)
	local roster = SquishyData.getEventRoster()
	if #roster == 0 then
		return nil
	end
	return roster[(week % #roster) + 1]
end

local function daysLeftText(): string
	local days = math.max(1, math.ceil(WeeklyConfig.secondsLeft() / 86400))
	return days == 1 and "last day!" or (days .. " days left")
end

-- Build the cozy visiting tent once (the visitor + sign refresh weekly).
local function buildTent(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "VisitingFriendTent"

	local face = CFrame.lookAt(Vector3.new(TENT_POS.X, 0, TENT_POS.Z), Vector3.new(0, 0, 34))

	-- two slanted candy-striped roof slats over a soft back wall
	for i, sx in ipairs({ -1, 1 }) do
		for s = 0, 3 do
			local slat = part({
				Name = "TentRoof", Size = Vector3.new(2.1, 0.4, 7.5),
				Color = ((s + i) % 2 == 0) and Color3.fromRGB(255, 200, 120) or Color3.fromRGB(255, 247, 240),
			})
			slat.CFrame = face * CFrame.new(sx * (1.1 + s * 0.95), 6.2 - s * 0.62, -1.4) * CFrame.Angles(0, 0, math.rad(sx * -38))
			slat.Parent = folder
		end
	end
	local back = part({
		Name = "TentBack", Size = Vector3.new(9.4, 6.4, 0.6),
		Color = Color3.fromRGB(255, 232, 200),
	})
	back.CFrame = face * CFrame.new(0, 3.2, -4.4)
	back.Parent = folder
	for _, sx in ipairs({ -1, 1 }) do
		local pole = part({
			Name = "TentPole", Size = Vector3.new(0.55, 6.6, 0.55),
			Color = Color3.fromRGB(206, 170, 120),
		})
		pole.CFrame = face * CFrame.new(sx * 4.5, 3.3, 1.6)
		pole.Parent = folder
	end
	-- a soft rug for the visitor to sit on
	local rug = part({
		Name = "TentRug", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 9, 9),
		Color = Color3.fromRGB(255, 214, 170), CanCollide = false,
	})
	rug.CFrame = face * CFrame.new(0, 0.16, 0.5) * CFrame.Angles(0, 0, math.rad(90))
	rug.Parent = folder

	-- the floating sign (label text refreshes with the rotation)
	local signGui = Instance.new("BillboardGui")
	signGui.Name = "VisitorSign"
	signGui.Size = UDim2.fromOffset(250, 52)
	signGui.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	signGui.AlwaysOnTop = true
	signGui.MaxDistance = 70
	signGui.Parent = back
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextSize = 20
	lbl.TextWrapped = true
	lbl.TextColor3 = Color3.fromRGB(240, 160, 40)
	lbl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.2
	lbl.Text = "⭐ Visiting Friend"
	lbl.Parent = signGui
	signLabel = lbl

	-- gentle sparkle so the tent reads as special
	local em = Instance.new("ParticleEmitter")
	em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	em.LightEmission = 0.8
	em.Color = ColorSequence.new(Color3.fromRGB(255, 226, 150), Color3.fromRGB(255, 244, 222))
	em.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(1, 0),
	})
	em.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.3), NumberSequenceKeypoint.new(1, 1),
	})
	em.Lifetime = NumberRange.new(1, 1.8)
	em.Rate = 5
	em.Speed = NumberRange.new(1, 2.5)
	em.SpreadAngle = Vector2.new(180, 180)
	em.Parent = back

	folder.Parent = parent
	tentFolder = folder
end

-- Swap in this week's visitor (model + prompt + sign text).
local function refreshVisitor()
	local week = WeeklyConfig.weekIndex()
	if week == currentWeek and visitorModel and visitorModel.Parent then
		-- same week: just keep the countdown fresh
		if signLabel and currentDef then
			signLabel.Text = "⭐ " .. currentDef.DisplayName .. " is visiting!  (" .. daysLeftText() .. ")"
		end
		return
	end
	currentWeek = week
	currentDef = defForWeek(week)
	if not (currentDef and tentFolder) then
		return
	end

	if visitorModel then
		visitorModel:Destroy()
	end
	local model = SquishyModelFactory.build(currentDef)
	model.Name = "Visitor_" .. currentDef.Id
	local face = CFrame.lookAt(Vector3.new(TENT_POS.X, 0, TENT_POS.Z), Vector3.new(0, 0, 34))
	-- mesh-body contract: the pivot's -Z is the BACK, so a lookAt toward the
	-- spawn needs a 180 flip or card-mesh visitors would greet kids with the
	-- back of their head
	model:PivotTo(face * CFrame.new(0, 2, 0.8) * CFrame.Angles(0, math.rad(180), 0))
	model.Parent = tentFolder
	visitorModel = model

	-- ProximityPrompts need a BasePart parent (a Model won't render the prompt).
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = currentDef.DisplayName
	prompt.ActionText = "Befriend (" .. WeeklyConfig.Cost .. " coins)"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	prompt.Triggered:Connect(function(player)
		WeeklyService.tryBefriend(player)
	end)

	if signLabel then
		signLabel.Text = "⭐ " .. currentDef.DisplayName .. " is visiting!  (" .. daysLeftText() .. ")"
	end
end

function WeeklyService.tryBefriend(player: Player)
	local def = currentDef
	if not def or not PlayerDataService.isReady(player) then
		return
	end
	if PlayerDataService.hasDiscovered(player, def.Id) then
		toastEvent:FireClient(player, def.DisplayName .. " is already your friend! A new visitor arrives in " .. daysLeftText() .. ".")
		return
	end
	if not PlayerDataService.spendCoins(player, WeeklyConfig.Cost) then
		toastEvent:FireClient(player, "Befriending " .. def.DisplayName .. " takes " .. WeeklyConfig.Cost .. " Sparkle Coins — keep squishing, you'll get there!")
		return
	end
	PlayerDataService.discoverCard(player, def.Id)
	DailyService.noteEvent(player, "discover")

	-- the full card-reveal celebration (the same one capsules play)
	capsuleResultEvent:FireClient(player, {
		defId = def.Id,
		displayName = def.DisplayName,
		cardNumber = def.CardNumber,
		rarity = def.Rarity,
		imageAssetId = def.ImageAssetId,
		isNew = true,
		bonusCoins = 0,
		wasFree = false,
		variantLevel = 0,
		variantUpgraded = false,
	})
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			toastEvent:FireClient(other, "⭐ " .. player.DisplayName .. " befriended " .. def.DisplayName .. ", the visiting friend!")
		end
	end
	PlayerDataService.sync(player)
end

function WeeklyService.init()
	toastEvent = Remotes.get(Remotes.Toast)
	capsuleResultEvent = Remotes.get(Remotes.CapsuleResult)

	task.spawn(function()
		local home = Workspace:WaitForChild("PuddingHills", 30) or Workspace
		buildTent(home)
		refreshVisitor()
		-- keep the countdown honest + roll the visitor over at the week boundary
		while true do
			task.wait(60)
			refreshVisitor()
		end
	end)
end

return WeeklyService
