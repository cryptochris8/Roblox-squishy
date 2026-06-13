--!strict
-- SquishyData
-- A small, friendly query layer over the generated SquishyDefinitions table.
-- Both the server and the client require this to look up squishy friends by id,
-- pack, zone, or rarity, and to get the sorted 48-card launch roster for the
-- Squishy Book. The generated data stays the single source of truth.

local Shared = script.Parent
local Definitions = require(Shared:WaitForChild("SquishyDefinitions"))

-- Apply any uploaded card-art ids over the generated "REPLACE_ME" placeholders,
-- so every consumer (Squishy Book, Capsule reveal, and the server) sees the real
-- image automatically. Friends without an id keep their coloured placeholder.
local CardImageAssets = require(Shared:WaitForChild("CardImageAssets"))
for id, assetId in pairs(CardImageAssets) do
	local def = Definitions[id]
	if def and type(assetId) == "number" and assetId > 0 then
		-- %d so big 15-digit ids never turn into scientific notation.
		def.ImageAssetId = string.format("rbxassetid://%d", assetId)
	end
end

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
-- Family friends are their OWN thing, so they're excluded here (and from the
-- weekly visitor pool, which reads this).
function SquishyData.getEventRoster(): { any }
	return sortedBy(function(def)
		return def.ReleaseType ~= "launch" and def.ReleaseType ~= "family"
	end)
end

-- The three Family friends (Chris's daughters), shown in the Book's ⭐ Family
-- tab and earned one per land by restoring its Sparkle shard. Fixed order by
-- land progression (their CardNumbers aren't numeric, so the default sort is
-- unstable) — Apple (Pudding) → Eggy (Goo) → Heidi (Moonlit).
local FAMILY_ORDER = { apple_addy = 1, eggy_ellie = 2, hot_dog_heidi = 3 }
function SquishyData.getFamilyRoster(): { any }
	local list = {}
	for _, def in pairs(Definitions) do
		if def.ReleaseType == "family" then
			table.insert(list, def)
		end
	end
	table.sort(list, function(a, b)
		return (FAMILY_ORDER[a.Id] or 99) < (FAMILY_ORDER[b.Id] or 99)
	end)
	return list
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
