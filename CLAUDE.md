# Squishy Smash Roblox — Claude Code Master Instructions

You are helping build **Squishy Smash** as a wholesome Roblox game using Rojo + Roblox Studio + local files.

Read these files before coding:

1. `docs/00_START_HERE.md`
2. `docs/01_UNIVERSE_CANON.md`
3. `docs/02_KID_FRIENDLY_RULES.md`
4. `docs/03_ROBLOX_GAME_DESIGN_MVP.md`
5. `docs/04_CHARACTER_DATA_AND_ROSTER.md`
6. `docs/05_COLLECTION_AND_CAPSULE_SYSTEM.md`
7. `docs/06_UI_AND_CARD_STYLE_GUIDE.md`
8. `docs/07_IMPLEMENTATION_TASK_LIST.md`
9. `docs/08_ASSET_IMPORT_AND_PLACEHOLDER_PLAN.md`
10. `docs/09_FUTURE_ROADMAP.md`

Use the JSON data in `data/raw/` as the official character/card source of truth. Use the sample card images in `assets/card_samples/` as the visual reference for card UI. Use `generated_lua/` as a starting point for Roblox ModuleScripts.

## Non-negotiable creative rule

Squishy Smash is kid-friendly and storybook-safe. Build around squish, squeeze, bounce, boop, pop, sparkle, discover, collect, decorate, help, and friendship.

Do **not** build combat, weapons, horror, vulgarity, romance/dating, blood, gore, or mature content.

## First MVP goal

Build a playable local Roblox prototype with Pudding Hills starter zone, simple squishy interaction, Sparkle Coins, Collection Book, capsule reveal, official 48-card launch roster, placeholder Roblox models, card image asset placeholders, no Robux purchases yet, no Open Cloud automation yet, and no automatic publishing.

## Terminology replacements

Use player-facing language like:

- `Joy Meter`, not health
- `Squish Power`, not attack power
- `Happy Pop`, not defeat/burst
- `Squishy Friends`, not enemies
- `Play Zone`, not arena/battle zone
- `Discovered`, not won/pulled

Internally, old JSON fields such as `burstSound` or `burstThreshold` may remain for compatibility, but player-facing UI should use the softer terms above.

---

## Current Build (Pudding Hills MVP)

Active Rojo project at the repo root (`default.project.json`, name `SquishySmash`).
Run `rojo serve` from `D:\Roblox`, connect the Rojo plugin in Studio (Edit mode),
then Play. The earlier QB1 football prototype is preserved on git branch/tag
`qb1-prototype` and under `archive/qb1/`.

### File map

```
src/ReplicatedStorage/Shared/
  SquishyDefinitions.lua   generated 56-friend data (48 launch + 8 event) — source of truth
  RarityConfig / PackConfig / CapsuleConfig   generated configs
  SquishyData.lua          query helpers (getById/getByPack/getByZone/getByRarity/getLaunchRoster)
  GameConfig.lua           kid-friendly tunables (Joy per squish, tutorial, starters)
  Remotes.lua              RemoteEvent names + setupServer/get
src/ServerScriptService/Server/   (server-authoritative)
  Main.server.lua          entry: setup remotes, init services, build world, wire prompts
  PlayerDataService.lua    per-player profile (coins, discovered, totals) + leaderstats; DataStore = TODO
  WorldService.lua         builds Pudding Hills (ground, hills, capsule, guide, pads)
  SquishService.lua        spawns friends; squish -> Joy -> Happy Pop -> coins -> respawn
  CapsuleService.lua       Sparkle Capsule: weighted rarity, discover, Friendship Bonus (server RNG)
  CollectionService.lua    Equip Buddy (validated)
  TutorialService.lua      "wake up 3 sleepy friends" quest -> 100 coins
src/StarterPlayer/StarterPlayerScripts/   (client; runs once, respawn-safe)
  ClientController.client.lua   boots UI, routes server messages
  UiTheme / HudUI / CollectionBookUI / CapsuleRevealUI / ToastUI / SquishFx
```

### Contract (server <-> client)

- Remotes: c->s `RequestInitialState`, `EquipBuddyRequest`; s->c `StateSync`,
  `SquishResult`, `CapsuleResult`, `BuddyEquipped`, `Toast`.
- Input is server-side: `ClickDetector.MouseClick` (squish) and
  `ProximityPrompt.Triggered` (capsule + guide) fire on the server.
- Card art uses `def.ImageAssetId` (currently `rbxassetid://REPLACE_ME`); the UI
  falls back to a coloured placeholder until real image asset ids are pasted into
  `SquishyDefinitions.lua` (see `docs/08_ASSET_IMPORT_AND_PLACEHOLDER_PLAN.md`).

### Not in MVP yet (deliberately)

DataStore save/load, Goo Coast + Moonlit Hollow zones, buddy follower models,
3D character meshes, and any monetization (no Game Passes / Developer Products).
