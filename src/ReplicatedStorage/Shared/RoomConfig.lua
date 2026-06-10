--!strict
-- RoomConfig
-- The Squishy Room: every player gets a cozy little room of their own to
-- decorate with furniture bought with EARNED Sparkle Coins (the deepest coin
-- sink; doc 09's "decorate a Squishy Room"). Shared so the server (validation,
-- building, persistence) and the client (catalog UI) always agree.
--
-- Layout model (deliberately kid-simple): every room has the same fixed SLOTS —
-- marked spots on the floor/walls — and each slot accepts one item of its kind.
-- Decorating = walking to a slot and choosing what goes there. No free-drag,
-- no rotation puzzles, nothing to get "wrong".

export type RoomItem = {
	id: string,
	name: string,
	icon: string,
	kind: string, -- which slot kind it fits: "rug" | "bed" | "table" | "lamp" | "plant" | "wall" | "window"
	price: number,
	color: Color3?,
	color2: Color3?,
}

local RoomConfig = {}

-- The rooms sit far below the lands (own "neighborhood"), one per player slot.
RoomConfig.NeighborhoodOrigin = Vector3.new(0, -500, 0)
RoomConfig.RoomSpacing = 200
RoomConfig.MaxRooms = 30 -- per-server instanced rooms (plenty for a family server)

-- Room shell dimensions (one cozy square room).
RoomConfig.RoomSize = Vector3.new(38, 14, 38)

-- The fixed decorating slots: id, kind, and position relative to room centre
-- (floor y=0). Every room shares this layout, so saves are tiny: slotId -> itemId.
RoomConfig.Slots = {
	{ id = "rug_center",  kind = "rug",    offset = Vector3.new(0, 0, 0) },
	{ id = "bed_corner",  kind = "bed",    offset = Vector3.new(-12, 0, -12) },
	{ id = "table_side",  kind = "table",  offset = Vector3.new(11, 0, -10) },
	{ id = "lamp_door",   kind = "lamp",   offset = Vector3.new(13, 0, 12) },
	{ id = "plant_left",  kind = "plant",  offset = Vector3.new(-13, 0, 10) },
	{ id = "wall_back",   kind = "wall",   offset = Vector3.new(0, 7, -18.6) },
	{ id = "window_side", kind = "window", offset = Vector3.new(-18.6, 7, 0) },
}

local C = Color3.fromRGB

local catalog: { RoomItem } = {
	-- rugs
	{ id = "rug_round_pink", name = "Round Pink Rug", icon = "🟣", kind = "rug", price = 150, color = C(255, 190, 210) },
	{ id = "rug_cloud", name = "Cloud Rug", icon = "☁️", kind = "rug", price = 250, color = C(245, 248, 255) },
	{ id = "rug_rainbow", name = "Rainbow Rug", icon = "🌈", kind = "rug", price = 400, color = C(255, 200, 150), color2 = C(180, 200, 255) },
	-- beds
	{ id = "bed_classic", name = "Cozy Bed", icon = "🛏️", kind = "bed", price = 300, color = C(255, 170, 190), color2 = C(255, 245, 235) },
	{ id = "bed_cloud", name = "Cloud Bed", icon = "💤", kind = "bed", price = 500, color = C(225, 235, 255), color2 = C(250, 250, 255) },
	-- tables
	{ id = "table_tea", name = "Tea Table", icon = "🍵", kind = "table", price = 200, color = C(230, 190, 150) },
	{ id = "table_picnic", name = "Treat Table", icon = "🧁", kind = "table", price = 350, color = C(255, 225, 200) },
	-- lamps
	{ id = "lamp_mushroom", name = "Mushroom Lamp", icon = "🍄", kind = "lamp", price = 200, color = C(235, 120, 140) },
	{ id = "lamp_star", name = "Star Lamp", icon = "⭐", kind = "lamp", price = 300, color = C(255, 220, 110) },
	-- plants
	{ id = "plant_sprout", name = "Happy Sprout", icon = "🌱", kind = "plant", price = 150, color = C(150, 208, 130) },
	{ id = "plant_tulips", name = "Tulip Pot", icon = "🌷", kind = "plant", price = 250, color = C(255, 150, 170) },
	-- wall decor
	{ id = "wall_star_garland", name = "Star Garland", icon = "✨", kind = "wall", price = 200, color = C(255, 220, 110) },
	{ id = "wall_friend_frame", name = "Friend Portrait", icon = "🖼️", kind = "wall", price = 300, color = C(206, 170, 120) },
	-- windows
	{ id = "window_sunny", name = "Sunny Window", icon = "🌞", kind = "window", price = 250, color = C(190, 226, 255) },
	{ id = "window_moon", name = "Moonlit Window", icon = "🌙", kind = "window", price = 350, color = C(140, 140, 200) },
}
RoomConfig.Catalog = catalog

local byId: { [string]: RoomItem } = {}
for _, item in ipairs(catalog) do
	byId[item.id] = item
end

function RoomConfig.get(id: string): RoomItem?
	return byId[id]
end

-- Friendly labels for slot kinds (prompts + the catalog header).
local KIND_LABELS: { [string]: string } = {
	rug = "a rug", bed = "a bed", table = "a table", lamp = "a lamp",
	plant = "a plant", wall = "wall decor", window = "a window",
}
function RoomConfig.kindLabel(kind: string): string
	return KIND_LABELS[kind] or kind
end

function RoomConfig.slotById(slotId: string)
	for _, s in ipairs(RoomConfig.Slots) do
		if s.id == slotId then
			return s
		end
	end
	return nil
end

function RoomConfig.ofKind(kind: string): { RoomItem }
	local list = {}
	for _, item in ipairs(catalog) do
		if item.kind == kind then
			list[#list + 1] = item
		end
	end
	return list
end

return RoomConfig
