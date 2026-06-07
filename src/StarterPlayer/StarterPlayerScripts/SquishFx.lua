-- SquishFx
-- Plays the squishy "feel" on the friends in the world: a wobble/squash when
-- squished, a Joy Meter that fills, and a sparkly Happy Pop when they wake up.
-- Driven entirely by the server's SquishResult events (the server stays the
-- authority; the client just makes it feel good).

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SquishyData = require(Shared:WaitForChild("SquishyData"))
local UiTheme = require(script.Parent.UiTheme)

local SquishFx = {}

local localPlayer = Players.LocalPlayer
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local BASE_SIZE = Vector3.new(4, 4, 4)

local entries = {} -- objectId -> { body, fill, zzz }

local function buildBillboard(body, def)
	local gui = Instance.new("BillboardGui")
	gui.Name = "SquishyLabel"
	gui.Size = UDim2.fromOffset(150, 54)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 70
	gui.Parent = body

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 24)
	name.Font = UiTheme.HeaderFont
	name.TextSize = 18
	name.TextColor3 = Color3.fromRGB(110, 80, 110)
	name.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	name.TextStrokeTransparency = 0.2
	name.Text = (def and def.DisplayName) or "Squishy Friend"
	name.Parent = gui

	local barBg = Instance.new("Frame")
	barBg.Size = UDim2.new(1, -20, 0, 12)
	barBg.Position = UDim2.new(0, 10, 0, 32)
	barBg.BackgroundColor3 = Color3.fromRGB(240, 225, 235)
	barBg.BorderSizePixel = 0
	barBg.Parent = gui
	UiTheme.corner(6, barBg)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = UiTheme.Colors.Accent
	fill.BorderSizePixel = 0
	fill.Parent = barBg
	UiTheme.corner(6, fill)

	local zzz = Instance.new("TextLabel")
	zzz.Name = "Zzz"
	zzz.BackgroundTransparency = 1
	zzz.Size = UDim2.fromScale(1, 1)
	zzz.Font = UiTheme.HeaderFont
	zzz.TextSize = 13
	zzz.TextColor3 = Color3.fromRGB(150, 150, 200)
	zzz.Text = "z Z z"
	zzz.Parent = barBg

	return fill, zzz
end

local function register(model)
	if not model:IsA("Model") then
		return
	end
	local objectId = model:GetAttribute("ObjectId")
	if type(objectId) ~= "string" then
		return
	end
	local body = model:FindFirstChild("Body") or model.PrimaryPart
	if not body then
		return
	end
	local def = SquishyData.getById(model:GetAttribute("DefId"))
	local fill, zzz = buildBillboard(body, def)
	entries[objectId] = { body = body, fill = fill, zzz = zzz }
end

local function squash(body)
	if not body or not body.Parent then
		return
	end
	local t1 = TweenService:Create(body, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(4.9, 2.9, 4.9),
	})
	t1.Completed:Connect(function()
		if body and body.Parent then
			TweenService:Create(body, TweenInfo.new(0.28, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Size = BASE_SIZE,
			}):Play()
		end
	end)
	t1:Play()
end

local function sparkle(body, count, color)
	if not body or not body.Parent then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.5, 0.9)
	emitter.Speed = NumberRange.new(6, 15)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Size = NumberSequence.new(1.4)
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(255, 232, 180))
	emitter.LightEmission = 0.6
	emitter.Parent = body
	emitter:Emit(count)
	Debris:AddItem(emitter, 1)
end

local function pop(body)
	if not body or not body.Parent then
		return
	end
	TweenService:Create(body, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.new(6.5, 6.5, 6.5),
		Transparency = 1,
	}):Play()
end

local function floatingCoins(body, coins)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(130, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = body
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.Font = UiTheme.HeaderFont
	lbl.TextSize = 26
	lbl.TextColor3 = UiTheme.Colors.CoinDeep
	lbl.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.1
	lbl.Text = "+" .. coins
	lbl.Parent = gui
	TweenService:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, 9, 0),
	}):Play()
	TweenService:Create(lbl, TweenInfo.new(0.9), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Debris:AddItem(gui, 1)
end

function SquishFx.handle(result)
	local entry = entries[result.objectId]
	if not entry then
		return
	end
	local body = entry.body
	if entry.fill then
		entry.fill.Size = UDim2.new(math.clamp(result.joy or 0, 0, 1), 0, 1, 0)
	end
	if entry.zzz then
		entry.zzz.Visible = false
	end

	squash(body)

	if result.popped then
		local def = SquishyData.getById(result.defId)
		local color = def and UiTheme.rarityColor(def.Rarity) or nil
		sparkle(body, 26, color)
		pop(body)
		if result.byUserId == localPlayer.UserId and result.coins then
			floatingCoins(body, result.coins)
		end
		entries[result.objectId] = nil
	else
		sparkle(body, 6, Color3.fromRGB(255, 240, 205))
	end
end

function SquishFx.init()
	local folder = Workspace:WaitForChild("Squishies")
	for _, model in ipairs(folder:GetChildren()) do
		register(model)
	end
	folder.ChildAdded:Connect(function(model)
		task.defer(register, model)
	end)
	folder.ChildRemoved:Connect(function(model)
		local id = model:GetAttribute("ObjectId")
		if type(id) == "string" then
			entries[id] = nil
		end
	end)
end

return SquishFx
