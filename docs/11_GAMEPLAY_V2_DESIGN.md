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
- **Phase A — "The First Shard" (Pudding Hills):** spread the world + hide friends/secrets; the First Shard clue-quest (wake friends → shard appears at the orchard → recover → unlock Goo Coast); a quest HUD tracker. **← start here**
- **Phase B — Depth & return:** Collection Book hub (silhouettes + %); daily free capsule + daily quests + gentle streak; duplicate→variant (Sparkly/Rainbow) tier.
- **Phase C — Shared & social:** co-op "Everybody Squish" shard events; server-wide Restore-the-Sparkle meter; leaderboards; show-off buddies. (Migrate `PlayerDataService` → ProfileStore session-locking before trading.)
- **Phase D — Monetization:** cosmetics, passes, Friend-of-the-Week shop, (later) subscription — only once it's genuinely fun + retentive.

## Honest constraints
- Solo-dad cadence → favor **renewable/rotating systems** (daily/weekly/events) over hand-built content.
- **Validate each phase with the 3 daughters** (the focus group) before the next.
- Goo Coast & Moonlit Hollow are future zones; **Phase A ships the Pudding Hills quest + a Goo Coast teaser gate.**

## Free-asset usage
Per `docs/10_FREE_ASSET_SOURCES.md`: native parts + lighting first; CC0 props/Creator-Store as accents; Roblox built-in sounds for SFX; player-supplied Audio Library ids for music.

---
*Design v2 — 2026-06-08. Built from parallel research; see session notes.*
