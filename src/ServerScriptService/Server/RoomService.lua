--!strict
-- RoomService (SERVER)
-- The Squishy Room: every player's own cozy room, decorated with furniture
-- bought with EARNED Sparkle Coins. Rooms are instanced per player far below
-- the lands; a glowing door near the Pudding Hills spawn takes you home, and a
-- door inside brings you back. Decorating is kid-simple: walk to a marked spot
-- ("slot"), pick what goes there from a little catalog, done. The server
-- validates everything (price, ownership, slot/item kind match) and persists
-- the layout on the profile.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local RoomConfig = require(Shared:WaitForChild("RoomConfig"))

local PlayerDataService = require(script.Parent.PlayerDataService)

local RoomService = {}

-- Set by Main: someone visited their room (the First Day list celebrates it).
RoomService.onVisited = nil :: ((Player) -> ())?

local toastEvent: RemoteEvent
local openCatalogEvent: RemoteEvent

local roomsFolder: Folder
-- player -> { index, folder, slotProps: {[slotId]: Folder}, entryCF: CFrame? }
local rooms: { [Player]: any } = {}
local usedIndices: { [number]: boolean } = {}

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

local C = Color3.fromRGB

-- ── Furniture builders (one per item id; soft part-built pieces) ────────────
-- Each gets (folder, baseCF, item) where baseCF sits ON the floor at the slot.

local function buildRug(folder, baseCF, item)
	local rug = part({ Name = "Rug", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22, 11, 11), Color = item.color, CanCollide = false })
	rug.CFrame = baseCF * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90))
	rug.Parent = folder
	if item.id == "rug_rainbow" then
		for i, col in ipairs({ C(255, 170, 170), C(255, 220, 150), C(170, 230, 180), C(170, 190, 255) }) do
			local ring = part({ Name = "Ring", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.24, 11 - i * 2.2, 11 - i * 2.2), Color = col, CanCollide = false })
			ring.CFrame = baseCF * CFrame.new(0, 0.13 + i * 0.01, 0) * CFrame.Angles(0, 0, math.rad(90))
			ring.Parent = folder
		end
	elseif item.id == "rug_cloud" then
		for _, off in ipairs({ Vector3.new(-3.4, 0, 1.4), Vector3.new(3.2, 0, -1.2), Vector3.new(0.4, 0, 3.4) }) do
			local puff = part({ Name = "Puff", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 5.5, 5.5), Color = item.color, CanCollide = false })
			puff.CFrame = baseCF * CFrame.new(off.X, 0.11, off.Z) * CFrame.Angles(0, 0, math.rad(90))
			puff.Parent = folder
		end
	end
end

local function buildBed(folder, baseCF, item)
	local base = part({ Name = "BedBase", Size = Vector3.new(7, 1.6, 10), Color = C(230, 200, 170) })
	base.CFrame = baseCF * CFrame.new(0, 0.8, 0)
	base.Parent = folder
	local mattress = part({ Name = "Mattress", Size = Vector3.new(6.4, 1.2, 9.2), Color = item.color2 or C(255, 250, 240) })
	mattress.CFrame = baseCF * CFrame.new(0, 2.1, 0)
	mattress.Parent = folder
	local blanket = part({ Name = "Blanket", Size = Vector3.new(6.5, 0.5, 5.4), Color = item.color })
	blanket.CFrame = baseCF * CFrame.new(0, 2.85, 1.7)
	blanket.Parent = folder
	local pillow = part({ Name = "Pillow", Shape = Enum.PartType.Ball, Size = Vector3.new(3.2, 1.4, 2.2), Color = C(255, 252, 246), CanCollide = false })
	pillow.CFrame = baseCF * CFrame.new(0, 3, -3.4)
	pillow.Parent = folder
	if item.id == "bed_cloud" then
		for _, sx in ipairs({ -1, 1 }) do
			local puff = part({ Name = "CloudPuff", Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 1.8, 2.6), Color = C(245, 248, 255), CanCollide = false })
			puff.CFrame = baseCF * CFrame.new(sx * 3.4, 1.4, 3.6)
			puff.Parent = folder
		end
	end
end

