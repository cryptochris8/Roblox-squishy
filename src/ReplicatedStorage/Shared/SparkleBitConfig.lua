--!strict
-- SparkleBitConfig
-- Hidden Sparkle Bits tucked around Pudding Hills to reward exploration (not
-- clicking). Shared so the CLIENT can render the bits it hasn't found yet and the
-- SERVER can validate a pickup (range + not-already-collected) before awarding.
--
-- Each bit floats at roughly player height so you collect it by walking up to it.
-- Spots are spread N/S/E/W and tied to landmarks (cottage, orchard, capsule,
-- guide, syrup river) so finding them all means seeing the whole valley.

local SparkleBitConfig = {}

export type Bit = { id: string, position: Vector3, hint: string }

SparkleBitConfig.Bits = {
	{ id = "behind_cottage", position = Vector3.new(-58, 2.6, 38), hint = "behind the cream cottage" },
	{ id = "far_west",       position = Vector3.new(-72, 2.6, 2),  hint = "out west past the cottage" },
	{ id = "river_west",     position = Vector3.new(-52, 2.6, 16), hint = "by the syrup river's western bend" },
	{ id = "guide_nook",     position = Vector3.new(-24, 2.6, 6),  hint = "near Soft Dumpling" },
	{ id = "southwest_dune", position = Vector3.new(-46, 2.6, -40), hint = "among the southwest dunes" },
	{ id = "north_dell",     position = Vector3.new(-2, 2.6, -50), hint = "in the far north of the valley" },
	{ id = "behind_capsule", position = Vector3.new(0, 2.6, -22),  hint = "behind the Sparkle Capsule" },
	{ id = "orchard_deep",   position = Vector3.new(56, 2.6, -50), hint = "deep in the orchard grove" },
	{ id = "east_meadow",    position = Vector3.new(50, 2.6, 26),  hint = "in the eastern meadow" },
	{ id = "east_dunes",     position = Vector3.new(78, 2.6, -6),  hint = "out east toward Goo Coast" },
}

function SparkleBitConfig.count(): number
	return #SparkleBitConfig.Bits
end

return SparkleBitConfig
