--!strict
-- Boot.client.lua (REPLICATED FIRST) — the FIRST client code that runs, before
-- anything else replicates. Kills Roblox's default loading bar, raises the
-- storybook loading page, preloads the sounds a kid meets in the first
-- seconds, and holds the page until the server-built world AND the character
-- actually exist — the exact wait that used to look like a broken, empty
-- baseplate on kid tablets (WorldService builds everything at boot, and
-- StreamingEnabled streams it in around the spawn).
--
-- Hard rule: this NEVER traps the player. Every wait has a timeout; the page
-- always lifts (BOOT_TIMEOUT), even if a step fails.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LoadingUi = require(script.Parent:WaitForChild("LoadingUi"))

local BOOT_TIMEOUT = 45 -- absolute ceiling: the page ALWAYS lifts by now
local MIN_SHOW_SECONDS = 4 -- enough to read one tip; never a flash
local SETTLE_SECONDS = 1 -- a beat AFTER ready, so the world never pops in mid-fade

local startedAt = os.clock()
local player = Players.LocalPlayer

ReplicatedFirst:RemoveDefaultLoadingScreen()

local playerGui = player:WaitForChild("PlayerGui")
local screen = LoadingUi.build()
screen.gui.Parent = playerGui
screen.setProgress(0.05, "Opening the storybook…")

-- Preload what the player MEETS immediately: Pudding Hills' music + birds and
-- the squish/pop/signature sounds that fire on the very first boop.
-- Deliberately NOT the whole catalog — first-30-seconds assets only.
local function preloadTargets(): { string }
	local shared = ReplicatedStorage:WaitForChild("Shared", 10)
	if shared == nil then
		return {}
	end
	local soundModule = shared:FindFirstChild("SoundConfig")
	if soundModule == nil or not soundModule:IsA("ModuleScript") then
		return {}
	end
	local ok, SoundConfig = pcall(require, soundModule)
	if not ok or type(SoundConfig) ~= "table" then
		return {}
	end
	local cfg: any = SoundConfig

	local targets: { string } = {}
	local function add(id: any)
		if type(id) == "string" and id ~= "" then
			table.insert(targets, id)
		end
	end
	local function addAll(list: any)
		if type(list) == "table" then
			for _, id in ipairs(list) do
				add(id)
			end
		end
	end
	add(cfg.MusicByZone and cfg.MusicByZone["Pudding Hills"])
	add(cfg.AmbientByZone and cfg.AmbientByZone["Pudding Hills"])
	addAll(cfg.SquishVariants)
	addAll(cfg.HappyPopVariants)
	if type(cfg.SignatureSounds) == "table" then
		for _, pool in pairs(cfg.SignatureSounds) do
			addAll(pool)
		end
	end
	add(cfg.CapsuleReveal)
	return targets
end

-- Preload with a real per-asset progress callback (ContentProvider's callback
-- fires once per asset — that's what drives an honest bar).
local targets = preloadTargets()
if #targets > 0 then
	local done = 0
	local total = #targets
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(targets, function()
				done += 1
				screen.setProgress(0.05 + 0.45 * (done / total), `Warming up the sparkles… {done}/{total}`)
			end)
		end)
	end)
end

-- Wait for the world the server builds at boot (the real wait players felt).
-- Workspace.Squishies is the tell: SquishService parents every friend there
-- once WorldService has finished the lands.
local function waitForWorld(): boolean
	local deadline = startedAt + BOOT_TIMEOUT
	while os.clock() < deadline do
		if Workspace:FindFirstChild("Squishies") ~= nil then
			return true
		end
		task.wait(0.1)
	end
	return false
end

screen.setProgress(0.55, "Fluffing the pudding hills…")
if waitForWorld() then
	screen.setProgress(0.75, "The friends are getting sleepy…")
else
	screen.setProgress(0.75, "Almost there…")
end

-- Then the character: a page that lifts before you have legs feels broken.
local function waitForCharacter()
	local deadline = startedAt + BOOT_TIMEOUT
	while os.clock() < deadline do
		local character = player.Character
		if character ~= nil and character:FindFirstChild("HumanoidRootPart") ~= nil then
			return
		end
		task.wait(0.1)
	end
end
waitForCharacter()
screen.setProgress(0.95, "Ready!")

-- Let the streamed world settle behind the page before revealing it.
task.wait(SETTLE_SECONDS)
-- Never flash: the page always gets its full read-time (one tip minimum).
local elapsed = os.clock() - startedAt
if elapsed < MIN_SHOW_SECONDS then
	task.wait(MIN_SHOW_SECONDS - elapsed)
end
screen.finish()
