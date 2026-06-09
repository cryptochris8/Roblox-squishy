# 10 — Free Asset Sources for Roblox Games (Reusable Catalog)

A reusable, license-vetted catalog of **free** asset sources for building Roblox games.
Built from parallel research, verified **~June 2026**. This file is meant to be **reused
for every Roblox game we build** — copy it into a new game's `docs/`, or reference it.
Squishy Smash–specific picks are in §8.

> ⚠️ Asset libraries, licenses, and Roblox limits change. Re-verify a source's license
> page before shipping anything in a monetized game.

---

## 0. Licensing cheat sheet (read first)

| License | Use in a published/monetized game? | Credit required? |
|---|---|---|
| **CC0 / Public Domain** | ✅ Yes — modify & ship freely | **No** — *prefer this* |
| **CC-BY** | ✅ Yes | **Yes** — keep a credits list/screen |
| **CC-BY-SA** | ✅ in-game use is fine | Yes + derivatives share-alike (avoid for proprietary) |
| **CC-NC (NonCommercial)** | ❌ **Never** in a game with Robux/passes/products | — |
| **"Free" (custom/All-Rights-Reserved)** | ⚠️ Read the EULA per asset | varies |
| **Roblox-native (Creator Store)** | ✅ Use *inside* Roblox experiences | No |

**Two golden rules**
1. Using an asset **inside your game = fine**. **Re-selling/re-uploading the raw asset** (to the Creator Store, as a UGC item, as a texture pack) = usually **not** — CC0 allows it, most others don't.
2. **"Free" ≠ "CC0."** Always check the per-asset license, especially on aggregator sites (Poly Pizza, Sketchfab, itch.io, OpenGameArt) that mix licenses within one pack.

---

## 1. Roblox-native sources (safest — in-engine, no import)

