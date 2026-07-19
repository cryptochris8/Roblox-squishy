# Squishy Smash — Coin Economy Model (WO-0.1)

*Built 2026-07-18 per `docs/14_FUN_UPGRADE_DIRECTIONS.md` §5 WO-0 item 1. Every
number below comes from the live source files (cited `file:line`, paths relative
to the repo root). The runnable calculator is `docs/economy/economy_model.py`
(stdlib Python; `python economy_model.py` reprints every table here). When a WO
tunes a value, change it in BOTH files — the script is the calculator, this md
is the citation + rationale layer.*

**Verdict up front:** projected top-end income is **x1.10** of today's top-end
(8,876 vs 8,078 coins/30 min) — **PASSES** the WO-0 acceptance bar of ≤ ~x1.5,
with the plan's own caps (chain +5 flat, weather-vs-surge take-the-max,
co-squish never chains twice, endgame bit pool rotated to ~12/day).

---

## 1. Faucet inventory (every coin source, as built today)

### Recurring faucets

| Faucet | Coins | Source | Notes / rate driver |
|---|---|---|---|
| Happy Pop | `def.CoinReward` (8–140) | `src/ServerScriptService/Server/SquishService.lua:145` | The core faucet. Per-friend values in `src/ReplicatedStorage/Shared/SquishyDefinitions.lua` — see the rarity table below. |
| Golden pop (Everybody Squish) | pop x3 | `SquishService.lua:146-148` × `src/ReplicatedStorage/Shared/SocialConfig.lua:31` (`EventGoldenCoinMultiplier = 3`) | Golden friends spawn ~every 7 min (`SocialConfig.lua:25`), goal 4 pops/player (`:27`). |
| Everybody Squish success gift | 150 to everyone online | `SocialConfig.lua:32`, paid at `src/ServerScriptService/Server/GroupEventService.lua:103` | ~3 events per 30 min possible (420 s interval, 180 s first delay). |
| Sparkle Surge | x2 all coin awards, 60 s | `SocialConfig.lua:17-18`; multiplier at `src/ServerScriptService/Server/SurgeService.lua:33-35` | Fills at 15 pops/player (`SocialConfig.lua:14-16`, clamp 15–90). Applied only via `SquishService.coinMultiplier` (`src/ServerScriptService/Server/Main.server.lua:99-101`) — **pops only**, not quests/bits. |
| Coin Boost pass | x1.25 pop stream | `src/ReplicatedStorage/Shared/MonetizationConfig.lua:51` | Multiplies WITH surge (x2.5 max today, `Main.server.lua:97-101`). |
| Sparkle Bit | 25 each | `src/ReplicatedStorage/Shared/GameConfig.lua:29` | 26 bits across 3 lands (`src/ReplicatedStorage/Shared/SparkleBitConfig.lua:16-48`); **reset every UTC day** (`src/ServerScriptService/Server/DailyService.lua:79`). |
| All-bits bonus | 300 | `GameConfig.lua:30` | Per day (bits reset daily) — today's endgame bit route = 26×25+300 = **950/day**. |
| Daily quests | 35–70 each, 3/day | `src/ReplicatedStorage/Shared/DailyQuestConfig.lua:15-19` (pool 50/45/35/60/70, avg 52), awarded `DailyService.lua:50` | Rotating 3-of-5 window (`DailyQuestConfig.lua:24-31`); possible daily sums 130–180, avg 156. |
| Login streak | 20 + 10/day, caps day 7 (= 80) | `GameConfig.lua:36-38`, math at `DailyService.lua:80-82` | Day 1 = 20, day 5 = 60, day 7+ = 80. Resets to day 1 on a miss (WO-3.1 will fix the framing, not the coin ramp). |
| Free daily capsule | 0 coins (a discovery) or dupe coins | `DailyService.lua:87-99` (opens `StarterCapsule` free) | Dupe → variant bonus below. |
| Capsule duplicate → variant | +30 Sparkly / +60 Rainbow / +25 maxed | `src/ReplicatedStorage/Shared/VariantConfig.lua:16-17,21`, applied `src/ServerScriptService/Server/CapsuleService.lua:102-115` | Partially refunds the 100-coin open (net cost 40–75). |

### One-time faucets (lifetime totals)

