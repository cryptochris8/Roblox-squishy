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
  SparkleBitConfig.lua     the 26 hidden Sparkle Bit spots across all 3 lands (shared: client renderer + server validator)
  WeeklyConfig.lua         Friend of the Week: UTC week index + the coin price of befriending the visitor
  VariantConfig.lua        duplicate→variant tiers (Sparkly/Rainbow): names, colours, bonus coins
  DailyQuestConfig.lua     rotating daily-quest templates + forDay(dayIndex)
  ZoneConfig.lua           the 3 lands: pack/capsule/center/spawn/shard goal + unlock chain
  SocialConfig.lua         Phase C tunables: Sparkle Surge meter, Everybody Squish event, leaderboards
  CosmeticsConfig.lua      Sparkle Boutique catalog (hats/trails/balloons, coin prices, builder hints)
  GiftConfig.lua           Gifting v1 tunables: coin presets, daily gift limit, prompt/send ranges
  Remotes.lua              RemoteEvent names + setupServer/get
src/ServerScriptService/Server/   (server-authoritative)
  Main.server.lua          entry: setup remotes, init services, build world, wire prompts + hooks
  PlayerDataService.lua    per-player profile (coins, discovered, variants, sparkle bits, shard quest, daily/streak) + leaderstats; DataStore load/save/autosave + BindToClose flush
  WorldService.lua         builds all 3 lands, bespoke each — Pudding Hills (river/orchard/cottage VILLAGE/windmill/garden/picnic/treats), Goo Coast (goo sea/pier/tide-pools/sandcastle/lighthouse/huts/cove), Moonlit Hollow (moonpool/mushroom grove/mushroom cottages/stargazing circle/lanterns/log/fireflies); 12 friend pads per land SPREAD radius ~10-90 (3-pad starter cluster at spawn, pockets behind/beside landmarks) + wayfinding paths (caramel ribbons / boardwalk planks / glowing stepping stones); each land has its own capsule, guide, shard pedestal + travel hub
  SquishService.lua        spawns each land's pack friends on its pads; squish -> Joy -> Happy Pop -> coins -> respawn
  CapsuleService.lua       per-land Sparkle Capsule (tryOpen(player, capsuleKey, free)): weighted rarity, discover, duplicate→variant; onOpened hook
  CollectionService.lua    Equip Buddy (validated, toggles on/off)
  TutorialService.lua      "wake up 3 sleepy friends" quest -> 100 coins
  BuddyService.lua         spawns the equipped friend as a floating companion that follows you
  QuestService.lua         The Lost Sparkle quest — one shard per land (clue -> wake N -> shard appears -> recover -> next land opens); all 3 -> finale hook
  SparkleBitService.lua    validates + awards hidden Sparkle Bit pickups (range-checked); onCollected hook
  DailyService.lua         free daily capsule; rotating daily quests (noteEvent) + gentle login streak (onJoin); refreshes Sparkle Bits each day
  TravelService.lua        teleports between lands via Travel Pads, gated by shard progress
  FinaleService.lua        all 3 shards -> Restore the Sparkle (one-time +coins, brightens the world Sparkle orb); announces it server-wide
  SurgeService.lua         server-wide Sparkle Surge meter: every Happy Pop fills it (goal scales w/ player count) -> 60s of x2 coins for everyone
  GroupEventService.lua    "Everybody Squish!": every ~7min golden friends appear at the busiest land; shared goal -> +coins for all online
  LeaderboardService.lua   OrderedDataStore boards ("Top Friend Finders" / "Joy Champions") on physical signs at the Pudding Hills travel hub
  BoutiqueService.lua      the Sparkle Boutique stall (Pudding Hills, near spawn): validated coin-only buy/equip of buddy cosmetics; auto-wear on purchase
  WeeklyService.lua        Friend of the Week: a visiting tent by the travel hub; one of the 8 event friends rotates in weekly; Befriend = known coin price (never random), full card reveal
  CodeService.lua          storybook "magic words" (promo codes; table is SERVER-side only): one-time coin gifts, normalized input, per-player redemption persisted
  GiftService.lua          Gifting v1: 🎁 prompt on every player's character; give preset coins or SHARE a discovered friend (recipient gets discovery + reveal, GIVER KEEPS THEIRS); daily limit + range + cooldown validated server-side; shout-out on gift
  SquishyModelFactory.lua  every friend's real 3D shape: ~17 part-built archetypes (dumpling/bun/cube/bunny/bat/ghost...) + hand-tuned skins for all 48 launch friends (+8 weekly); HatOffset attr; applyGolden()
