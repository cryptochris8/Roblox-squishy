-- InviteNudge (CLIENT)
-- Bring-a-friend moments (doc 15 §7.3): the 2026 discovery algorithm MEASURES
-- "Intentional Co-Play Days", so the pro-social peaks — a gift arriving, a
-- group photo — offer a small tappable chip; ONLY a tap opens Roblox's own
-- invite sheet (PromptGameInvite — the platform's consented flow, no free
-- text, respects privacy settings). The sheet never opens itself: an
-- unprompted full-screen takeover is pressure, and the Law doesn't do
-- pressure (review catch). Caps keep it a whisper: each beat offers at most
-- once per session, two chips per session total, auto-fades in 8s, and only
-- appears when the platform says this player can send invites at all.

local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local UiTheme = require(script.Parent.UiTheme)

local InviteNudge = {}

local localPlayer = Players.LocalPlayer
local screen = nil
local activeChip = nil

local askedBeat: { [string]: boolean } = {}
local totalAsks = 0
local MAX_ASKS_PER_SESSION = 2

function InviteNudge.maybe(beatName: string)
	if not screen or totalAsks >= MAX_ASKS_PER_SESSION or askedBeat[beatName] or activeChip then
		return
	end
	askedBeat[beatName] = true
	task.spawn(function()
		local ok, canSend = pcall(function()
			return SocialService:CanSendGameInviteAsync(localPlayer)
		end)
		if not ok or canSend ~= true or activeChip then
			return
		end
		totalAsks += 1

		local chip = UiTheme.panel({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 30),
			Size = UDim2.fromOffset(280, 46),
			BackgroundColor3 = UiTheme.Colors.Panel,
			radius = 23,
		})
		chip.ZIndex = 40
		chip.Parent = screen
		UiTheme.stroke(UiTheme.Colors.Accent, 2, chip)
		activeChip = chip

		local btn = Instance.new("TextButton")
		btn.BackgroundTransparency = 1
		btn.Size = UDim2.fromScale(1, 1)
		btn.Font = UiTheme.HeaderFont
		btn.TextSize = 17
		btn.TextColor3 = UiTheme.Colors.AccentDeep
		btn.Text = "Play together? Invite a friend! 💖"
		btn.ZIndex = 41
		btn.Active = true
		btn.Parent = chip
		btn.Activated:Connect(function()
			chip:Destroy()
			if activeChip == chip then
				activeChip = nil
			end
			pcall(function()
				SocialService:PromptGameInvite(localPlayer)
			end)
		end)

		TweenService:Create(chip, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, 0, 1, -152), -- above the cheer toast's slot
		}):Play()
		task.delay(8, function()
			if chip.Parent then
				TweenService:Create(chip, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 1, 30) }):Play()
				Debris:AddItem(chip, 0.35)
			end
			if activeChip == chip then
				activeChip = nil
			end
		end)
	end)
end

function InviteNudge.mount(playerGui)
	screen = Instance.new("ScreenGui")
	screen.Name = "InviteNudge"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 52
	screen.Parent = playerGui
end

return InviteNudge