| Faucet | Coins | Source |
|---|---|---|
| Tutorial ("wake 3 sleepy friends") | 100 | `GameConfig.lua:19-20`, paid by TutorialService |
| First Day checklist (5 steps) | 20+0+30+30+50 = 130 | `src/ReplicatedStorage/Shared/FirstDayConfig.lua:22-26` |
| First capsule free | (saves 100) | `GameConfig.lua:44`, `CapsuleService.lua:86-88` |
| Shard quests (per land) | 150 / 250 / 400 = 800 | `src/ReplicatedStorage/Shared/ZoneConfig.lua:60,73,85`, paid `src/ServerScriptService/Server/QuestService.lua:172` |
| Finale (Restore the Sparkle) | 1,000 | `GameConfig.lua:41`, paid `src/ServerScriptService/Server/FinaleService.lua:56` |
| Story pages | 18 × 25 + 300 = 750 | `src/ReplicatedStorage/Shared/StoryPageConfig.lua:15-16` (18 pages `:18-40`) |
| Magic words (5 codes) | 150+150+200+250+300 = 1,050 | `src/ServerScriptService/Server/CodeService.lua:18-24` (server-side only) |
| **Lifetime one-time total** | **3,830** (+100 saved) | |

### Happy Pop expected value (the number everything hangs on)

Pads pick uniformly from the land's 16-friend pack (`SquishService.lua:38-44`),
so EV = sum(CoinReward)/16. Tallied from `SquishyDefinitions.lua` (sample cites:
common 8 at `:20`, rare 16 at `:188`, epic 28 at `:272`, mythic 120 at `:335`,
Goo mythic 130 at `:671`, Moonlit mythic 140 at `:1007`):

| Pack (land) | 8 commons | 4 rares | 3 epics | 1 mythic | **EV/pop** |
|---|---|---|---|---|---|
| launch_squishy_foods (Pudding Hills) | 8–10 (sum 72) | 16–18 (sum 66) | 28–30 (sum 86) | 120 | **21.50** |
| goo_fidgets_drop_01 (Goo Coast) | 10–14 (sum 86) | 18–19 (sum 74) | 32–34 (sum 98) | 130 | **24.25** |
| creepy_cute_pack_01 (Moonlit Hollow) | 12–18 (sum 104) | 20–24 (sum 88) | 36 (sum 108) | 140 | **27.50** |

The mythic (1/16 spawn odds) skews the mean: the *median* pop is 9–13 coins,
but over 45+ pops the EV is the right estimator. The 8 event/weekly friends
(8–75 coins, e.g. `:1091`) and the Family Three (0 coins, `:1202`) never spawn
on pads, so they don't affect pop EV.

Not a faucet: **gifts** are redistribution, not creation — presets 25/50/100/250
(`src/ReplicatedStorage/Shared/GiftConfig.lua:15`), max 5/day (`:19`) → max
outflow 1,250/day per giver, zero net server-wide.

---

## 2. Sink inventory (every spend, as built today)

| Sink | Price | One-time? | Source |
|---|---|---|---|
| Sparkle Capsule open | 100 (net 40–75 after dupe return) | recurring | `src/ReplicatedStorage/Shared/CapsuleConfig.lua:10,17,24` |
| Weekly visitor befriend | 400 | 8 visitors → 3,200 lifetime | `src/ReplicatedStorage/Shared/WeeklyConfig.lua:11` |
| Boutique hats (6) | 150,150,200,250,250,400 | one-time each | `src/ReplicatedStorage/Shared/CosmeticsConfig.lua:38-49` |
| Boutique trails (4) | 250,300,300,600 | one-time each | `CosmeticsConfig.lua:52-58` |
| Boutique balloons (2) | 200,200 | one-time each | `CosmeticsConfig.lua:61-64` |
| **Boutique coin catalog total** | **3,250** | | (premium shelf is Robux, not coins — `:67-84`) |
| Room items (15 across 7 slot kinds) | 150–500 | one-time each | `src/ReplicatedStorage/Shared/RoomConfig.lua:49-72` |
| **Room catalog total** | **4,150** | | |
| Gifts sent | 25–250, ≤5/day | recurring (transfer) | `GiftConfig.lua:15,19` |

**Total lifetime coin sinks today ≈ 10,600** (3,250 + 4,150 + 3,200) plus
capsule opens. **The structural problem the plan fixes:** an endgame kid earns
~8,100/30-min session (below) and has *no recurring sink* once the catalogs are
bought out — coins pile up. The plan's shelf/swap/seeds/upgrade exist to absorb
exactly that surplus. (Side note: the comment at `CosmeticsConfig.lua:8-9`
— "a cozy session earns ~100-300 coins" — predates bits/quests/surge and is
~10–25x stale; worth updating whenever that file is next touched.)

