-- PhotoSpots (CLIENT)
-- The kid-facing half of the Sparkle Photo Spots. When the server says "your
-- group is standing in a photo frame" (a PhotoMoment remote), everyone in the
-- group counts down together against ONE shared server clock — 3… 2… 1… say
-- sparkle! — then hops and cheers, a little confetti pops, and (on phones) the
-- shot is saved to the camera roll. No pressure, nothing is lost if you miss it:
-- it's a joyful "get ready to smile" cue, and the frame just re-arms afterward.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")

local UiTheme = require(script.Parent.UiTheme)

local PhotoSpots = {}

local localPlayer = Players.LocalPlayer
local screen: ScreenGui? = nil
local banner: TextLabel? = nil
local running = false

-- Gentle FX budget: half on phones, half again in Calm Sparkles mode.
local function fxScalar(): number
	local s = UiTheme.isCompact() and 0.5 or 1
	if localPlayer:GetAttribute("CalmSparkles") == true then
		s *= 0.5
	end
	return s
end

-- Briefly hide every other on-screen panel so the screenshot is just the world
-- (mirrors PhotoMode's HUD-hide), then restore exactly what we hid.
local function withHudHidden(seconds: number)
	local pg = localPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return
	end
	-- We only restore GUIs we hid AND still "own": if anything else toggles a
	-- GUI's Enabled during the window (PhotoMode's own exit button, or a kid
	-- closing a panel), we relinquish it so our restore can't resurrect a stale
	-- control. (Two uncoordinated HUD-hide owners would otherwise clobber.)
	local owned: { [ScreenGui]: RBXScriptConnection } = {}
	for _, g in ipairs(pg:GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled and g ~= screen then
			g.Enabled = false -- set BEFORE we listen, so our own change isn't caught
			owned[g] = g:GetPropertyChangedSignal("Enabled"):Connect(function()
				local conn = owned[g]
				owned[g] = nil
				if conn then
					conn:Disconnect()
				end
			end)
		end
	end
	task.delay(seconds, function()
		for g, conn in pairs(owned) do
			conn:Disconnect()
			owned[g] = nil
			if g.Parent then
				g.Enabled = true
			end
		end
	end)
end

local function confettiBurst(root: BasePart?)
	if not root or not root.Parent then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds" -- same as SquishFx
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.7, 1.2)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Size = NumberSequence.new(1.2)
	emitter.LightEmission = 0.5
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 196, 212), Color3.fromRGB(170, 200, 255))
	emitter.Parent = root
	emitter:Emit(math.floor(36 * fxScalar() + 0.5))
	Debris:AddItem(emitter, 1.4)
end

-- On phones the shot can save straight to the camera roll; desktop has no
-- gallery API, so we just nudge them to grab a screenshot (best-effort, never
-- blocks the cheer).
local function screenshotNudge()
	-- clear the game chrome so the shot is just the world + this happy moment
	-- (our own "say sparkle!" banner is kept; withHudHidden restores the rest)
	withHudHidden(2.2)
	if UserInputService.TouchEnabled then
		task.wait(0.15) -- let the HUD-hide render before we grab the frame
		local ok = pcall(function()
			local CaptureService = game:GetService("CaptureService")
			CaptureService:CaptureScreenshot(function(captureId)
				pcall(function()
					CaptureService:PromptSaveCapturesToGallery({ captureId }, function() end)
				end)
			end)
		end)
		if banner then
			banner.Text = ok and "📸 Say sparkle! ✨" or "📸 Say sparkle!"
		end
	elseif banner then
		banner.Text = "📸 Say sparkle! (grab a screenshot!)"
	end
end

function PhotoSpots.play(info)
	if running or not banner or not screen then
		return
	end
	if type(info) ~= "table" or type(info.at) ~= "number" then
		return
	end
	running = true
	screen.Enabled = true
	banner.TextColor3 = UiTheme.Colors.AccentDeep

	-- 1) synchronized 3-2-1 against the SHARED server clock every occupant holds
	local started = os.clock()
	while true do
		local left = info.at - workspace:GetServerTimeNow()
		if left <= 0 or os.clock() - started > 8 then -- safety cap vs clock skew
			break
		end
		banner.Text = "📸 " .. tostring(math.ceil(math.min(left, 3)))
		task.wait(0.1)
	end

	-- 2) the moment: cheer on MY OWN character (client owns it → replicates)
	banner.Text = "📸 Say sparkle!"
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum:PlayEmote("cheer")
		end)
		hum.Jump = true -- the always-works happy hop
	end

	-- 3) a little confetti (within the FX budget) + the screenshot nudge
	confettiBurst(char and char.PrimaryPart)
	screenshotNudge()

	task.delay(2.6, function()
		if screen then
			screen.Enabled = false
		end
		running = false
	end)
end

function PhotoSpots.mount(playerGui: Instance)
	screen = Instance.new("ScreenGui")
	screen.Name = "SquishyPhotoSpots"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 40
	screen.Enabled = false
	screen.Parent = playerGui

	local compact = UiTheme.isCompact()
	banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.24)
	banner.Size = compact and UDim2.fromScale(0.8, 0.12) or UDim2.fromOffset(560, 90)
	banner.BackgroundColor3 = UiTheme.Colors.Cream
	banner.BackgroundTransparency = 0.1
	banner.Font = UiTheme.HeaderFont
	banner.TextScaled = compact
	banner.TextSize = 46
	banner.TextColor3 = UiTheme.Colors.AccentDeep
	banner.Text = "📸"
	banner.Parent = screen
	UiTheme.corner(24, banner)
	UiTheme.stroke(UiTheme.Colors.Accent, 3, banner)
end

return PhotoSpots
