# 07 — Implementation Task List for Claude Code

## Phase 1 — Project structure

Verify Rojo structure. Create folders for ReplicatedStorage, ServerScriptService, StarterGui, StarterPlayerScripts, and Workspace placeholders. Copy or adapt generated modules from `generated_lua/`.

Suggested structure:

```text
src/
  ReplicatedStorage/
    Shared/
      SquishyDefinitions.lua
      RarityConfig.lua
      PackConfig.lua
      CapsuleConfig.lua
    Remotes/
  ServerScriptService/
    Main.server.lua
    PlayerDataService.lua
    SquishyService.lua
    CapsuleService.lua
    CollectionService.lua
  StarterPlayer/
    StarterPlayerScripts/
      ClientController.client.lua
  StarterGui/
    SquishyHUD.client.lua
    CollectionBook.client.lua
```

## Phase 2 — Shared data

Use `SquishyDefinitions.lua`. Add helper functions: getById, getByPack, getByZone, getByRarity, getLaunchRoster.

## Phase 3 — Player data

Create SparkleCoins, TotalSquishes, TotalHappyPops, CardsDiscovered. Use leaderstats plus server table for early testing.

## Phase 4 — Pudding Hills prototype

Create simple Pudding Hills area, spawn points, capsule machine placeholder, Soft Dumpling guide placeholder, and 3–5 squishy friends.

## Phase 5 — Squish interaction

Add click/tap detector or ProximityPrompt, Joy Meter, Happy Pop reward, respawn delay, and squash/stretch tween.

## Phase 6 — HUD

Show Sparkle Coins, Total Squishes, and Squishy Book button.

## Phase 7 — Collection Book

Grid all 48 launch cards, show locked/unlocked display, card detail modal, and placeholder image asset IDs.

## Phase 8 — Capsule system

Add capsule prompt, charge Sparkle Coins, choose card by rarity, add to discovered collection, show reveal UI, and handle duplicates as Friendship Bonus.

## Phase 9 — Save data

After local systems work, add DataStore save/load with safe retry/error handling.

## Do not add yet

Robux products, trading, Open Cloud automation, auto-publishing, or all 48 custom 3D models.
