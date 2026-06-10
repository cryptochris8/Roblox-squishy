--!strict
-- SparkleBitConfig
-- Hidden Sparkle Bits tucked around ALL THREE lands to reward exploration (not
-- clicking). Shared so the CLIENT can render the bits it hasn't found yet and the
-- SERVER can validate a pickup (range + not-already-collected) before awarding.
--
-- Each bit floats at roughly player height so you collect it by walking up to it.
-- Spots are tied to landmarks (cottages, the pier's end, the lighthouse, the
-- stargazing circle...) so finding them all means truly seeing every land.
-- Goo Coast sits at x+600, Moonlit Hollow at x+1200 (see ZoneConfig).

local SparkleBitConfig = {}

export type Bit = { id: string, position: Vector3, hint: string }

SparkleBitConfig.Bits = {
	-- ── Pudding Hills ───────────────────────────────────────────────────────
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

	-- ── Goo Coast (unlocks with its land; an endgame-y hunt is fine) ────────
	{ id = "goo_pier_end",   position = Vector3.new(600, 4.4, -48),  hint = "at the very end of the pier" },
	{ id = "goo_lighthouse", position = Vector3.new(520, 2.6, 6),    hint = "behind the lighthouse" },
	{ id = "goo_sandcastle", position = Vector3.new(548, 2.6, 48),   hint = "behind the sandcastle" },
	{ id = "goo_cove",       position = Vector3.new(669, 2.6, 10),   hint = "tucked in the rocky cove" },
	{ id = "goo_huts",       position = Vector3.new(647, 2.6, 64),   hint = "behind the beach huts" },
	{ id = "goo_rowboat",    position = Vector3.new(578, 2.6, -12),  hint = "by the beached rowboat" },
	{ id = "goo_tidepool",   position = Vector3.new(633, 2.6, 12),   hint = "beside a tide pool" },
	{ id = "goo_dunes",      position = Vector3.new(576, 2.6, 78),   hint = "deep in the southern dunes" },

	-- ── Moonlit Hollow ──────────────────────────────────────────────────────
	{ id = "moon_stargaze",  position = Vector3.new(1248, 2.6, -70), hint = "at the stargazing circle" },
	{ id = "moon_cottage_w", position = Vector3.new(1142, 2.6, 66),  hint = "behind a mushroom cottage" },
	{ id = "moon_cottage_e", position = Vector3.new(1266, 2.6, -12), hint = "by the blue-capped cottage" },
	{ id = "moon_grove",     position = Vector3.new(1150, 2.6, 20),  hint = "among the giant mushrooms" },
	{ id = "moon_log",       position = Vector3.new(1244, 2.6, 26),  hint = "behind the cozy log" },
	{ id = "moon_pool",      position = Vector3.new(1200, 2.6, -36), hint = "across the moonpool" },
	{ id = "moon_meadow",    position = Vector3.new(1222, 2.6, 70),  hint = "out in the firefly meadow" },
	{ id = "moon_north",     position = Vector3.new(1174, 2.6, -70), hint = "past the violet cottage" },
}

function SparkleBitConfig.count(): number
	return #SparkleBitConfig.Bits
end

return SparkleBitConfig
