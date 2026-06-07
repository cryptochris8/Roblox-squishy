--!strict
-- SquishyData
-- A small, friendly query layer over the generated SquishyDefinitions table.
-- Both the server and the client require this to look up squishy friends by id,
-- pack, zone, or rarity, and to get the sorted 48-card launch roster for the
-- Squishy Book. The generated data stays the single source of truth.

local Shared = script.Parent
local Definitions = require(Shared:WaitForChild("SquishyDefinitions"))

local SquishyData = {}

-- "001/048" -> 1 (used to sort the album in card-number order).
local function cardIndex(def): number
	local prefix = def.CardNumber and string.match(def.CardNumber, "^(%d+)")
	return (prefix and tonumber(prefix)) or 9999
end
SquishyData.cardIndex = cardIndex

function SquishyData.getById(id: string)
	return Definitions[id]
end

function SquishyData.getAll()
	return Definitions
end

-- Returns a fresh array of every def matching the filter, sorted by card number.
local function sortedBy(filterFn): { any }
	local list = {}
	for _, def in pairs(Definitions) do
		if filterFn(def) then
			table.insert(list, def)
		end
	end
	table.sort(list, function(a, b)
		return cardIndex(a) < cardIndex(b)
	end)
	return list
end
SquishyData.sortedBy = sortedBy

-- The official 48-card launch roster (excludes the future weekly/event pack).
function SquishyData.getLaunchRoster(): { any }
	return sortedBy(function(def)
		return def.ReleaseType == "launch"
	end)
end

-- The event/weekly friends (shown under the "Events" tab in the Squishy Book).
function SquishyData.getEventRoster(): { any }
	return sortedBy(function(def)
		return def.ReleaseType ~= "launch"
	end)
end

function SquishyData.getByPack(packId: string): { any }
	return sortedBy(function(def)
		return def.PackId == packId
	end)
end

function SquishyData.getByZone(zone: string): { any }
	return sortedBy(function(def)
		return def.Zone == zone
	end)
end

function SquishyData.getByRarity(rarity: string): { any }
	return sortedBy(function(def)
		return def.Rarity == rarity
	end)
end

return SquishyData
