# Card → 3D Asset Pipeline (Squishy Smash)

**How a card-collection idea becomes a real, textured 3D body squishing around in
Roblox — every step, every tool, every command.**

This is the reproducible recipe. Follow it to add a new friend, re-render a card,
or explain the workflow to someone else. Written 2026-06-29 from the actual
pipeline that shipped all 48 launch friends + the Family Three.

---

## The big picture (read this first)

A friend travels through **two parallel tracks** that both end inside Roblox:

```
                         data/raw/*.json  (the IDEA — id, name, rarity, stats)
                                  │
                  ┌───────────────┴────────────────┐
                  │                                 │
        TRACK 1: CARD ART                  TRACK 2: 3D MESH BODY
        (the 2D collectible)               (the thing you squish)
                  │                                 │
   rendered in the mobile-app repo          crop the card hero art
   (final_48/*.webp)                        (crop_cards.py — Pillow)
                  │                                 │
   WebP → PNG (Pillow)                       Meshy AI image-to-3D
                  │                          (meshy_batch.ps1 → .fbx)
   upload as Decal (Open Cloud)                     │
   (upload_cards.ps1)                        upload as Model (Open Cloud)
                  │                          (upload_meshes.ps1)
   resolve Decal → Image id (Studio)                │
                  │                          resolve into the place (Studio)
   CardImageAssets.lua                       ServerStorage.MeshBodies/<id>
                  │                                 │
                  └───────────────┬────────────────┘
                                  │
                    SquishyModelFactory.build(def)
        (prefers a Meshy mesh body; falls back to a part-built archetype)
                                  │
                          In-game 3D friend
```

The named tools, end to end:
**JSON data → Pillow (Python) → Meshy AI (image-to-3D) → Roblox Open Cloud Assets
API → PowerShell uploaders → Roblox Studio Luau (`InsertService`) →
`SquishyModelFactory` at runtime.**

Two API keys gate everything (both in `HKCU:\Environment`, never in the repo):
- `MESHY_API_KEY` — Meshy AI
- `ROBLOX_OPEN_CLOUD_KEY` — Roblox Open Cloud (scope **Assets: Write**, IP `0.0.0.0/0`)

