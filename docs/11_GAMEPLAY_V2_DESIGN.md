# 11 — Gameplay v2 Design: "The Lost Sparkle" (shared world, individual story)

*Created 2026-06-08. Evolves Squishy Smash from a flat click-loop into a shared,
explorable, quest-driven cozy collector that matches the storybook and is built to
retain + monetize ethically. Grounded in 2026 research (retention/algorithm,
kid-game design, Roblox monetization, comparable cozy/collector games).*

## North star
A wholesome **shared world** where kids explore Pudding Hills (then Goo Coast,
Moonlit Hollow), wake sleepy Squishy Friends, follow **clues to recover the 3 lost
Sparkle shards**, and restore the Sparkle — collecting a 48-friend Book and a buddy
along the way. **Solo-completable, better together.**

## Core pillars (anti-boredom for skilled young kids)
1. **Shared world, individual story** — persistent hub, per-player progress (DataStore). Solves the single-player-vs-Roblox-economics problem.
2. **Explore, don't just click** — spread-out world; friends + secrets hidden in clever spots ("I found one my sister missed").
3. **Layered goals** — *this minute* (fill a Joy Meter), *this session* (a daily quest / today's secret), *this week+* (find the shard, complete a world, restore the Sparkle).
4. **Collection as the hub** — 48-card Book with silhouettes + completion %; a duplicate→variant tier (Sparkly/Rainbow) for long-tail depth with no new art.
5. **Optional challenge, mandatory hints** — opt-in skill/puzzle layers serve the skilled 8-year-olds; gentle escalating hints protect the 6-year-old. Never gate the core kindness loop behind difficulty.
6. **Daily reasons to return** — free daily capsule, rotating daily quests, gentle streaks (pause, never hard-reset).
7. **Co-op + social** — group "Everybody Squish" shard events, a server-wide Restore-the-Sparkle meter, show-off buddies, leaderboards. (Later: careful gift/trade.)

## The quest spine — *The Lost Sparkle* (mirrors the book)
Per world (Pudding Hills → Goo Coast → Moonlit Hollow):
> get a **clue** → **wake** the sleepy friends → the **shard appears** at a landmark → **recover** it → that world's Sparkle is restored → the **next world unlocks**.

Three shards recovered → **"Everybody Squish!"** → the Sparkle shines bright again.

## Monetization (ethical, brand-safe) — NOT in MVP; cosmetics-first when enabled
- **KEEP SPARKLE CAPSULES FREE** (opened with *earned* coins only, never Robux). This avoids Roblox's **Paid Random Items** policy — which restricts our exact 6–9 audience (UK <18, AU <15, all of Belgium/Netherlands/Brazil) — and the "child gambling" brand risk.
- Monetize via **cosmetics** (buddy trails/auras, decorations, titles), **QoL/cosmetic Game Passes** (extra buddy slot, +25% coins, a "Sparkle Club"), a **non-random "Friend of the Week" direct-buy shop**, and (later) a subscription. **Sell speed & style, never power** — all 48 collectable F2P.
- The real revenue is **retention** (Roblox Creator Rewards) — a daily cozy habit beats impulse buys.

## Phased build plan
- **✅ Phase A — "The First Shard" (Pudding Hills) — DONE (2026-06-09):** spread world + hidden friends/secrets; the First Shard clue-quest (wake friends → shard appears at the orchard → recover → Goo Coast gate opens); quest HUD tracker; hidden Sparkle Bits exploration collectibles.
- **✅ Phase B — Depth & return — DONE (2026-06-09):** Collection Book hub (silhouettes + completion % + per-zone counts); duplicate→variant (Sparkly/Rainbow) tier; free daily capsule; rotating daily quests + a gentle login streak; hidden Sparkle Bits refresh daily.
- **✅ Phase C — Shared & social — DONE (2026-06-09, solo-verified):** the server-wide **Sparkle Surge** meter (every Happy Pop fills it; full = 60s of x2 coins for everyone); the **"Everybody Squish!"** golden-friend co-op event (~7min cadence at the busiest land, shared goal scaled by player count, everyone-online reward); cross-server **leaderboards** ("Top Friend Finders" / "Joy Champions") at the Pudding Hills hub; **show-off buddies** (owner-name tag + ✨/🌈 variant badge + particle aura) and server-wide discovery/shard/finale shout-outs. Everything scales 1→N players, so it was verifiable solo — *the 4-player family playtest is the real multiplayer validation.* (ProfileStore session-locking still pending before any gifting/trading.)
- **Phase D — Monetization — needs your decisions:** cosmetics, passes, Friend-of-the-Week shop, (later) subscription — only once it's genuinely fun + retentive. *Requires your pricing/business calls + Robux product setup + publishing.*

### Build log
- **2026-06-09 (the spread-out world — pillar 2 for real):** Chris called out
  that friends felt lumped together — and the numbers agreed (12 pads in an
  ~80×80 box on each 320×320 land). Every land now spreads its 12 friends from
  a 3-pad starter cluster at the spawn out to radius ~90, each pocket anchored
  to a landmark worth visiting: Pudding Hills grew a cottage village lane, a
  windmill field, a fenced flower garden, and a picnic clearing; Goo Coast got
  a candy-striped lighthouse, beach huts, umbrellas + towels, driftwood, a
  beached rowboat, and a rocky cove (one friend naps at the END of the pier);
  Moonlit Hollow got three mushroom cottages, a stargazing stone circle, and
  lantern posts. Wayfinding for the 6-year-old: caramel paths (Pudding),
  boardwalk planks (Goo), and glowing stepping stones (Moonlit) lead from each
  spawn to every pocket, and sleepy zZz labels now beckon from 90 studs (was
  70). Verified in Studio: 12 friends per land spread 6→92 studs, all
  structures present, paths readable at kid's-eye level, and the Everybody
  Squish event fired naturally at the busiest land mid-playtest.
- **2026-06-09 (real 3D shapes — goodbye placeholder balls):** SquishyModelFactory
  gives every friend a part-built body: ~17 squishy archetypes (dumpling, bun,
  mochi, cube, puff, rice ball, flan, blob, orb, pad, capsule, drop, pop-ball,
  bunny, bat, ghost, kitty, critter) hand-tuned per friend with name-true
  palettes — Strawberry Dumpling is strawberry-pink with a calyx knot, Frost Gel
  Cube is icy glass with a frost cap, Moon Bat Blob has wedge ears, wings, and a
  little neon moon. Buddies are the same shapes at companion scale (boutique hats
  sit at each shape's HatOffset). ClickDetectors moved to the model so ears are
  squishable; golden event friends recolor every part. SquishFx animations were
  reworked for multi-part models: whole-model breathing bob, a squish-spring via
  uniform scale, and a swell-and-fade pop. Verified in Studio: click-pop works,
  goldens glimmer fully, buddy wears its hat on the new shape, and all three
  lands' crowds read distinct at a glance.
- **2026-06-09 (Sparkle Boutique — cosmetics + the first coin sink):** A cute
  striped stall near the Pudding Hills spawn sells buddy cosmetics for EARNED
  Sparkle Coins (never Robux): 6 part-built hats (party hat, star clip, bow,
  flower crown, mushroom cap, tiny crown), 4 sparkle trails (bubbles, hearts,
  stars, rainbow), 2 balloons. One slot per type; buying auto-wears it; outfits
  persist and replicate (everyone sees them — show-off synergy with Phase C).
  Server-validated buy/equip (price, catalog, ownership, slot). This doubles as
  Phase D groundwork: the same system can sell premium cosmetics later once
  pricing is decided. Verified in Studio: exact charges, friendly rejection when
  short on coins, fuzz-safe remotes, persistence across sessions, walk-up-press-E
  shop open, and all three prop types rendered on the buddy.
- **2026-06-09 (Phase C — shared & social):** Sparkle Surge meter (SurgeService +
  a HUD pill in the left column), "Everybody Squish!" golden-friend event
  (GroupEventService: busiest-land pick, goal scaled by player count, success =
  +150 coins for everyone online, gentle timeout), OrderedDataStore leaderboards
  on physical boards flanking the Pudding Hills travel hub, buddy show-off tags
  ("🌈 Emily's Celestial Dumpling Core") with variant auras, and server-wide
  shout-outs (new discovery / shard recovered / Sparkle restored). Owner-only
  🌟 Event / ✨ Surge demo buttons beside Reset for demoing to the kids on cue.
  Also fixed a StreamingEnabled bug: friends' faces/labels now attach whenever a
  Body streams in (they used to vanish for streamed-in lands). All verified in
  Studio play (surge x2 math exact, event full arc + fail path, boards showing
  real names/values, buddy tag + aura live).
- **2026-06-09 (card art — all 48 friends):** Uploaded the finished `final_48`
  trading cards to Roblox and wired all 48 into `CardImageAssets.lua` (Open Cloud
  upload → resolve Decal→Image id in Studio → merge over the defs). The Squishy Book
  and capsule reveals now show real card art for every friend. The reusable pipeline
  (convert WebP→PNG, upload, the decal→image map) lives in `tools/card_art/`.
- **2026-06-09 (Phase E — the full world):** All three lands built and made
  *distinct* — Pudding Hills (cozy golden valley), Goo Coast (goo sea + wooden
  pier + tide-pools + sandcastle), Moonlit Hollow (reflective moonpool + giant
  glowing-mushroom grove + cozy log + fireflies) — each with its own pad layout,
  Sparkle Capsule, guide, and shard quest. Travel Pads link the lands (gated by
  shard progress). All 48 friends are obtainable across the three capsules. The
  three-shard chain culminates in the **Restore the Sparkle** finale. The game is
  solo-completable end to end. (Co-op/social and monetization are still Phases C/D.)
- **2026-06-09 (overnight autonomous build):** Phases A + B fully implemented, playtested in Studio, committed, and pushed to GitHub. All systems server-authoritative + DataStore-persisted. Capsules remain FREE (earned coins only). The game is solo-completable and now has daily reasons to return. **To play the new version in the live Roblox game, publish from Studio (File → Publish, Alt+P) — a creator-only action.**

## Honest constraints
- Solo-dad cadence → favor **renewable/rotating systems** (daily/weekly/events) over hand-built content.
- **Validate each phase with the 3 daughters** (the focus group) before the next.
- Goo Coast & Moonlit Hollow are future zones; **Phase A ships the Pudding Hills quest + a Goo Coast teaser gate.**

## Free-asset usage
Per `docs/10_FREE_ASSET_SOURCES.md`: native parts + lighting first; CC0 props/Creator-Store as accents; Roblox built-in sounds for SFX; player-supplied Audio Library ids for music.

---
*Design v2 — 2026-06-08. Built from parallel research; see session notes.*