---

## 3. Assumptions (everything not directly in a config file)

Sessions are 20–40 min (audience 6–9); all profiles model **30 min, solo**,
one session/day. Explicit assumptions:

1. **Pops/min while actively popping:** NEW 3, MID 4, ENDGAME 8. Mechanics
   allow far more (3 squishes/pop at 0.12 s cooldown, 1.2 s respawn, 12 pads —
   `GameConfig.lua:13-15`); these are kid-on-tablet paces.
2. **Minutes spent popping** (rest is travel/UI/bits/rides): NEW 15, MID 15,
   ENDGAME 20 → 45 / 60 / 160 pops per session.
3. **Land mix → pop EV:** NEW all Pudding (21.50); MID Pudding+Goo avg (22.88);
   ENDGAME Goo+Moonlit avg (25.88, the bit route crosses lands).
4. **Surge overlap** (share of pops inside x2 windows): NEW 10%, MID 20%,
   ENDGAME 40%. Mechanical ceiling for continuous solo popping at r pops/min is
   r/15 (15-pop goal, 60 s window): 20% / 27% / 53% — assumptions sit below it.
5. **Everybody Squish successes/session:** 1 / 2 / 3 (of ~3 possible). Value
   each = 150 gift + 4 golden pops × EV × 2 extra (the x3 minus the normal x1
   already counted in the pop total).
6. **Bits found:** NEW 4, MID 10, ENDGAME all 26 (+300). **Pages:** NEW 3,
   MID 2, ENDGAME 0 (all found; the 300 all-pages bonus is one-time, spent).
7. **Dailies completed:** NEW 1.5, MID 3, ENDGAME 3, at the 52-coin pool
   average. Streak day: 1 / 5 / 7+.
8. **Daily free capsule coin EV:** NEW 0 (a new discovery), MID +30 (typical
   Sparkly upgrade), ENDGAME +25 (maxed dupe).
9. Profiles exclude Robux passes; the Coin Boost x1.25 variant is shown as a
   footnote per profile (it multiplies only the SquishService pop stream).
10. **Projection-only assumptions:** chain average +1 / +2.5 / +4.5 per pop
    (cap +5); weather multiplier x1.5 active 20% of a session; garden yield =
    1.5x seed price; picnic 15, race 20, firefly 1 coin (counts per profile in
    the tables). Rotated bit pool ~12/day (WO-3.3) keeps the 300 all-found
    bonus per day.

---

## 4. The three 30-minute profiles — today and projected

Output of `python economy_model.py` (the md and script totals must always
match). "-" = 0. Projection additions marked `+`.

### NEW PLAYER (first session; Pudding Hills; tutorial + first capsules)

| Faucet | Today | Projected |
|---|---|---|
| Happy Pops (45 × 21.50 EV) | 968 | 968 |
| Sparkle Surge x2 overlap (10% of pops) | 97 | 97 |
| Everybody Squish events (1 × (150 + 4×21.5×2)) | 322 | 322 |
| Daily quests (1.5 × 52 avg) | 78 | 78 |
| Login streak (day 1) | 20 | 20 |
| Sparkle Bits (4 × 25) | 100 | 100 |
| Story pages, one-time (3 × 25) | 75 | 75 |
| One-time quest coins (tutorial 100 + First Day 130 + shard 150) | 380 | 380 |
| + Sparkle Chain (avg +1/pop, flat) | - | 45 |
| + Weather bonus (x1.5 on 20% of non-surge pops) | - | 87 |
| + Co-squish (solo: 0) | - | - |
| + Garden net (plants a 50-coin sprout, harvests tomorrow) | - | -50 |
| + Picnic circles (1 × 15) | - | 15 |
| + Slide races (1 × 20) | - | 20 |
| **TOTAL coins / 30 min** | **2,039** | **2,156** |
| **Ratio** | | **x1.06** |

Typical first-session spend: 2–3 capsule opens ≈ 200–300 (first is free,
`GameConfig.lua:44`) → ends day 1 holding ~1,700–1,850.

### MID-GAME (2 lands unlocked; dailies + bits; steady state)