src/StarterPlayer/StarterPlayerScripts/   (client; runs once, respawn-safe)
  ClientController.client.lua   boots UI, routes server messages
  UiTheme / HudUI / CollectionBookUI / CapsuleRevealUI / ToastUI / SquishFx
  SparkleBits.lua          renders + detects the player's uncollected Sparkle Bits (server-validated pickup)
  DailyUI.lua              "Today's Quests" panel: gentle streak + 3 daily quests with progress bars
  FinaleUI.lua             the "Restore the Sparkle" celebration (shown when all 3 shards are recovered)
  SocialUI.lua             shared-world HUD: Surge meter pill (left column) + "Everybody Squish" banner with countdowns
  BoutiqueUI.lua           the Sparkle Boutique shop panel (price/owned/"Wearing ✓" states, gentle buy confirm)
  CodesUI.lua              the "Magic Words" panel (type a storybook code; feedback arrives as a toast)
  GiftUI.lua               the gift picker (coin presets + share-a-friend card grid, picture confirm, "N gifts left" pill) + the 🎁 "gift arrived" pop; hides your own GiftPrompt locally
```

### Contract (server <-> client)

- Remotes: c->s `RequestInitialState`, `EquipBuddyRequest`, `CollectSparkleBit`,
  `ClaimDailyCapsule`, `BuyCosmetic`, `EquipCosmetic`, `RedeemCode`, `VisitRoom`,
  `PlaceRoomItem`, `CollectStoryPage`, `SendGift` (recipientUserId, "coins"|"friend",
  amount|defId), `ResetProgress` (owner-only),
  `OwnerDebug` (owner-only: "startEvent"/"startSurge" demo triggers, with HUD
  buttons next to Reset); s->c `StateSync`, `SocialSync` (surge meter + event
  slices, with seconds-remaining), `OpenBoutique`, `OpenRoomCatalog`,
  `StoryPageCollected`, `OpenGiftUI` (recipient + their discovered set + gifts
  left today), `GiftReceived` (coin gifts; friend shares arrive as a
  `CapsuleResult` carrying `giftFrom`), `SquishResult`, `CapsuleResult`,
  `SparkleBitCollected`, `SparkleRestored`, `Toast`.
- The `StateSync` snapshot carries: coins, discovered (+count), variants,
  sparkleBits, shards (per-land {progress, collected}), tutorial, dailyCapsuleReady,
  daily (streak + quests), sparkleRestored.
- Input is server-side: `ClickDetector.MouseClick` (squish) and
  `ProximityPrompt.Triggered` (capsule + guide) fire on the server. Hidden Sparkle
  Bits are client-rendered per-player, but the pickup award is server-validated
  (range-checked).
- Card art lives in `CardImageAssets.lua` (friend Id → uploaded Image id), merged
  over the `REPLACE_ME` defaults by `SquishyData`. **All 48 launch friends now have
  real card art** (the `final_48` trading cards, uploaded 2026-06-09); a friend with
  no id still falls back to a coloured placeholder. Upload pipeline + decal→image-id
  provenance: `tools/card_art/`.

### Not in MVP yet (deliberately)

Cross-server gifting (v1 is same-server walk-up only; a mailbox pattern can
ride on the session locks later), TRADING of any kind (gifts only — sharing a
friend never costs the giver theirs, so nobody can be talked out of their
collection), and any monetization (Phase D — no Game Passes / Developer
Products; **Sparkle Capsules stay FREE by design**, to avoid the Paid Random
Items policy that restricts our 6–9 audience). *(Earlier gaps now closed: all 48 friends have real trading-card
art; Phase C co-op/social shipped 2026-06-09; and every friend has a real
part-built 3D shape via SquishyModelFactory — no more placeholder balls.)*

### Build status

Phases A (quest + exploration), B (collection depth + daily loop), E (all three
lands + travel + the Restore-the-Sparkle finale), and C (shared & social) are
implemented, playtested in Studio, and pushed to GitHub. The game is
**solo-completable end to end** and now has a shared-world layer that scales with
player count: the server-wide Sparkle Surge meter (x2 coins when the server fills
it), the "Everybody Squish!" golden-friend co-op event, cross-server leaderboards
at the Pudding Hills hub, show-off buddy tags (owner name + ✨/🌈 variant badge +
aura), and server-wide shout-outs for discoveries/shards/the finale. Phase C is
solo-verified; the four-player family playtest is its real multiplayer validation
(see `docs/12_PLAYTEST_CHECKLIST.md`). The **Sparkle Boutique** (2026-06-09) adds
the first coin sink + Phase D groundwork: buddy cosmetics (hats/trails/balloons)
bought with EARNED Sparkle Coins only, auto-worn on purchase, persisted, and
visible to everyone — the same system later sells premium cosmetics if/when Robux
products are priced. **Gifting v1** (2026-06-11) adds the first
player-to-player kindness loop: a 🎁 prompt on every player — give preset
Sparkle Coins or SHARE a discovered friend (recipient gets the discovery +
a "💝 A gift from …!" card reveal; the giver keeps theirs), 5 gifts/day,
picture confirm, server-validated end to end, same-server only. Solo-verified
in Studio; the family playtest is its real multiplayer validation. Next:
Phase D (monetization — needs pricing/business calls).
See `docs/11_GAMEPLAY_V2_DESIGN.md` for the roadmap.
**Changes are synced to Studio + git but go live in the published game only after
File → Publish (Alt+P), a creator-only action.**
