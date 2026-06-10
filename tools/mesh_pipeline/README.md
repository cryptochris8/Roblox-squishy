# Mesh pipeline — card-faithful 3D bodies for every friend

Turns each friend's actual trading-card art into a textured 3D mesh and wires it
into the game. Built 2026-06-09/10; all queries go through .NET (this machine's
TLS-inspecting proxy breaks curl/Python — see ../card_art/README.md).

## The path
1. **Crop** the hero art out of each card (fixed template window):
   `python crop_cards.py` → `crops/<friendId>.png` (sources from the mobile-app
   repo's `final_48`; friend id = lower-cased card name, matches SquishyDefinitions).
2. **Generate** via Meshy image-to-3D (`meshy_batch.ps1`, resumable, concurrency 4):
   ~3 min and 30 credits per friend; writes `output/<friendId>.fbx` + `_thumb.png`
   and records everything in `manifest.json`. Key: `MESHY_API_KEY` in
   HKCU:\Environment (NEVER in the repo). Reroll a friend by deleting its manifest
   entry and rerunning with `-Only friend_id`.
3. **Upload** to Roblox (`upload_meshes.ps1`, resumable): Open Cloud Assets API,
   assetType `Model`, content-type `model/fbx`. Meshy FBXs EMBED their textures,
   so the imported Model arrives as MeshPart + SurfaceAppearance (ColorMap +
   NormalMap) — no separate texture upload. Ids land in `upload_result.json`.
   Key: `ROBLOX_OPEN_CLOUD_KEY` (Assets: Write).
4. **Resolve into the place** (Studio, edit mode, via execute_luau): for each
   assetId `InsertService:LoadAsset` → take the MeshPart → rename to the friendId
   → scale to ~4 studs max-dimension → `Anchored`, `CanCollide=false`,
   `CastShadow=false` → `PivotOffset = CFrame.Angles(0, rad(180), 0)` (raw Meshy
   meshes face -Z; the pivot flip makes every consumer get a +Z-facing friend
   for free) → parent into `ServerStorage.MeshBodies`.
5. **The game does the rest**: `SquishyModelFactory.build` prefers
   `ServerStorage.MeshBodies[<friendId>]` (clone named "Body", `HatOffset` attr,
   `BakedFace=true` so SquishFx/BuddyService skip their billboard faces); the
   part-built archetypes remain the fallback. `applyGolden` strips the
   SurfaceAppearance so event gold shows on mesh bodies.

## Files
- `crop_cards.py` / `meshy_batch.ps1` / `upload_meshes.ps1` — the tools
- `manifest.json` — friendId → Meshy task id/status/credits (provenance)
- `upload_result.json` — friendId → Roblox Model assetId (provenance)
- `STATE.md` — the run log / resume anchor for the overnight build
- `crops/`, `output/`, `work/` — bulk artifacts, gitignored (regenerable)

## Notes
- The card scenes sometimes ride along (Soft Dumpling keeps its bamboo steamer) —
  kept deliberately when coherent: it matches the card. Reroll only malformed ones.
- The baked-face tradeoff: mesh friends don't blink awake (face is in the
  texture); the zZz tag + Joy bar still carry the sleepy→awake read.