| Faucet | Today | Projected |
|---|---|---|
| Happy Pops (60 × 22.88 EV) | 1,372 | 1,372 |
| Sparkle Surge x2 overlap (20% of pops) | 274 | 274 |
| Everybody Squish events (2 × (150 + 4×22.88×2)) | 666 | 666 |
| Daily quests (3 × 52 avg) | 156 | 156 |
| Login streak (day 5) | 60 | 60 |
| Sparkle Bits (10 × 25) | 250 | 250 |
| Story pages, one-time (2 × 25) | 50 | 50 |
| Free daily capsule (dupe EV, Sparkly +30) | 30 | 30 |
| + Sparkle Chain (avg +2.5/pop, flat) | - | 150 |
| + Weather bonus (x1.5 on 20% of non-surge pops) | - | 110 |
| + Co-squish (solo: 0; family +10–15% pops) | - | - |
| + Garden net (2 sprout cycles) | - | 50 |
| + Picnic circles (2 × 15) | - | 30 |
| + Slide races (2 × 20) | - | 40 |
| + Firefly wisps (10 × 1) | - | 10 |
| + Star Path chests (amortized/day) | - | 10 |
| **TOTAL coins / 30 min** | **2,859** | **3,259** |
| **Ratio** | | **x1.14** |

(Goo shard 250 and the finale 1,000 are one-time and excluded from the steady
state; a mid-game kid also spends ~100–300/day on capsules + saves toward the
400 weekly visitor.)

### ENDGAME (full book; memorized bit route; pops with surge windows)

| Faucet | Today | Projected |
|---|---|---|
| Happy Pops (160 × 25.88 EV) | 4,140 | 4,140 |
| Sparkle Surge x2 overlap (40% of pops) | 1,656 | 1,656 |
| Everybody Squish events (3 × (150 + 4×25.88×2)) | 1,071 | 1,071 |
| Daily quests (3 × 52 avg) | 156 | 156 |
| Login streak (day 7+) | 80 | 80 |
| Sparkle Bits (26 × 25 + 300 all-found) | 950 | **600** |
| Free daily capsule (dupe EV, maxed +25) | 25 | 25 |
| + Sparkle Chain (avg +4.5/pop, flat) | - | 720 |
| + Weather bonus (x1.5 on 20% of non-surge pops) | - | 248 |
| + Co-squish (solo: 0) | - | - |
| + Garden net (2 sprouts + amortized 5-day Bloom) | - | 80 |
| + Picnic circles (2 × 15) | - | 30 |
| + Slide races (2 × 20) | - | 40 |
| + Firefly wisps (20 × 1) | - | 20 |
| + Star Path chests (amortized/day) | - | 10 |
| **TOTAL coins / 30 min** | **8,078** | **8,876** |
| **Ratio** | | **x1.10** |

