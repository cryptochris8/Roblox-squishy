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

## Current Build (three lands — the full Lost Sparkle quest)

Active Rojo project at the repo root (`default.project.json`, name `SquishySmash`).
Run `rojo serve` from `C:\Users\chris\Roblox-squishy` on **port 34872** (Gnarly
Nutmeg — a separate game — serves on 34873; don't cross them), connect the Rojo
plugin in Studio (Edit mode), then Play. The earlier QB1 football prototype is
preserved on git branch/tag `qb1-prototype` and under `archive/qb1/`.

Three lands are built — **Pudding Hills** (center, ~origin), **Goo Coast** (x≈600),
and **Moonlit Hollow** (x≈1200) — on their own ground plates, connected by Travel
Pads. The place has **StreamingEnabled**, so a distant land only replicates to a
client once they're near it (to inspect a zone via Luau, teleport the character in
first, or check server-side).

### File map

```
src/ReplicatedStorage/Shared/
  SquishyDefinitions.lua   generated 56-friend data (48 launch + 8 event) — source of truth
  RarityConfig / PackConfig / CapsuleConfig   generated configs
  SquishyData.lua          query helpers (getById/getByPack/getByZone/getByRarity/getLaunchRoster)
  GameConfig.lua           kid-friendly tunables (Joy, tutorial, First Shard goal, Sparkle Bits, streak)
  SoundConfig.lua          background music + squish/Happy-Pop sound ids
  SparkleBitConfig.lua     the 10 hidden Sparkle Bit spots (shared: client renderer + server validator)
  VariantConfig.lua        duplicate→variant tiers (Sparkly/Rainbow): names, colours, bonus coins
  DailyQuestConfig.lua     rotating daily-quest templates + forDay(dayIndex)
  ZoneConfig.lua           the 3 lands: pack/capsule/center/spawn/shard goal + unlock chain
  Remotes.lua              RemoteEvent names + setupServer/get
src/ServerScriptService/Server/   (server-authoritative)
  Main.server.lua          entry: setup remotes, init services, build world, wire prompts + hooks
  PlayerDataService.lua    per-player profile (coins, discovered, variants, sparkle bits, shard quest, daily/streak) + leaderstats; DataStore load/save/autosave + BindToClose flush
  WorldService.lua         builds all 3 lands, bespoke each — Pudding Hills (river/orchard/cottage/treats), Goo Coast (goo sea/pier/tide-pools/sandcastle), Moonlit Hollow (moonpool/mushroom grove/log/fireflies); each with its own pads, capsule, guide, shard pedestal + travel hub
  SquishService.lua        spawns each land's pack friends on its pads; squish -> Joy -> Happy Pop -> coins -> respawn
  CapsuleService.lua       per-land Sparkle Capsule (tryOpen(player, capsuleKey, free)): weighted rarity, discover, duplicate→variant; onOpened hook
  CollectionService.lua    Equip Buddy (validated, toggles on/off)
  TutorialService.lua      "wake up 3 sleepy friends" quest -> 100 coins
  BuddyService.lua         spawns the equipped friend as a floating companion that follows you
  QuestService.lua         The Lost Sparkle quest — one shard per land (clue -> wake N -> shard appears -> recover -> next land opens); all 3 -> finale hook
  SparkleBitService.lua    validates + awards hidden Sparkle Bit pickups (range-checked); onCollected hook
  DailyService.lua         free daily capsule; rotating daily quests (noteEvent) + gentle login streak (onJoin); refreshes Sparkle Bits each day
  TravelService.lua        teleports between lands via Travel Pads, gated by shard progress
  FinaleService.lua        all 3 shards -> Restore the Sparkle (one-time +coins, brightens the world Sparkle orb)
src/StarterPlayer/StarterPlayerScripts/   (client; runs once, respawn-safe)
  ClientController.client.lua   boots UI, routes server messages
  UiTheme / HudUI / CollectionBookUI / CapsuleRevealUI / ToastUI / SquishFx
  SparkleBits.lua          renders + detects the player's uncollected Sparkle Bits (server-validated pickup)
  DailyUI.lua              "Today's Quests" panel: gentle streak + 3 daily quests with progress bars
  FinaleUI.lua             the "Restore the Sparkle" celebration (shown when all 3 shards are recovered)
```

### Contract (server <-> client)

- Remotes: c->s `RequestInitialState`, `EquipBuddyRequest`, `CollectSparkleBit`,
  `ClaimDailyCapsule`, `ResetProgress` (owner-only); s->c `StateSync`,
  `SquishResult`, `CapsuleResult`, `SparkleBitCollected`, `SparkleRestored`, `Toast`.
- The `StateSync` snapshot carries: coins, discovered (+count), variants,
  sparkleBits, shards (per-land {progress, collected}), tutorial, dailyCapsuleReady,
  daily (streak + quests), sparkleRestored.
- Input is server-side: `ClickDetector.MouseClick` (squish) and
  `ProximityPrompt.Triggered` (capsule + guide) fire on the server. Hidden Sparkle
  Bits are client-rendered per-player, but the pickup award is server-validated
  (range-checked).
- Card art uses `def.ImageAssetId` (currently `rbxassetid://REPLACE_ME`); the UI
  falls back to a coloured placeholder until real image asset ids are pasted into
  `SquishyDefinitions.lua` (see `docs/08_ASSET_IMPORT_AND_PLACEHOLDER_PLAN.md`).

### Not in MVP yet (deliberately)

Real 3D character meshes (buddies + world friends use placeholder squishy balls
with faces for now); real **card art for 40 of the 48 friends** (8 have uploaded
art, the rest show a coloured placeholder card — see
`docs/08_ASSET_IMPORT_AND_PLACEHOLDER_PLAN.md`); co-op / social (Phase C — needs
a multiplayer playtest); and any monetization (Phase D — no Game Passes /
Developer Products; **Sparkle Capsules stay FREE by design**, to avoid the Paid
Random Items policy that restricts our 6–9 audience).

### Build status

Phases A (quest + exploration), B (collection depth + daily loop), and E (all
three lands + travel + the Restore-the-Sparkle finale) are implemented, playtested
in Studio, and pushed to GitHub. The game is **solo-completable end to end**: three
distinct lands, a Sparkle shard per land, 48 friends across three free capsules,
and the finale. Next: Phase C (co-op/social — needs a multiplayer playtest) and
Phase D (monetization). See `docs/11_GAMEPLAY_V2_DESIGN.md` for the roadmap and
`docs/12_PLAYTEST_CHECKLIST.md` for what to watch with the girls. **Changes are
synced to Studio + git but go live in the published game only after File → Publish
(Alt+P), a creator-only action.**