- **Creator Store / Toolbox** — Studio `View → Toolbox`, or `create.roblox.com/store`.
  - Always use the **Free** filter (the store now also sells paid models).
  - Keep the **default "verified creators only"** on; filter **Creators = `Roblox`** for first-party; an **orange shield** = officially endorsed.
  - **Prefer script-free meshes/models** — historically malware rides in scripts inside old free models (extra important for a kids' game). Inspect/strip scripts before publishing.
  - License: you get the right to **use** assets in experiences (not ownership); you **can't re-distribute/re-sell** assets you didn't create. Shipping them in your game = fine.
- **★ Synty free POLYGON packs** — first-party partnership, **free in the Marketplace/Toolbox** ("free to use in anything you create on Roblox"). Packs: **Nature**, **City**, Dungeon. Cohesive low-poly "toy box" style — **Nature + City** are an ideal pastel-friendly base. (Skip Dungeon/Skeleton for kid-safe themes.)
- **★ Roblox Audio Library** — `create.roblox.com/store/audio`. **100k+ professionally produced, pre-cleared** SFX & music (Pro Sound Effects, Monstercat, APM…). **This is the safe audio source — no copyright-strike risk.** Cap: 250 licensed tracks per experience; "Roblox-only, no download."
- **Built-in Materials / Material Manager / MaterialVariant** — free engine PBR. Build **custom pastel materials from your own texture maps**; `MaterialVariant` overrides a base material globally or per-part. Zero licensing concerns.
- **Studio MCP automation** — `search_creator_store` / `insert_from_creator_store` let an agent search the store and drop assets into the open place for review (still vet each one).

## 2. External 3D models / meshes (import as MeshParts)

| Source | URL | License | Notes |
|---|---|---|---|
| **Kenney** ⭐ | kenney.nl/assets | **CC0** | Tiny tri-counts, single atlas; imports clean. |
| **Quaternius** ⭐ | quaternius.com | **CC0** | Stylized/pastel; some rigged + animated. |
| **KayKit** | kaylousberg.itch.io | **CC0** | "Compatible with Roblox"; don't resell raw. |
| **Poly Pizza** | poly.pizza | **Mixed** (filter CC0) | Great search; CC-BY models need credit. |
| **Sketchfab** | sketchfab.com | **Mixed** | Filter Downloadable + license; avoid NC. |
| **itch.io / OpenGameArt** | itch.io/game-assets · opengameart.org | **Mixed** (filter CC0) | Read each pack's license box. |

**Standout pastel/storybook packs (all CC0):**
- **Kenney — Food Kit** (200 dessert/food props 🍮), **Nature Kit** (330), **Furniture Kit** (cozy interiors), **Holiday Kit**, **Particle Pack**.
- **Quaternius — Stylized Nature MegaKit** (Ghibli-style trees, **mushrooms**, flowers, rocks), **Cute Animals**, **Ultimate Platformer Pack**.
- **KayKit — Forest Nature Pack**, **Platformer Pack**.

## 3. Textures, PBR materials, HDRIs & skyboxes

| Source | URL | License | Offers |
|---|---|---|---|
| **Poly Haven** ⭐ | polyhaven.com | **CC0** | PBR textures, **HDRIs** (Sunrise/Sunset, Overcast skies), models |
| **ambientCG** ⭐ | ambientcg.com | **CC0** | 2,800+ PBR materials, HDRIs |
| **cgbookcase** | cgbookcase.com | **CC0** | PBR textures, no credit |
| **ShareTextures / TextureCan / cc0-textures** | sharetextures.com · texturecan.com · cc0-textures.com | **CC0** | PBR textures + some models |

> ❌ **Avoid `textures.com`** — not CC0 (restrictive custom license).

**Use PBR in Roblox:** `SurfaceAppearance` (per-mesh) or `MaterialVariant` (reusable tiling) with 4 maps — **ColorMap, NormalMap (OpenGL convention), RoughnessMap, MetalnessMap**.

**HDRI → Skybox:** Roblox needs **6 cube faces** (no equirect input). Convert a panorama with **HDRI-to-CubeMap** (`matheowis.github.io/HDRI-to-CubeMap`), export faces ~1024px, insert a `Sky` under `Lighting`, and map: **PX→`SkyboxFt`, NX→`SkyboxBk`, NZ→`SkyboxLf`, PZ→`SkyboxRt`, NY→`SkyboxUp`, PY→`SkyboxDn`**; use `SkyboxOrientation` to aim the sun.

**Storybook picks:** Poly Haven **Sunrise/Sunset** + **Overcast** sky HDRIs; matte **fabric/felt/clay** materials (ambientCG/cgbookcase) via `MaterialVariant` for a soft, plush, non-shiny look.

## 4. Audio, fonts, UI, VFX

- **Audio:** **Roblox Audio Library first** (cleared, no risk). External CC0 (Kenney Interface Sounds, Freesound-CC0, Pixabay, Mixkit, Sonniss GDC) only for audio you can legally upload — **note: self-uploaded external audio often fails Roblox's copyright detector.** Upload limits: 2,000/30d (ID-verified) or 100/30d; ≤7 min; mp3/ogg/wav/flac; private by default.
- **Fonts:** Roblox uses asset-id `FontFace` (legacy `Enum.Font` frozen). Built-in/Creator-Store fonts incl. **Fredoka One, GothamRounded**. **Google Fonts** are mostly **SIL OFL** — embeddable in a game (keep the license file; don't reuse the Reserved Font Name). Rounded/friendly picks: **Fredoka, Baloo 2, Quicksand, Nunito**.
- **UI / icons:** **Kenney UI Pack + Game Icons = CC0** (no credit). **game-icons.net = CC-BY 3.0** (credit required, 4,000+ icons).
- **VFX:** Roblox particle docs (`create.roblox.com/docs/effects/particle-emitters`); **Kenney Particle Pack = CC0** textures. For soft glow: `LightEmission ≈ 1`, pastel `Color` sequence, small `Size` easing to 0.

## 5. Roblox import quick-reference

- **3D Importer formats:** `.fbx` (rigged/animated), `.obj` (static), `.glb` (textures bundled).
- **Tri budget:** ≤ ~20,000 tris/mesh (single-import ~21k, batch ~10k). CC0 low-poly packs are well under — decimate/split anything heavier.
- **Materials:** **one texture atlas per mesh** — merge multi-material models or split into MeshParts.
- **Texture resolution:** standalone image uploads (Decal/Texture) effectively **downscale to 1024²**; the **SurfaceAppearance/MeshPart pipeline supports up to 4096² (4K)**.
- **Scale:** imports often come in wrong-sized (meters vs studs) — **rescale after import** against the stud grid.

## 6. Lowest-friction "zero-attribution" stack (recommended default)

Roblox **Audio Library** · **Synty / Kenney / Quaternius / KayKit** CC0 meshes · **Poly Haven / ambientCG** CC0 textures + sky HDRIs · **built-in Materials + MaterialVariants** · **Google Fonts (OFL)** · **Kenney** CC0 UI/icons/particles.
→ Add **game-icons.net** (CC-BY) or **Incompetech** music (CC-BY) only if you maintain a credits screen.

## 7. Attribution tracking

If you use any **CC-BY / CC-BY-SA** asset, log it in a `docs/CREDITS.md` and surface it on an in-game credits screen. CC0 assets need no entry.

---

## 8. Application — Squishy Smash (Pudding Hills storybook look)

Backbone = **native parts + the existing storybook lighting** (it already matches the soft, rounded card style and has zero licensing friction), with **CC0 props as accents** and optional **AI-generated hero pieces**.

| World element | Plan |
|---|---|
| **Sky** | Poly Haven **Sunrise/Sunset** or **Overcast** HDRI → skybox (or enhance the current procedural pastel sky) |
| **Ground & cream-bowl hills** | Native SmoothPlastic + custom **pastel matte `MaterialVariant`** (felt/clay from ambientCG/cgbookcase) |
| **Orchard / trees / mushrooms** | **Quaternius Stylized Nature MegaKit** or **Synty Nature**, recolored pastel |
| **Dessert props** | **Kenney Food Kit** (puddings, sweets) — on-theme for Pudding Hills |
| **Syrup river** | Native parts + glossy/Neon-tinted `MaterialVariant` + soft liquid texture; thins to a trickle at the Goo Coast border (canon) |
| **The Sparkle** | Neon part + `PointLight` + **Kenney Particle Pack** sparkle texture (`LightEmission ≈ 1`) high in the sky |
| **Cozy structures** | Synty City props (cream cottage hub, bridge, lamps) recolored pastel |
| **Audio** | Roblox Audio Library — soft pop (Happy Pop), sparkle/chime (capsule, coins), boop (buttons) |
| **Fonts** | Fredoka / Baloo 2 (already using FredokaOne) |

Later zones reuse the same kit, recolored: **Goo Coast** = mint/aqua glossy; **Moonlit Hollow** = lavender/silver (Quaternius mushrooms shine here), soft moonlight.

---
*Catalog v1 — 2026-06-08. Sources verified ~June 2026 via parallel research agents.*