> **Environment gotcha that shapes the whole pipeline:** this machine sits behind a
> **TLS-inspecting proxy** whose CA only **.NET** trusts. `curl` and Python both
> fail the HTTPS handshake (`CERTIFICATE_VERIFY_FAILED`) on Roblox/Meshy calls. So
> **every API call goes through Windows PowerShell 5.1** (`Invoke-RestMethod` /
> `System.Net.Http.HttpClient`). PS 5.1 has no `Invoke-RestMethod -Form`, so
> multipart uploads are hand-built with `MultipartFormDataContent`. (Python is fine
> for purely local image work like Pillow — it just can't do the network calls.)

---

## Stage 0 — The idea / source of truth

Every friend begins as **data, not art**.

- **`data/raw/*.json`** — 4 pack files define all 48 launch friends + event/family
  characters. Each entry: `id`, `name`, `category`, `rarity`, physics
  (`deformability`, `elasticity`, `gooLevel`, `burstThreshold`), sounds,
  `coinReward`, `cardNumber` (`001`…`048`).
- These generate **`src/ReplicatedStorage/Shared/SquishyDefinitions.lua`** (the
  in-game source of truth, with Roblox additions: `ImageAssetId`, `Zone`,
  `PackName`, `ReleaseType` = `"launch"`/`"family"`/event).
- At runtime, **`SquishyData.lua`** merges the art ids (below) over the definitions.

**The id is the through-line.** A friend's `id` is the lower-cased name part of its
card filename and is the key used in EVERY downstream file:

```
003_Peach_Mochi.webp   →   friend id "peach_mochi"
```

That single rule is what lets the card image, the crop, the Meshy task, the Roblox
Model, and the mesh-body template all line up automatically.

---

## TRACK 1 — Card art → Roblox image

Tools: **mobile-app render → Pillow → Open Cloud (Decal) → Studio Luau →
`CardImageAssets.lua`**. (Full notes: `tools/card_art/README.md`.)

### 1.1 — Source art (rendered elsewhere)
The finished trading cards live in the **separate mobile-app repo**, not here:
```
C:\Users\chris\Squishy-smash\squishy_smash\assets\cards\final_48\NNN_Name.webp
```

### 1.2 — Convert WebP → PNG (Pillow)
Roblox upload needs PNG. One-liner (writes to `%TEMP%\squishy_cards_png`):
```bash
python -c "import glob,os,tempfile; from PIL import Image; \
s=r'C:\\Users\\chris\\Squishy-smash\\squishy_smash\\assets\\cards\\final_48'; \
d=os.path.join(tempfile.gettempdir(),'squishy_cards_png'); os.makedirs(d,exist_ok=True); \
[Image.open(f).convert('RGBA').save(os.path.join(d,os.path.splitext(os.path.basename(f))[0]+'.png'),'PNG') for f in glob.glob(os.path.join(s,'*.webp'))]"
```

### 1.3 — Upload to Roblox as Decal assets
`tools/card_art/upload_cards.ps1` (PS 5.1 + HttpClient, resumable). Endpoint
`POST https://apis.roblox.com/assets/v1/assets`, `assetType = "Decal"`,
content-type `image/png`, creator userId `7230402132`, polls
`operations/<opId>` for the asset id, 900ms between cards with 429 backoff.
```
powershell -ExecutionPolicy Bypass -File tools\card_art\upload_cards.ps1 -Limit 1   # test one
powershell -ExecutionPolicy Bypass -File tools\card_art\upload_cards.ps1            # the rest
```
Writes `tools/card_art/upload_result.json` (`friendId → Decal id`, provenance).

### 1.4 — Resolve Decal → Image id (in Studio)
The Assets API returns a **Decal** id, but `ImageLabel.Image` needs the underlying
**Image** id (a decal id renders BLANK). In Studio (edit mode, `execute_luau`),
per id:
```lua
local d = game:GetService("InsertService"):LoadAsset(decalId)
-- the loaded Decal's .Texture is "rbxassetid://<IMAGE_ID>"; take the numeric id
```

### 1.5 — Wire the Image ids into the game
Drop each `friendId → numeric image id` into
**`src/ReplicatedStorage/Shared/CardImageAssets.lua`**, e.g.
`soft_dumpling = 134003206141337,`. `SquishyData` merges these over the
`REPLACE_ME` defaults; the Collection Book and Capsule Reveal show real art. A
friend with no id falls back to a coloured placeholder.

**Replacing one card:** re-render it in `final_48`, convert that one PNG, remove it
from the `$skip` list in `upload_cards.ps1` (or upload ad-hoc), resolve the new
Decal, and update its id in `CardImageAssets.lua`.

---

## TRACK 2 — Card art → 3D mesh body (the headline)

Tools: **Pillow crop → Meshy AI image-to-3D → Open Cloud (Model) → Studio Luau →
`ServerStorage.MeshBodies`**. Everything lives in `tools/mesh_pipeline/`.
(Full notes: `tools/mesh_pipeline/README.md` + run log in `STATE.md`.)

### 2.1 — Crop the hero art off each card
Meshy should see the **character**, not the card frame/title/stat panel.
`tools/mesh_pipeline/crop_cards.py` (Python + Pillow) crops a fixed template window
`(55, 300, 1030, 925)` out of the 1086×1448 cards and names the output by friend id:
```
python tools/mesh_pipeline/crop_cards.py     # → crops/<friendId>.png  (all 48)
```

### 2.2 — Generate the 3D mesh with Meshy (image-to-3D)
`tools/mesh_pipeline/meshy_batch.ps1` (PS 5.1, **resumable**, concurrency 4).
Reads `MESHY_API_KEY` from `HKCU:\Environment`.

- `POST https://api.meshy.ai/openapi/v1/image-to-3d` with the crop as a base64
  `data:image/png` URI and these settings:
  ```json
  { "enable_pbr": false, "should_remesh": true, "should_texture": true,
    "topology": "triangle", "target_polycount": 12000, "symmetry_mode": "auto" }
  ```
- Returns a `taskId`. Poll `GET .../image-to-3d/{taskId}` every 20s until
  `SUCCEEDED`, then download `model_urls.fbx` + `thumbnail_url`.
- **~3 min and ~30 credits per friend.** Outputs `output/<friendId>.fbx` +
  `_thumb.png`. Every change is written to `manifest.json`
  (`friendId → {taskId, status, fbx, thumb, credits}`), so a rerun skips finished
  friends and resumes in-flight tasks.

```
powershell -ExecutionPolicy Bypass -File tools\mesh_pipeline\meshy_batch.ps1
# reroll one friend: delete its manifest entry, then:
powershell -ExecutionPolicy Bypass -File tools\mesh_pipeline\meshy_batch.ps1 -Only soft_dumpling
```

**QC tip:** `contact_sheet.py` tiles all the `_thumb.png`s so you can eyeball that
each mesh reads as its card before uploading. (Full run: 48/48, 1440 credits, zero
rerolls.)

### 2.3 — Upload each FBX to Roblox as a Model
`tools/mesh_pipeline/upload_meshes.ps1` (PS 5.1 + HttpClient, **resumable**). Reads
`ROBLOX_OPEN_CLOUD_KEY`.

- `POST https://apis.roblox.com/assets/v1/assets`, `assetType = "Model"`,
  content-type `model/fbx`, creator userId `7230402132`, polls
  `operations/<opId>` for the asset id.
- **Meshy FBXs EMBED their textures**, so the imported Roblox Model arrives as a
  `MeshPart` + `SurfaceAppearance` (ColorMap + NormalMap) — no separate texture
  upload step.
- Writes `upload_result.json` (`friendId → Roblox Model assetId`, provenance).

```
powershell -ExecutionPolicy Bypass -File tools\mesh_pipeline\upload_meshes.ps1 -Limit 1   # test one
powershell -ExecutionPolicy Bypass -File tools\mesh_pipeline\upload_meshes.ps1            # the rest
```

> ⚠️ **Upload SLOWLY, one at a time, eyeballing each texture.** A fast ~24-FBX
> burst once tripped a **false-positive moderation strike** on an auto-generated UV
> texture atlas (scrambled kawaii texture islands misread as "Sexual Content") →
> a 7-day account ban that 403'd *all* Open Cloud calls and even `LoadAsset` of old
> approved assets. It was appealed and lifted same-day, then finished via
> `trickle_upload.ps1` (one upload / ~8 min / moderation check / stop on anomaly).
> Lesson: visually check each Meshy texture first, space uploads out, never batch.

### 2.4 — Resolve each Model into the place (Studio)
The uploaded Model is just an asset id. In **Studio, edit mode, on the REAL place**,
via `execute_luau`, turn each one into a reusable body template. Per friend:
```lua
local assetId = 85266889744083            -- from upload_result.json
local loaded  = game:GetService("InsertService"):LoadAsset(assetId)
local mesh    = loaded:FindFirstChildWhichIsA("MeshPart", true)  -- Meshy's "Mesh_0"
mesh.Name        = "goo_ball"             -- the friend id
mesh.Anchored    = true
mesh.CanCollide  = false
mesh.CastShadow  = false
-- scale to ~4 studs on the longest axis
local m = math.max(mesh.Size.X, mesh.Size.Y, mesh.Size.Z)
mesh.Size = mesh.Size * (4 / m)
-- raw Meshy meshes face -Z; flip the pivot so every consumer gets a +Z (south) face
mesh.PivotOffset = CFrame.Angles(0, math.rad(180), 0)
mesh.Parent = game.ServerStorage.MeshBodies   -- the template folder
```

> **Always verify `game.GameId` before resolving** — Rojo renames whatever place it
> fills, which once disguised a throwaway baseplate as the real place. The real one:
> PlaceId `105594294243426` / universe `10292103666`.

Templates land in **`ServerStorage.MeshBodies/<friendId>`**. Because they live in
the place, **File → Publish (Alt+P)** bakes them in.

---

## Stage 3 — Runtime: the factory picks a body

`src/ServerScriptService/Server/SquishyModelFactory.lua` builds every friend with a
**three-tier fallback** in `build(def)`:

1. **Mesh body (preferred)** — if `ServerStorage.MeshBodies/<def.Id>` exists, clone
   it, name it `"Body"`, set `HatOffset` and `BakedFace = true` (face is painted
   into the texture, so SquishFx/BuddyService skip their billboard face).
2. **Part-built archetype (fallback)** — look up `SKINS[def.Id]` and call one of
   ~17 procedural archetype builders (dumpling, bun, mochi, cube, blob, orb, puff,
   bunny, bat, ghost…) that assemble the friend from plain Roblox primitives
   (Balls/Blocks/Cylinders/Wedges) with hand-tuned colours. **No AI needed** — this
   is how the game looked before the Meshy bodies, and it still backstops any friend
   without a mesh.
3. **Plain ball (last resort)** — a friend with neither mesh nor skin.

`applyGolden(model)` (for event "golden" friends) strips the `SurfaceAppearance` off
mesh bodies so the gold shows, then tints + sparkles.

---

## Quick reference — files & where ids live

**Data (the idea)**
- `data/raw/*.json` — character definitions (source of truth)
- `src/ReplicatedStorage/Shared/SquishyDefinitions.lua` — generated in-game truth
- `src/ReplicatedStorage/Shared/SquishyData.lua` — merges art ids at runtime

**Track 1 — card art**
- `tools/card_art/README.md` — the card recipe
- `tools/card_art/upload_cards.ps1` — Decal uploader (resumable)
- `tools/card_art/upload_result.json` — friendId → Decal id (provenance)
- `src/ReplicatedStorage/Shared/CardImageAssets.lua` — friendId → **Image** id (live)

**Track 2 — 3D mesh**
- `tools/mesh_pipeline/README.md` + `STATE.md` — the mesh recipe + run log
- `tools/mesh_pipeline/crop_cards.py` — Pillow crop of card hero art
- `tools/mesh_pipeline/meshy_batch.ps1` — Meshy image-to-3D (resumable)
- `tools/mesh_pipeline/upload_meshes.ps1` — Roblox Model uploader (resumable)
- `tools/mesh_pipeline/manifest.json` — friendId → Meshy task/status/credits
- `tools/mesh_pipeline/upload_result.json` — friendId → Roblox Model assetId
- `ServerStorage.MeshBodies/<friendId>` — the in-place body templates

**Runtime**
- `src/ServerScriptService/Server/SquishyModelFactory.lua` — mesh-or-procedural body

**Credentials (names only — never print values; both in `HKCU:\Environment`)**
- `MESHY_API_KEY` — Meshy AI
- `ROBLOX_OPEN_CLOUD_KEY` — Roblox Open Cloud (Assets: Write)

---

## TL;DR — add one new friend, start to finish

1. Add the friend to `data/raw/*.json` (gives it an `id`); regenerate
   `SquishyDefinitions.lua`.
2. Render its trading card in the mobile-app repo (`final_48/NNN_Name.webp`).
3. **Card art:** WebP→PNG (Pillow) → `upload_cards.ps1` → resolve Decal→Image id in
   Studio → add id to `CardImageAssets.lua`.
4. **3D body:** `crop_cards.py` → `meshy_batch.ps1 -Only <id>` → eyeball the
   thumbnail → `upload_meshes.ps1 -Limit 1` → resolve into
   `ServerStorage.MeshBodies/<id>` in Studio.
5. Play-test (the factory auto-prefers the new mesh body), then **File → Publish
   (Alt+P)** to bake the mesh template into the live place.