local function buildTable(folder, baseCF, item)
	local top = part({ Name = "TableTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 6.5, 6.5), Color = item.color })
	top.CFrame = baseCF * CFrame.new(0, 2.8, 0) * CFrame.Angles(0, 0, math.rad(90))
	top.Parent = folder
	local leg = part({ Name = "TableLeg", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.6, 1.2, 1.2), Color = C(206, 170, 120) })
	leg.CFrame = baseCF * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90))
	leg.Parent = folder
	if item.id == "table_tea" then
		local pot = part({ Name = "Teapot", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.3, 1.6), Color = C(190, 226, 255), CanCollide = false })
		pot.CFrame = baseCF * CFrame.new(0, 3.9, 0)
		pot.Parent = folder
	else
		local cake = part({ Name = "Cupcake", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.5, 1.4), Color = C(255, 170, 190), CanCollide = false })
		cake.CFrame = baseCF * CFrame.new(0, 4, 0)
		cake.Parent = folder
	end
end

local function buildLamp(folder, baseCF, item)
	local pole = part({ Name = "LampPole", Size = Vector3.new(0.5, 5, 0.5), Color = C(244, 230, 214) })
	pole.CFrame = baseCF * CFrame.new(0, 2.5, 0)
	pole.Parent = folder
	local shadeShape = item.id == "lamp_mushroom" and Vector3.new(3.2, 1.9, 3.2) or Vector3.new(2.2, 2.2, 2.2)
	local shade = part({ Name = "LampShade", Shape = Enum.PartType.Ball, Size = shadeShape, Color = item.color, Material = Enum.Material.Neon, CanCollide = false })
	shade.CFrame = baseCF * CFrame.new(0, 5.4, 0)
	shade.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = item.color
	light.Brightness = 0.7
	light.Range = 14
	light.Parent = shade
end

local function buildPlant(folder, baseCF, item)
	local pot = part({ Name = "Pot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6, 2.4, 2.4), Color = C(220, 160, 130) })
	pot.CFrame = baseCF * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90))
	pot.Parent = folder
	if item.id == "plant_sprout" then
		local stem = part({ Name = "Stem", Size = Vector3.new(0.4, 2.4, 0.4), Color = item.color, CanCollide = false })
		stem.CFrame = baseCF * CFrame.new(0, 2.6, 0)
		stem.Parent = folder
		for _, sx in ipairs({ -1, 1 }) do
			local leaf = part({ Name = "Leaf", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 0.7, 0.9), Color = item.color, CanCollide = false })
			leaf.CFrame = baseCF * CFrame.new(sx * 0.8, 3.6, 0) * CFrame.Angles(0, 0, math.rad(sx * 24))
			leaf.Parent = folder
		end
	else
		for i, off in ipairs({ Vector3.new(-0.6, 0, 0.2), Vector3.new(0.6, 0, -0.2), Vector3.new(0, 0, 0.5) }) do
			local stem = part({ Name = "Stem" .. i, Size = Vector3.new(0.25, 2.2, 0.25), Color = C(150, 208, 130), CanCollide = false })
			stem.CFrame = baseCF * CFrame.new(off.X, 2.4, off.Z)
			stem.Parent = folder
			local head = part({ Name = "Tulip" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 1.1, 0.9), Color = item.color, CanCollide = false })
			head.CFrame = baseCF * CFrame.new(off.X, 3.7, off.Z)
			head.Parent = folder
		end
	end
end

local function buildWall(folder, baseCF, item)
	if item.id == "wall_star_garland" then
		for i = 0, 4 do
			local star = part({ Name = "GarlandStar", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 0.4), Color = item.color, Material = Enum.Material.Neon, CanCollide = false })
			star.CFrame = baseCF * CFrame.new((i - 2) * 2.6, math.abs(i - 2) * -0.7 + 1.4, 0)
			star.Parent = folder
		end
	else
		local frame = part({ Name = "Frame", Size = Vector3.new(5.4, 4.2, 0.4), Color = item.color, CanCollide = false })
		frame.CFrame = baseCF
		frame.Parent = folder
		local canvas = part({ Name = "Canvas", Size = Vector3.new(4.6, 3.4, 0.45), Color = C(255, 214, 224), CanCollide = false })
		canvas.CFrame = baseCF
		canvas.Parent = folder
		local face = part({ Name = "FriendFace", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 0.5), Color = C(255, 238, 214), CanCollide = false })
		face.CFrame = baseCF * CFrame.new(0, 0, -0.05)
		face.Parent = folder
	end
end

