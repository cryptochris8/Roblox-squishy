--!strict
-- FirstDayConfig
-- "My First Day" — the new-player checklist (the Adopt-Me-"Guide" pattern, sized
-- for us): five one-action steps that each pay Sparkle Coins the moment they
-- happen. No claim buttons, no reading required — icons lead, the arrow points.
-- Shared so the server (award logic) and client (panel + world markers) agree.
--
-- Step completion is computed from signals the profile ALREADY tracks, so there
-- is no new bookkeeping — only the paid/unpaid memory per step.

export type Step = {
	id: string,
	icon: string,
	text: string,
	reward: number, -- 0 = another system pays this step (the tutorial's 100)
	marker: string?, -- world-marker target: "sleepy" | "capsule" | "roomdoor"
}

local FirstDayConfig = {}

local steps: { Step } = {
	{ id = "squish1", icon = "👆", text = "Squish a sleepy friend!", reward = 20, marker = "sleepy" },
	{ id = "wake3", icon = "🫧", text = "Wake up 3 friends!", reward = 0, marker = "sleepy" }, -- TutorialService pays its 100
	{ id = "capsule", icon = "🎁", text = "Open your free Sparkle Capsule!", reward = 30, marker = "capsule" },
	{ id = "buddy", icon = "🐾", text = "Pick a buddy in your Squishy Book!", reward = 30 },
	{ id = "room", icon = "🏠", text = "Visit your Squishy Room!", reward = 50, marker = "roomdoor" },
}
FirstDayConfig.Steps = steps

return FirstDayConfig
