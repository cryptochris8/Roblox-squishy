-- CapsuleTrail (CLIENT)
-- The D1 funnel fix (doc 15 §7.3): the moment the tutorial completes, the
-- Pudding Hills Sparkle Capsule starts visibly CALLING — a soft light beam and
-- a breadcrumb trail of ground sparkles from the player toward the capsule —
-- until the first capsule is opened. A six-year-old doesn't read toasts; she
-- follows sparkles. Pure invitation: no timer, no arrow yelling, no nag —
-- and it never appears again once the first capsule is open.
--
-- Client-local rendering only (the capsule sits near spawn, so StreamingEnabled
-- always has it). Driven by StateSync (tutorial.done + tutorial.firstCapsuleClaimed)
-- and stopped early by the first CapsuleResult.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local CapsuleTrail = {}

local localPlayer = Players.LocalPlayer

local active = false
local starting = false
local beamPart: Part? = nil
local trailThread: thread? = nil

local BEAM_COLOR = Color3.fromRGB(255, 170, 200)
local SPARKLE_IMAGE = "rbxasset://textures/particles/sparkles_main.dds"

local function capsulePosition(): Vector3?
	local land = Workspace:FindFirstChild("PuddingHills")
	local model = land and land:FindFirstChild("SparkleCapsule")
	local base = model and model:FindFirstChild("Base")
	if base and base:IsA("BasePart") then
		return base.Position
	end
	return nil
end

local function stopNow()
	active = false
	if beamPart then
		beamPart:Destroy()
		beamPart = nil
	end
	trailThread = nil
end

local function startTrail()
	if active or starting then
		return
	end
	starting = true
	task.spawn(function()
		-- the land streams in around spawn; give it a moment on a cold join
		local pos: Vector3? = nil
		for _ = 1, 20 do
			pos = capsulePosition()
			if pos then
				break
			end
			task.wait(0.5)
		end
		starting = false
		if not pos or active then
			return
		end
		active = true

		-- The gentle calling beam over the capsule (client-local, breathing).
		local beam = Instance.new("Part")
		beam.Name = "CapsuleCallBeam"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.Material = Enum.Material.Neon
		beam.Color = BEAM_COLOR
		beam.Transparency = 0.55
		beam.Shape = Enum.PartType.Cylinder
		beam.Size = Vector3.new(40, 2.2, 2.2)
		beam.CFrame = CFrame.new(pos + Vector3.new(0, 24, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beam.Parent = Workspace
		beamPart = beam
		task.spawn(function()
			while active and beam.Parent do
				local t = TweenService:Create(beam, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Transparency = 0.8,
				})
				t:Play()
				t.Completed:Wait()
				if not (active and beam.Parent) then
					break
				end
				local back = TweenService:Create(beam, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					Transparency = 0.55,
				})
				back:Play()
				back.Completed:Wait()
			end
		end)

		-- Breadcrumbs: a few ground sparkles stepping from the player toward the
		-- capsule, refreshed every couple of seconds from wherever she is now.
		trailThread = task.spawn(function()
			while active do
				local char = localPlayer.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp and pos then
					local from = (hrp :: BasePart).Position
					local dist = (pos - from).Magnitude
					if dist > 10 then
						local steps = math.min(6, math.floor(dist / 8))
						for i = 1, steps do
							if not active then
								break
							end
							local at = from:Lerp(pos, i / (steps + 1))
							local crumb = Instance.new("Part")
							crumb.Anchored = true
							crumb.CanCollide = false
							crumb.CanQuery = false
							crumb.CanTouch = false
							crumb.Transparency = 1
							crumb.Size = Vector3.new(0.5, 0.5, 0.5)
							crumb.Position = Vector3.new(at.X, 0.6, at.Z)
							crumb.Parent = Workspace
							local gui = Instance.new("BillboardGui")
							gui.Size = UDim2.fromOffset(26, 26)
							gui.AlwaysOnTop = false
							gui.Parent = crumb
							local img = Instance.new("ImageLabel")
							img.BackgroundTransparency = 1
							img.Size = UDim2.fromScale(1, 1)
							img.Image = SPARKLE_IMAGE
							img.ImageColor3 = BEAM_COLOR
							img.Parent = gui
							TweenService:Create(img, TweenInfo.new(1.8, Enum.EasingStyle.Quad), {
								ImageTransparency = 1,
							}):Play()
							Debris:AddItem(crumb, 2)
							task.wait(0.12)
						end
					end
				end
				task.wait(2.2)
			end
		end)
	end)
end

-- Driven from StateSync: call on every snapshot.
function CapsuleTrail.update(state)
	local tut = state and state.tutorial
	if tut and tut.done == true and tut.firstCapsuleClaimed ~= true then
		startTrail()
	elseif active then
		stopNow()
	end
end

-- The first reveal ends the calling immediately (snappier than the next sync).
function CapsuleTrail.onCapsuleOpened()
	if active then
		stopNow()
	end
end

return CapsuleTrail