local function buildWindow(folder, baseCF, item)
	local frame = part({ Name = "WindowFrame", Size = Vector3.new(0.5, 5.2, 6.4), Color = C(244, 230, 214), CanCollide = false })
	frame.CFrame = baseCF
	frame.Parent = folder
	local isMoon = item.id == "window_moon"
	local glass = part({
		Name = "WindowGlass", Size = Vector3.new(0.55, 4.4, 5.6),
		Color = item.color, Material = Enum.Material.Neon, Transparency = 0.25, CanCollide = false,
	})
	glass.CFrame = baseCF
	glass.Parent = folder
	local orb = part({
		Name = isMoon and "Moon" or "Sun", Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.6, 1.7, 1.7), Color = isMoon and C(240, 240, 255) or C(255, 226, 130),
		Material = Enum.Material.Neon, CanCollide = false,
	})
	orb.CFrame = baseCF * CFrame.new(-0.06, 0.9, -1.3)
	orb.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = isMoon and C(200, 200, 255) or C(255, 236, 180)
	light.Brightness = 1.2
	light.Range = 14
	light.Parent = glass
end

local BUILDERS: { [string]: (Instance, CFrame, any) -> () } = {
	rug = buildRug, bed = buildBed, table = buildTable,
	lamp = buildLamp, plant = buildPlant, wall = buildWall, window = buildWindow,
}

-- ── The room shell ──────────────────────────────────────────────────────────

local function roomOrigin(index: number): Vector3
	-- a simple row of rooms deep underground
	return RoomConfig.NeighborhoodOrigin + Vector3.new(index * RoomConfig.RoomSpacing, 0, 0)
end

-- Rebuild the furniture of one slot from the profile (or its empty marker).
local function refreshSlot(player: Player, slotId: string)
	local room = rooms[player]
	local profile = PlayerDataService.get(player)
	local slot = RoomConfig.slotById(slotId)
	if not (room and profile and slot) then
		return
	end
	local holder: Folder = room.slotProps[slotId]
	holder:ClearAllChildren()

	local origin = roomOrigin(room.index)
	local baseCF = CFrame.new(origin + slot.offset)
	if slot.kind == "wall" then
		baseCF = baseCF * CFrame.Angles(0, 0, 0) -- back wall faces +Z already
	elseif slot.kind == "window" then
		baseCF = baseCF -- side wall; the window builder is axis-aware via its sizes
	end

	local itemId = profile.Room.Placed[slotId]
	local item = itemId and RoomConfig.get(itemId)
	if item then
		local builder = BUILDERS[item.kind]
		if builder then
			builder(holder, baseCF, item)
		end
	elseif slot.kind ~= "wall" and slot.kind ~= "window" then
		-- an empty floor slot shows a soft "something could go here" marker
		local marker = part({
			Name = "SlotMarker", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 4.4, 4.4),
			Color = C(255, 235, 245), Transparency = 0.35, CanCollide = false,
		})
		marker.CFrame = baseCF * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
		marker.Parent = holder
	end
end

