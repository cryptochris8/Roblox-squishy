-- StoryPagesUI (CLIENT)
-- Renders the local player's unfound storybook pages (floating golden
-- parchments), notices the walk-up, asks the server to award, and shows the
-- page viewer — also openable anytime from the 📖 Storybook button to leaf
-- through everything found so far. Server validates + persists.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local StoryPageConfig = require(Shared:WaitForChild("StoryPageConfig"))
local StoryPageAssets = require(Shared:WaitForChild("StoryPageAssets"))
local SoundConfig = require(Shared:WaitForChild("SoundConfig"))
local UiTheme = require(script.Parent.UiTheme)
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local StoryPagesUI = {}

local localPlayer = Players.LocalPlayer
local PICKUP = 7

local folder: Folder
local parchments: { [string]: Model } = {}
local pending: { [string]: Model } = {}
local found: { [string]: boolean } = {}
local synced = false
local collectRemote: RemoteEvent

-- viewer state
local overlay, pageImage, pageLabel, captionLabel, prevBtn, nextBtn
local viewIndex = 1

local function makeParchment(id: string, pos: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "StoryPage_" .. id
	local sheet = Instance.new("Part")
	sheet.Name = "Sheet"
	sheet.Size = Vector3.new(2.6, 3.4, 0.25)
	sheet.Color = Color3.fromRGB(255, 246, 222)
	sheet.Material = Enum.Material.SmoothPlastic
	sheet.Anchored = true
	sheet.CanCollide = false
	sheet.CanQuery = false
	sheet.CanTouch = false
	sheet.CastShadow = false
	sheet.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(25), math.rad(6))
	sheet.Parent = m
	m.PrimaryPart = sheet
	local stripe = Instance.new("Part")
	stripe.Size = Vector3.new(2.2, 0.5, 0.27)
	stripe.Color = Color3.fromRGB(240, 160, 40)
	stripe.Material = Enum.Material.SmoothPlastic
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.CanQuery = false
	stripe.CastShadow = false
	stripe.CFrame = sheet.CFrame * CFrame.new(0, -1.1, -0.02)
	stripe.Parent = m
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 226, 150)
	glow.Brightness = 1.4
	glow.Range = 12
	glow.Parent = sheet
	local em = Instance.new("ParticleEmitter")
	em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	em.LightEmission = 1
	em.Color = ColorSequence.new(Color3.fromRGB(255, 236, 180))
	em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 0) })
	em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.25), NumberSequenceKeypoint.new(1, 1) })
	em.Lifetime = NumberRange.new(0.8, 1.4)
	em.Rate = 7
	em.Speed = NumberRange.new(0.8, 2)
	em.SpreadAngle = Vector2.new(180, 180)
	em.Parent = sheet
	TweenService:Create(sheet, TweenInfo.new(1.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		CFrame = sheet.CFrame * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, math.rad(140), 0),
	}):Play()
	m.Parent = folder
	return m
end

local function destroyPage(id: string)
	local m = parchments[id] or pending[id]
	parchments[id] = nil
	pending[id] = nil
	if m then
		m:Destroy()
	end
end

-- ── The viewer ──────────────────────────────────────────────────────────────

local function pageAsset(n: number): string?
	local id = (StoryPageAssets :: any)[string.format("page_%02d", n)]
	if type(id) == "number" and id > 0 then
		return string.format("rbxassetid://%d", id)
	end
	return nil
end

local function renderViewer()
	local page = StoryPageConfig.Pages[viewIndex]
	if not page then
		return
	end
	local owned = found[page.id] == true
	local asset = owned and pageAsset(page.n) or nil
	pageImage.Image = asset or ""
	pageImage.BackgroundColor3 = owned and Color3.fromRGB(255, 250, 240) or Color3.fromRGB(214, 204, 196)
	pageLabel.Text = owned and ("Page " .. page.n .. " of " .. StoryPageConfig.count())
		or ("Page " .. page.n .. " — still hidden out there...")
	captionLabel.Text = owned and page.caption or "🔍"
	prevBtn.Visible = viewIndex > 1
	nextBtn.Visible = viewIndex < StoryPageConfig.count()
end