The Sparkle Bits row DROPS under the plan: WO-3.3 rotates ~12 of ~40 spots per
day (12×25 + 300 = 600 vs today's 950) — that planned right-sizing is what
keeps the top-end ratio low while the fun additions land.

**With the Coin Boost pass (x1.25 on the pop stream only):** today 2,348 /
3,362 / 9,682 → projected 2,487 / 3,790 / 10,543 (ratios x1.06 / x1.13 /
x1.09 — the bar holds with the pass too).

---

## 5. WO-0 acceptance check

> **Acceptance: post-upgrade top-end income ≤ ~1.5x current top-end.**

| Profile | Today | Projected | Ratio | ≤ x1.5? |
|---|---|---|---|---|
| NEW PLAYER | 2,039 | 2,156 | x1.06 | PASS |
| MID-GAME | 2,859 | 3,259 | x1.14 | PASS |
| **ENDGAME (top-end)** | **8,078** | **8,876** | **x1.10** | **PASS** |

**PASS** — with these required caps (they are what makes it pass; violating any
one re-opens the check):

1. **Chain bonus is FLAT and capped at +5**, added AFTER multipliers
   (`coins = floor(base * mult) + chainBonus`). If the chain rode the x2.5
   surge+boost stack it would be worth up to +12.5/pop → endgame +2,000
   instead of +720, pushing the ratio to ~x1.26 — still passing but wasteful.
   Keep it flat.
2. **Weather and Surge take the MAX, never stack.** At the recommended weather
   x1.5, weather only matters outside surge windows (worth ~3% of endgame
   income). If they stacked (x3, x3.75 with the pass), endgame gains another
   ~1,000 → ratio ~x1.23. Keep max-of. Weather multiplier must stay **< x2**
   or it would eclipse surge and make the surge meter feel pointless.
3. **Co-squish pays full to both but never chains twice** — per-player solo
   income is unchanged; in family sessions it adds ~10–15% pops per kid
   (contested friends now credit everyone), well inside budget.
4. **The endgame bit pool rotates to ~12/day** (WO-3.3) — the single biggest
   rebalance, −350/day at the top end.
5. **Garden yield stays ~1.5x seed price** — the garden is a *ritual*, not an
   income engine; at 1.5x it nets ≤ ~80/day. Anything ≥ 2x at Bloom scale
   starts competing with popping.

Headroom note: the bar allows up to ~12,100 projected (x1.5 × 8,078); the plan
as modeled uses 8,876, leaving ~3,200/30-min of headroom for WO-10's Sparkle
Saturday spotlight bonuses and seasonal treats — budget them within that.

---

## 6. Recommended prices for the plan's new sinks

Yardsticks from §4 (today's rates, 1 session/day): a mid-game kid banks
**~2,900/day**, an endgame kid **~8,100/day** (projected: 3,260 / 8,880).

| New sink | Recommended price | Rationale |
|---|---|---|
| Rotating Boutique shelf item (WO-3.6) | **450 / 550 / 600** per week's trio | Doc range is 300–600; skew HIGH — at mid-game rates 600 ≈ 21% of a day, so one shelf item is an easy weekly goal, and a kid who wants all three that week (~1,600) has a real but kind week-long goal. Below 400 they're impulse noise for an endgame kid. |
| Sparkle Swap (WO-3.7) | **250** (confirm the doc's number) | ~9% of a mid day — a deliberate treat, not a reflex. Its real job is the endgame: shining the full 48-book to Rainbow via swaps alone = 96 tiers × 250 = **24,000**, ~3 endgame play-days of purpose. Deterministic, capped at Rainbow (Starlight stays Bond-only per WO-4.5). |
| Sparkle Seeds (WO-5) | **Sprout 50** (1-day → 75) · **Berry Bloom 150** (3-day → 240) · **Rainbow Bloom 300** (5-day → 500 incl. decor roll) | Yield = 1.5–1.6x price so patience always pays but never out-earns play (net ≤ ~80/day, §5.5). Sprout at 50 means even a day-1 kid can plant before logging off — the come-back-tomorrow hook is priced for the 6yo's wallet. |
| Room catalog wave 2 (WO-3.11) | **250–500 per item** (6–8 items, catalog +~2,400) | Sits on top of today's 150–500 spread (`RoomConfig.lua:49-72`); wave-2 items are for kids who already bought wave 1, so start at 250, no 150 fillers. |
| Big room upgrade (WO-3.11) | **5,000** (top of the 3,000–5,000 range) | ≈ 1.7 mid-game days of TOTAL income (realistically a 1–2 week save at kid spending habits) — exactly the doc's "1–2-week coin goal." An endgame kid clears it in under a day, which is fine: it's the mid-game aspiration piece. If endgame surplus persists after WO-3/5 ship, add a second tier at ~12,000 rather than repricing this one. |
| Picnic/race/firefly | (faucets, priced in §3.10) | 15 / 20 / 1 — trickles that reward togetherness without moving the totals (< 1% each). |

Existing sinks stay as-is: capsule 100, weekly visitor 400 (≈ 14% of a mid
day — right for a weekly beat), Boutique 150–600, Room 150–500.

---

## 7. How to re-run / re-tune

```
cd C:\Users\chris\Roblox-squishy\docs\economy
python economy_model.py
```

- Tune a live value → edit the `CONSTANTS` block (and the game's Lua file);
  tune a plan value → the `PLAN` block; tune a session assumption → `PROFILES`.
- The script prints the three profile tables, the acceptance verdict, and a
  sink-affordability table (price ÷ daily income). Update §4–§6 here whenever
  the printed numbers change.
- Known data wart (from docs/14 §2): `RarityConfig` (55/25/12/6/2) and
  `CapsuleConfig`'s RARITY_WEIGHTS (50/26/14/7/3) diverge — **CapsuleConfig is
  live** (`CapsuleConfig.lua:5`). Capsule weights affect discovery odds, not
  coin income, so they don't enter this model; unify before touching capsule
  logic.