local function buildRoomShell(player: Player, index: number): (Folder, { [string]: Folder })
	local origin = roomOrigin(index)
	local size = RoomConfig.RoomSize
	local folder = Instance.new("Folder")
	folder.Name = "Room_" .. player.UserId

	local floor = part({ Name = "Floor", Size = Vector3.new(size.X, 1, size.Z), Position = origin + Vector3.new(0, -0.5, 0), Color = C(255, 240, 224) })
	floor.Parent = folder
	local ceiling = part({ Name = "Ceiling", Size = Vector3.new(size.X, 1, size.Z), Position = origin + Vector3.new(0, size.Y + 0.5, 0), Color = C(255, 248, 240) })
	ceiling.Parent = folder
	local wallColors = { C(255, 224, 235), C(250, 232, 248) }
	for i, w in ipairs({
		{ Vector3.new(0, size.Y / 2, -size.Z / 2), Vector3.new(size.X, size.Y, 1) },  -- back
		{ Vector3.new(0, size.Y / 2, size.Z / 2), Vector3.new(size.X, size.Y, 1) },   -- front
		{ Vector3.new(-size.X / 2, size.Y / 2, 0), Vector3.new(1, size.Y, size.Z) },  -- left
		{ Vector3.new(size.X / 2, size.Y / 2, 0), Vector3.new(1, size.Y, size.Z) },   -- right
	}) do
		local wall = part({ Name = "Wall" .. i, Size = w[2], Position = origin + w[1], Color = wallColors[(i % 2) + 1] })
		wall.Parent = folder
	end

	-- a soft ceiling light: gentle, or the bloom blows out the little pastel box
	local glow = part({
		Name = "CeilingGlow", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 1.4, 3),
		Position = origin + Vector3.new(0, size.Y - 0.8, 0), Color = C(255, 236, 200),
		Material = Enum.Material.Neon, CanCollide = false,
	})
	glow.Parent = folder
	local light = Instance.new("PointLight")
	light.Color = C(255, 236, 200)
	light.Brightness = 0.55
	light.Range = 26
	light.Parent = glow

	-- the way home: a glowing door on the front wall, with a doormat and a
	-- big friendly sign (Chris got lost in his own room — never again)
	local door = part({
		Name = "HomeDoor", Size = Vector3.new(4.5, 7, 0.8),
		Position = origin + Vector3.new(0, 3.5, size.Z / 2 - 0.6),
		Color = C(255, 200, 120), Material = Enum.Material.Neon, Transparency = 0.2,
	})
	door.Parent = folder
	local mat = part({
		Name = "Doormat", Size = Vector3.new(5.5, 0.2, 3),
		Position = origin + Vector3.new(0, 0.1, size.Z / 2 - 3),
		Color = C(255, 170, 190), CanCollide = false, CanQuery = false,
	})
	mat.Parent = folder
	local signGui = Instance.new("BillboardGui")
	signGui.Name = "DoorSign"
	signGui.Size = UDim2.fromOffset(230, 44)
	signGui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	signGui.AlwaysOnTop = true
	signGui.MaxDistance = 60 -- visible from anywhere in the room
	signGui.Parent = door
	local signLbl = Instance.new("TextLabel")
	signLbl.BackgroundTransparency = 1
	signLbl.Size = UDim2.fromScale(1, 1)
	signLbl.Font = Enum.Font.FredokaOne
	signLbl.TextSize = 22
	signLbl.TextColor3 = C(240, 160, 40)
	signLbl.TextStrokeColor3 = C(255, 255, 255)
	signLbl.TextStrokeTransparency = 0.2
	signLbl.Text = "🚪 Back to Pudding Hills"
	signLbl.Parent = signGui
	local doorPrompt = Instance.new("ProximityPrompt")
	doorPrompt.ObjectText = "Door"
	doorPrompt.ActionText = "Back to Pudding Hills"
	doorPrompt.HoldDuration = 0.2
	doorPrompt.MaxActivationDistance = 14
	doorPrompt.RequiresLineOfSight = false
	doorPrompt.Parent = door
	doorPrompt.Triggered:Connect(function(p)
		if p == player then
			RoomService.leaveRoom(p)
		end
	end)

	-- decorating slots: a prompt at every slot
	local slotProps = {}
	for _, slot in ipairs(RoomConfig.Slots) do
		local holder = Instance.new("Folder")
		holder.Name = "Slot_" .. slot.id
		holder.Parent = folder
		slotProps[slot.id] = holder

		local anchor = part({
			Name = "SlotAnchor_" .. slot.id, Size = Vector3.new(1, 1, 1),
			Position = origin + slot.offset + Vector3.new(0, 1, 0),
			Transparency = 1, CanCollide = false,
		})
		anchor.Parent = folder
		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = "Decorate"
		prompt.ActionText = "Choose " .. RoomConfig.kindLabel(slot.kind)
		prompt.HoldDuration = 0.15
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.Parent = anchor
		prompt.Triggered:Connect(function(p)
			if p == player then
				openCatalogEvent:FireClient(p, { slotId = slot.id, kind = slot.kind })
			end
		end)
	end

	folder.Parent = roomsFolder
	return folder, slotProps
end

-- ── Public API ──────────────────────────────────────────────────────────────

-- Teleport a player to their room, building it on first visit this server.
function RoomService.visitRoom(player: Player)
	if not PlayerDataService.isReady(player) then
		return
	end
	local char = player.Character
	if not (char and char.PrimaryPart) then
		return
	end
	local room = rooms[player]
	if not room then
		local index = 1
		while usedIndices[index] do
			index += 1
		end
		if index > RoomConfig.MaxRooms then
			toastEvent:FireClient(player, "The rooms are all cozy and full right now - try again soon!")
			return
		end
		usedIndices[index] = true
		local folder, slotProps = buildRoomShell(player, index)
		room = { index = index, folder = folder, slotProps = slotProps }
		rooms[player] = room
		for _, slot in ipairs(RoomConfig.Slots) do
			refreshSlot(player, slot.id)
		end
	end
	room.entryCF = char:GetPivot()
	local origin = roomOrigin(room.index)
	char:PivotTo(CFrame.new(origin + Vector3.new(0, 3.5, RoomConfig.RoomSize.Z / 2 - 5)))
	toastEvent:FireClient(player, "Welcome to YOUR Squishy Room! Decorate the glowing spots — the 🚪 door behind you goes home.")
	if RoomService.onVisited then
		RoomService.onVisited(player)
	end