local function buildViewer(playerGui)
	local screen = Instance.new("ScreenGui")
	screen.Name = "SquishyStorybook"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 36
	screen.Parent = playerGui

	overlay = Instance.new("TextButton")
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = UiTheme.Colors.Shade
	overlay.BackgroundTransparency = 0.4
	overlay.AutoButtonColor = false
	overlay.Text = ""
	overlay.Visible = false
	overlay.Parent = screen
	overlay.Activated:Connect(function()
		overlay.Visible = false
	end)

	-- sized for the SQUARE book pages (story text is typeset on the art, so
	-- the page gets nearly the whole panel)
	local panel = UiTheme.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(540, 510),
		BackgroundColor3 = UiTheme.Colors.Cream,
		radius = 20,
	})
	panel.Active = true
	panel.Parent = overlay
	UiTheme.stroke(UiTheme.Colors.CoinDeep, 3, panel)
	UiTheme.autoFit(panel, 540, 510)

	pageImage = Instance.new("ImageLabel")
	pageImage.AnchorPoint = Vector2.new(0.5, 0)
	pageImage.Position = UDim2.new(0.5, 0, 0, 14)
	pageImage.Size = UDim2.fromOffset(440, 440)
	pageImage.BorderSizePixel = 0
	pageImage.ScaleType = Enum.ScaleType.Fit
	pageImage.Parent = panel
	UiTheme.corner(12, pageImage)

	pageLabel = Instance.new("TextLabel")
	pageLabel.BackgroundTransparency = 1
	pageLabel.Position = UDim2.fromOffset(24, 462)
	pageLabel.Size = UDim2.new(1, -48, 0, 26)
	pageLabel.Font = UiTheme.HeaderFont
	pageLabel.TextSize = 19
	pageLabel.TextColor3 = UiTheme.Colors.CoinDeep
	pageLabel.Text = ""
	pageLabel.Parent = panel

	captionLabel = Instance.new("TextLabel")
	captionLabel.BackgroundTransparency = 1
	captionLabel.Position = UDim2.fromOffset(24, 484)
	captionLabel.Size = UDim2.new(1, -48, 0, 22)
	captionLabel.Font = UiTheme.BodyFont
	captionLabel.TextSize = 13
	captionLabel.TextWrapped = true
	captionLabel.TextColor3 = UiTheme.Colors.Ink
	captionLabel.Text = ""
	captionLabel.Parent = panel

	local function navBtn(text, anchor, x)
		local b = Instance.new("TextButton")
		b.AnchorPoint = anchor
		b.Position = UDim2.new(x, anchor.X == 1 and -14 or 14, 0.5, -60)
		b.Size = UDim2.fromOffset(44, 44)
		b.BackgroundColor3 = UiTheme.Colors.AccentDeep
		b.BorderSizePixel = 0
		b.Font = UiTheme.HeaderFont
		b.TextSize = 22
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Text = text
		b.Parent = panel
		UiTheme.corner(22, b)
		return b
	end
	prevBtn = navBtn("‹", Vector2.new(0, 0.5), 0)
	nextBtn = navBtn("›", Vector2.new(1, 0.5), 1)
	prevBtn.Activated:Connect(function()
		viewIndex = math.max(1, viewIndex - 1)
		renderViewer()
	end)
	nextBtn.Activated:Connect(function()
		viewIndex = math.min(StoryPageConfig.count(), viewIndex + 1)
		renderViewer()
	end)
end

function StoryPagesUI.show(atIndex: number?)
	if atIndex then
		viewIndex = atIndex
	end
	renderViewer()
	overlay.Visible = true
end

-- ── Pickup flow ─────────────────────────────────────────────────────────────

local function claim(id: string)
	local m = parchments[id]
	parchments[id] = nil
	pending[id] = m
	collectRemote:FireServer(id)
	task.delay(2.5, function()
		local back = pending[id]
		if back and back.Parent and not found[id] then
			pending[id] = nil
			parchments[id] = back
		end
	end)
end

local function onStep()
	if not synced or not next(parchments) then
		return
	end
	local char = localPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local here = root.Position
	for id, m in pairs(parchments) do
		local sheet = m.PrimaryPart
		if sheet and (sheet.Position - here).Magnitude <= PICKUP then
			claim(id)
		end
	end
end

function StoryPagesUI.syncCollected(set: any)
	if type(set) == "table" then
		for id in pairs(set) do
			if type(id) == "string" then
				found[id] = true
				destroyPage(id)
			end
		end
	end
	synced = true
end

function StoryPagesUI.mount(playerGui, onToast)
	collectRemote = Remotes.get(Remotes.CollectStoryPage)
	folder = Instance.new("Folder")
	folder.Name = "LocalStoryPages"
	folder.Parent = Workspace
	buildViewer(playerGui)

	for _, page in ipairs(StoryPageConfig.Pages) do
		if not found[page.id] then
			parchments[page.id] = makeParchment(page.id, page.position)
		end
	end

	Remotes.get(Remotes.StoryPageCollected).OnClientEvent:Connect(function(info)
		if type(info) ~= "table" or type(info.id) ~= "string" then
			return
		end
		found[info.id] = true
		destroyPage(info.id)
		local pageSound = Instance.new("Sound")
		pageSound.SoundId = (info.all and SoundConfig.ShardRecovered) or SoundConfig.StoryPage
		pageSound.Volume = 0.6
		pageSound.Parent = SoundService
		pageSound:Play()
		Debris:AddItem(pageSound, 5)
		if onToast then
			if info.all then
				onToast("📖 You found EVERY page of The Lost Sparkle!  +" .. tostring(info.bonus) .. " bonus coins!")
			else
				onToast("📖 Storybook page found!  (" .. tostring(info.count) .. " / " .. tostring(info.total) .. ")  +" .. tostring(info.coins) .. " coins")
			end
		end
		StoryPagesUI.show(info.n)
	end)
	RunService.Heartbeat:Connect(onStep)
end

return StoryPagesUI