end

-- Bring them back to where they entered from (or the Pudding Hills spawn).
function RoomService.leaveRoom(player: Player)
	local char = player.Character
	if not (char and char.PrimaryPart) then
		return
	end
	local room = rooms[player]
	local backCF = room and room.entryCF or CFrame.new(0, 4, 34)
	char:PivotTo(backCF)
end

-- Buy-if-needed + place an item into a slot (itemId = nil clears the slot).
local function onPlace(player: Player, slotId: any, itemId: any)
	if type(slotId) ~= "string" then
		return
	end
	local profile = PlayerDataService.get(player)
	local slot = RoomConfig.slotById(slotId)
	if not (profile and slot and rooms[player]) then
		return
	end

	if itemId == nil then
		profile.Room.Placed[slotId] = nil
		refreshSlot(player, slotId)
		PlayerDataService.sync(player)
		return
	end
	if type(itemId) ~= "string" then
		return
	end
	local item = RoomConfig.get(itemId)
	if not item or item.kind ~= slot.kind then
		return
	end
	if not profile.Room.Owned[itemId] then
		if not PlayerDataService.spendCoins(player, item.price) then
			toastEvent:FireClient(player, "The " .. item.name .. " costs " .. item.price .. " Sparkle Coins - keep squishing!")
			return
		end
		profile.Room.Owned[itemId] = true
		toastEvent:FireClient(player, item.icon .. " You got the " .. item.name .. "!")
	end
	profile.Room.Placed[slotId] = itemId
	refreshSlot(player, slotId)
	PlayerDataService.sync(player)
end

local function onLeaveCleanup(player: Player)
	local room = rooms[player]
	if room then
		usedIndices[room.index] = nil
		room.folder:Destroy()
		rooms[player] = nil
	end
end

function RoomService.init()
	toastEvent = Remotes.get(Remotes.Toast)
	openCatalogEvent = Remotes.get(Remotes.OpenRoomCatalog)

	roomsFolder = Instance.new("Folder")
	roomsFolder.Name = "SquishyRooms"
	roomsFolder.Parent = Workspace

	Remotes.get(Remotes.VisitRoom).OnServerEvent:Connect(function(player, action)
		if action == "leave" then
			RoomService.leaveRoom(player)
		else
			RoomService.visitRoom(player)
		end
	end)
	Remotes.get(Remotes.PlaceRoomItem).OnServerEvent:Connect(onPlace)
	Players.PlayerRemoving:Connect(onLeaveCleanup)

	-- The way in: a cozy glowing door IN THE VILLAGE (districts pass — your
	-- home door belongs on the cottage lane, not parked at spawn).
	task.spawn(function()
		local home = Workspace:WaitForChild("PuddingHills", 30) or Workspace
		local base = Vector3.new(-49, 0, 32)
		local face = CFrame.lookAt(base, Vector3.new(-12, 0, 44))
		for _, sx in ipairs({ -1, 1 }) do
			local post = part({ Name = "RoomDoorPost", Size = Vector3.new(0.9, 8, 0.9), Color = C(244, 230, 214) })
			post.CFrame = face * CFrame.new(sx * 2.8, 4, 0)
			post.Parent = home
		end
		local arch = part({ Name = "RoomDoorArch", Shape = Enum.PartType.Ball, Size = Vector3.new(6.6, 3.4, 1.4), Color = C(255, 170, 190), CanCollide = false })
		arch.CFrame = face * CFrame.new(0, 8.4, 0)
		arch.Parent = home
		local door = part({
			Name = "RoomDoor", Size = Vector3.new(4.6, 7.2, 0.6),
			Color = C(255, 200, 222), Material = Enum.Material.Neon, Transparency = 0.15,
		})
		door.CFrame = face * CFrame.new(0, 3.6, 0)
		door.Parent = home
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(200, 40)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 6.2, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 60
		gui.Parent = door
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextSize = 22
		lbl.TextColor3 = C(225, 90, 150)
		lbl.TextStrokeColor3 = C(255, 255, 255)
		lbl.TextStrokeTransparency = 0.2
		lbl.Text = "🏠 My Squishy Room"
		lbl.Parent = gui
		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = "My Squishy Room"
		prompt.ActionText = "Go Home"
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = door
		prompt.Triggered:Connect(function(player)
			RoomService.visitRoom(player)
		end)
	end)
end

return RoomService
