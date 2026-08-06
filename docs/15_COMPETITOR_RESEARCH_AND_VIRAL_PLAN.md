# 15 — Competitor Research & Viral Plan: the "Trade Squishy Dumplings" Response

_Researched and written 2026-08-06. Trigger: Chris's daughters were playing
**Trade Squishy Dumplings** (roblox.com/games/88480125732253), and Chris asked
for an honest comparison + what to change or add so Squishy Smash can go viral.
Method: live Roblox API stats + fan-wiki/press teardown + a code audit of our
own reveal/gift systems, then three design agents produced the full specs that
make up §5–§7 of this doc. This doc does **not** override doc 14 — the one Law
bend it proposes (§4) is Chris's decision, and doc 14 §1/§7 must be amended
before anyone builds it._

---

## 1. The competitor, measured (2026-08-06)

**Trade Squishy Dumplings** by SGR Studios (verified group, 2.6M members):

- Created **2026-05-24** — just 74 days old at research time.
- **50.9M visits** (~690K/day), 96.7% like ratio (101K up / 3.4K down),
  108K favorites, 25-player servers, near-daily updates (last: Aug 5).
- **Already collapsing:** all-time-peak CCU 26,914 (Jun 27) → 30d peak 15,155 →
  7d peak 8,760 → **~3,100 now (−87%)**. Average session: **11.9 minutes**.
- Loop: crate/shop pulls (Robux buys more pulls = paid randomness) → 6 rarity
  tiers (Common→Grail) + variants (Galaxy/Glitter/colour) + **mutations** (huge
  value multipliers) → **physical trade boards** (both drop items, ➕ requests
  more, both stand on ✅ to confirm).
- The actual growth engine: trading → a player-driven **value economy** → a
  content ecosystem that markets the game for free: a dedicated fan wiki
  (tradesquishydumplings.wiki: tier lists, values, scam guides), codes articles
  on Destructoid/GameRant/ProGameGuides/RobloxDen (codes launched July 2026 —
  they are a **press channel**, not a game feature), and TikTok discover pages
  full of trade/unboxing clips.
- **Scams are rampant** — their own wiki documents seven patterns (last-second
  switch, add-it-after, fake-mutation claims, pressure rush, off-board deals,
  phishing, trust trades). The only protection is a mutual-confirm button. No
  age gates, no parental anything, no in-game scam reporting.
- It's one of a **wave** mirroring the real-world blind-box toy craze (Labubu /
  Sonny Angel): Squishy Dumpling Unboxing (Mar 2026, 10M+ visits), Trade
  Dumplings, My Squishy Dumplings. The wave's games are individually burning
  down; the underlying "squishy collectible" toy trend is multi-year.

**Reference safeguards (Adopt Me, best-in-class):** Trade License picture quiz
(3 safe-or-scam questions) gates high-rarity trading; unlicensed players trade
low rarities only; 30-day trade history; in-game scam reporting. In-experience
item trading is platform-allowed for all-ages games.

**Discovery algorithm (2026):** Recommended-For-You weighs a 28-day retention
window, session length, D1/D7 retention, like ratio, and **"7-Day Intentional
Co-Play Days per User"** — bringing friends is a *measured* signal.
Up-and-Coming surfaces growth velocity **relative to a game's own baseline** —
the small-dev channel. Every marketing beat should stack on one weekend.

## 2. Honest head-to-head

**They win at:** the unboxing/trading ritual (the recordable moment), a
rankable value ladder (rarity × variant × mutation) that fuels wiki/tier-list/
TikTok content, discovery volume, and update-cadence energy.

**We win at:** an actual world (3 lands, rides, garden, quests vs. a trading
lobby), session-length potential (their 11.9 min is a ceiling; ours is a
floor), real 3D models + real card art for all 56 friends, a cross-media IP
(books, music, site), and ethics a parent can read. The 2026 algorithm rewards
exactly what we built (retention, co-play) — we're weak on what gets a kid in
the door, they're weak on what keeps her.

**Chris's question — "are we only missing a great reveal and trading?"**
Mostly yes on the *visible* gaps, with two corrections: (1) what trading
actually buys them is a **value economy + content ecosystem** — that's the
thing to capture, and it can be captured more safely than they did; (2) there's
a third, invisible gap — **discovery-metric plumbing** (time-to-first-reveal,
co-play hooks, codes-as-press, update rhythm) that determines whether any spike
ever compounds.

## 3. Confirmed bug found during grounding (fix first, ships with anything)

`CapsuleConfig.RARITY_WEIGHTS` = `{ common=50, rare=26, epic=14, mythic=7,
legendary=3 }`, but `RarityConfig` ranks **Mythic** as the top tier (SortOrder
5 > Legendary 4; RarityConfig's own aspirational weights agree: mythic 2 <
legendary 6). The live game hands out its top tier **more often than the tier
below it**. Fix: swap to `mythic = 3, legendary = 7` in CapsuleConfig (and per
the doc-14 landmine, unify the two weight tables to one source of truth while
in there). Verified 2026-08-06 against both files.

## 4. The one Law bend — Chris's decision, not yet made

Doc 14 §1 locks **"NO trading. Gifts only"** and §7 skip-lists "Trading, in any
form." The Switcheroo spec (§5) bends exactly one clause: a deposited **spare**
copy does leave the player's spare count. Everything the lock protects survives
mechanically: Discovered/Variants are structurally non-transferable, the last
copy is unswappable *by arithmetic* (it is not a spare), rarity is always
exact-matched, all seven known scam patterns are mechanism-deleted (no
counterparty in Phase 1 at all), and gifts stay exactly as they are. The open
negotiation board (where TSD's scams live) is recommended **permanently out of
scope** — if the bend is approved, write that refusal into doc 14 so a future
build agent doesn't "improve" it back in.

**If Chris approves:** amend doc 14 §1 to "No negotiated trading, ever. Swaps
move only SPARE copies, only through atomic rituals, and the collection itself
can never shrink." and update §7 accordingly.

## 5–7. The three full specs

Everything below is the design agents' full output (2026-08-06), verified
against the live codebase. Recommended build order:

1. **Reveal v2 ("The Wobble Count")** + the §3 weight fix + the D1 funnel fixes
   from the viral plan — zero uploads, mostly client-side, feeds TikTok LIVE
   immediately.
2. **Sparkle Patterns** — the collection-depth axis; gives the new reveal its
   escalation material and the Switcheroo its interesting inventory.
3. **Switcheroo Station Phase 1** — after the Law-bend decision.
4. **Codes/press/wiki/cadence** — marketing plumbing, runs in parallel
   (mostly not code).

<!-- FULL SPECS APPENDED BELOW BY EXTRACTION SCRIPT -->

---

## 5. FULL SPEC — CapsuleRevealUI v2: CapsuleRevealUI v2 — "The Wobble Count": a progressive-telegraph Sparkle Capsule ceremony built to be screen-recorded

# CapsuleRevealUI v2 — Design Spec ("The Wobble Count")

**Thesis.** The single most-recorded moment in every collector game is the reveal (the competitor's TikTok surface is 90% unboxing clips). Our current reveal leaks the answer in frame one (rarity-tinted capsule), plays one chime for every tier, and is over in 1.5 flat seconds. v2 replaces it with an honest, countable suspense mechanic: **the capsule starts pearl-neutral and every extra wobble means a better friend**. Wobble-counting is the chat-along hook — kids (and LIVE viewers) count out loud, and the moment wobble 3 becomes wobble 4, everyone screams. That's the clip.

Grounded against the live code: `CapsuleRevealUI.lua` (audited), `SquishFx.lua` (FX-budget + sound patterns to reuse), `CapsuleService.lua` (payload + `onOpened` hook), `Remotes.lua`, `SoundConfig.lua`, `RarityConfig.lua`, `VariantConfig.lua`, `CapsuleConfig.lua`, `UiTheme.lua`.

---

## 0. Data quirk found during grounding (fix first, 1 line)

`CapsuleConfig.RARITY_WEIGHTS` is `{ common=50, rare=26, epic=14, mythic=7, legendary=3 }` — **Legendary (3/100) is currently rarer than Mythic (7/100)**, but `RarityConfig.SortOrder` ranks Mythic (5) above Legendary (4), and SquishFx already celebrates by SortOrder. The ceremony must escalate with actual scarcity or the telegraph lies.

**Fix:** swap the two weights → `mythic = 3, legendary = 7`. Now hierarchy, scarcity, ceremony, and the odds page all agree: Mythic is the top tier AND the rarest pull. (Alternative — reorder SortOrder — touches the Book sort; don't.) The spec below assumes the swap.

---

## 1. The rarity leak fix — progressive telegraph

**Neutral start.** The capsule spawns **pearl** (`Color3.fromRGB(248, 244, 238)`) with a soft cream gradient and white stroke — identical for every tier at t=0. No `UiTheme.rarityColor` anywhere until the wobbles begin.

Three honest, monotone telegraph channels (all derived from the *actual* result — see Law section):

1. **Wobble count** = tier rank. Common 1, Rare 2, Epic 3, Legendary 4, Mythic 5. The suspense is "is it going to wobble AGAIN?" — you never know mid-wobble whether the next one comes. Countable = chantable = recordable.
2. **Glow bleed.** An under-glow (2 concentric soft circles behind the capsule) + the capsule's UIStroke lerp from pearl toward `UiTheme.rarityColor(result.rarity)` at fraction `i / wobbleCount` per wobble — light leaking from *inside* the shell. The shell itself stays pearl until the pop. Early wobbles are near-identical across tiers (faint tint); only the final wobble shows the full colour. The colour ramp common→mythic conveniently runs cool→warm (soft blue → periwinkle → purple → gold → sunset), so "warmer = wow" reads without words.
3. **Chime pitch ladder.** One chime per wobble, pitch rising per step via `PlaybackSpeed` on the existing `SoundConfig.Chime` — **zero new uploads**. Pitch for wobble *i*: `1.0 + (i-1) * 0.12` (so Mythic's 5th chime lands at 1.48). Implementation: clone the chime template per play (SquishFx `playSound` pattern + Debris) so chimes ring over each other instead of restarting.

**Never-overshoot rule:** the glow at any moment never exceeds the final tier colour, wobble count never exceeds the true rank, and no copy ever references a tier you didn't get. The ramp only ever tells the truth in slow motion.

---

## 2. Tier ceremony parameters (the `RevealConfig.Tiers` table)

Per rarity: `wobbles` / `wobbleDur` / `dim` / `rise` / `preBurstHold` / `cardStyle` / `totalToButtons`.

- **common** — 1 wobble · 0.22s · dim 0.35 · rise 0 · hold 0 · card pop-in · **~1.2s**
- **rare** — 2 wobbles · 0.24s · dim 0.45 · rise 0 · hold 0.12s · card pop-in + quick shine · **~2.2s**
- **epic** — 3 wobbles · 0.26s · dim 0.55 · rise 20px · hold 0.25s · card flip-in 0.45s + shine · **~3.6s**
- **legendary** — 4 wobbles · 0.28s · dim 0.70 · rise 60px · slow-mo inflate 0.5s · slow flip 0.8s + shine sweep + star rain · **~5.8s**
- **mythic** — 5 wobbles · 0.28s · dim 0.72 · rise 60px · slow-mo inflate 0.6s · slow flip 0.9s + ray wheel + double burst · **~6.4s**
- **family** — Legendary ceremony, heart-rose palette (`UiTheme.Rarity.family`), hearts fall instead of stars (used if a Family grant ever routes a `CapsuleResult` through this UI)

**Pacing modifier — already-known:** when `result.isNew == false` and no variant upgrade, cut every `preBurstHold` to 0 and card entry to pop-in regardless of tier (~30% shorter). Repeat-open cadence matters more than ceremony when you already know the friend; the coin count-up (below) is the payoff beat instead.

---

## 3. Shot-by-shot storyboards

All positions are inside the existing auto-fit `stage` (560×620 logical), so phones get this free. Every wait/tween runs on the skippable Timeline (§5).

### 3.1 COMMON — "the cozy quickie" (~1.2s to buttons)

- **0.00–0.18** Dim `TextButton` tweens `BackgroundTransparency 1 → 0.65` (0.35 dim). Pearl capsule (150px circle) drops in from y-28px, `Back/Out` 0.18s, tiny settle squash (scale-Y 0.94, 0.06s).
- **0.18–0.40** *Wobble 1:* Rotation `0 → +11° → −11° → 0` over 0.22s, Sine. Chime clone at pitch **1.0**, vol 0.5. Under-glow lerps pearl → common soft-blue (fraction 1/1), stroke tints.
- **0.40–0.48** Squash: scale-Y → 0.82 in 0.08s, `Quad/In`.
- **0.48–0.60** **Pop:** capsule size → 0 (`Back/In` 0.12s) + `RevealFx.burst(center, 12, commonBlue)` + one `HappyPopVariants` pick at pitch 1.15, vol 0.5.
- **0.60–0.90** Card pops in `Back/Out` 0.3s to 322×430 (current behavior — it's already good at this speed). Headline fades in above (0.15s): "New Friend Discovered!" / sub-line from `RarityConfig.common.KidFriendlyReveal` ("A cozy friend appeared!").
- **0.90–1.20** Buttons row rises in (Yay! + optional Open Another + "What's inside?" link). `canDismiss = true`.

### 3.2 RARE — "wait, again?" (~2.2s)

- **0.00–0.20** Dim → 0.45. Capsule drop-in as Common.
- **0.20–0.44** *Wobble 1:* ±11°, chime **1.0**, glow at 50% toward periwinkle.
- **0.44–0.68** *Wobble 2:* ±13°, chime **1.12**, glow at 100%, 6 tiny orbit sparkles start circling the capsule (RevealFx orbiters).
- **0.68–0.80** Held breath: 0.12s, glow breathes (transparency ±0.1 sine).
- **0.80–1.00** Squash → **pop**: `burst(22, periwinkle)` + delayed white after-burst `burst(8, white)` at +0.06s (SquishFx's rare double-pop pattern, on-screen). `ring()` pulse ×1. HappyPop pitch 1.1 + Chime 1.3 layered.
- **1.00–1.40** Card pop-in 0.3s + **quick shine sweep** 0.35s (UIGradient offset −1 → 1 across the card).
- **1.40–2.20** Headline + sub ("A sparkly friend appeared!"), buttons, `canDismiss`.

### 3.3 EPIC — "the room notices" (~3.6s)

- **0.00–0.25** Dim → 0.55 (deeper; the world visibly hushes). Capsule drop-in.
- **0.25–1.05** *Wobbles 1–3:* ±11°/±13°/±14°, chimes **1.0 / 1.15 / 1.30**, glow bleeds 1/3 → 2/3 → full purple; a `ring()` pulse fires on each wobble; orbit sparkles ramp 4 → 8 → 12.
- **1.05–1.25** Capsule floats **up 20px** (`Sine/Out` 0.2s) — it's levitating now.
- **1.25–1.50** Pre-burst hold 0.25s: glow breathing, orbiters tighten inward.
- **1.50–1.80** Squash → **pop**: `burst(36, purple)` + white after-burst + soft radial gold bloom frame (0.3s fade — the on-screen cousin of SquishFx's `goldFlash`). Layered ta-da: HappyPop 1.1 then second HappyPop 0.82 at +0.12s (exactly the SquishFx epic pattern, so the game's sound language stays coherent).
- **1.80–2.35** **Card flip-in 0.45s:** card X-size 0 → 322 with midpoint face swap (pearl card-back with a ✨ mark → real art), `Back/Out` on the second half. Shine sweep 0.35s on landing.
- **2.35–3.60** Headline ("An amazing friend appeared!"), badges, buttons.

### 3.4 LEGENDARY — the full ceremony (~5.8s)

- **0.00–0.40** Dim → **0.70** over 0.4s — the deepest hush. Capsule drop-in.
- **0.40–1.55** *Wobbles 1–4:* amplitudes ±11/13/14/15°, chimes **1.0 / 1.12 / 1.28 / 1.45** — a rising four-note ladder kids learn to sing. Glow bleeds to full gold over the four steps. Star motes begin drifting up behind the capsule (starRain, sparse).
- **1.55–2.35** **The rise:** capsule ascends 60px over 0.8s (`Sine/InOut`) while a **ray wheel** fades in behind it (8 thin gold wedges in a container rotating 12°/s). Orbit sparkles at max (16).
- **2.35–2.85** **Slow-mo pop, phase 1:** capsule inflates scale 1.0 → 1.18 over 0.5s with a ±1.5° sine micro-rock — everything else on screen holds still. A low-pitch Chime (0.7) hums underneath.
- **2.85–3.10** **Phase 2 — POP:** one soft white veil flash (full-stage frame, transparency 1 → 0.45 → 1 over 0.25s — gentle by design, and hard-capped at ONE flash per reveal for photosensitivity). `burst(60, gold)` **star burst** + two expanding `ring()`s staggered 0.1s. HappyPop at 1.0 + Chime at 1.5 together. Star rain thickens.
- **3.10–3.90** **Slow card flip 0.8s:** card-back rotates in (X-scale collapse/expand with midpoint swap), lands with a 4% overshoot bounce.
- **3.90–4.50** **Shine sweep 0.6s** travels the art. Headline scales in ("A legendary friend appeared!"). Card stroke pulses gold twice.
- **4.50–5.80** Confetti idle (2 gentle bursts/s, budgeted), buttons rise in. Meanwhile **in the 3D world the Sparkle Beacon is firing** (§6) — visible behind the dim to the player and to everyone nearby.

### 3.5 MYTHIC — Legendary + one more of everything (~6.4s)

Same skeleton, with: **5th wobble** (chime tops out at **1.60**), sunset-orange palette, the ray wheel gains a second counter-rotating layer, the pop is a **double burst** (60 + 40 at +0.15s), and the star rain uses a warm two-colour palette (the SquishFx `confettiRing` gold+blue trick, on-screen). Rarest pull in the game (3/100 after the weight swap) — the ceremony no kid has seen twice.

### 3.6 Overlay — VARIANT UPGRADE (Sparkly / Rainbow)

Runs *after* the card lands on any tier, +0.9s:

- **+0.0–0.3** Card stroke sweeps to `VariantConfig.colorFor(level)` (tween around via two strokes cross-fading).
- **+0.3–0.5** Variant badge **stamps** in at 1.6× scale → 1.0 (`Back/Out`) with a small burst in the variant colour. Rainbow adds a 0.5s rainbow UIGradient sweep across the art.
- **+0.3–0.8** **Coin count-up:** "+0 → +30" (or +60) rolling number in the headline, `CoinDeep` colour, with quiet tick chimes (pitch 1.8, vol 0.15, max 6 ticks). Headline: "✨ Sparkly!" / "🌈 Rainbow!" (existing copy kept).

Already-Rainbow duplicates: no stamp, just the count-up ("Friendship Bonus! +25") on the shortened already-known pacing.

### 3.7 Overlay — GIFT reveal (`result.giftFrom`)

The rarity ramp still runs honestly (wobbles = the friend's real tier), but skinned:

- Capsule wears a **bow** (two rose ellipse frames + a knot) and the glow bleeds through a heart-rose filter (lerp toward `Colors.Accent` blended 40% with the rarity colour).
- The pop releases **heart confetti** (RevealFx hearts, not stars).
- Headline: "💝 A gift from `StreamerMode.mask(giftFrom)`!" (existing masking kept).
- Chime ladder plays a warmer interval (start pitch 0.9). Gift reveals never show Open Another (it wasn't your capsule).

### 3.8 Skip / fast-forward

- Any tap on the dim during the ceremony **after 0.15s** (same guard philosophy as the current `canDismiss`, so the opening tap can't skip it): `Timeline:skip()` — all remaining waits collapse, registered tweens `Cancel()` + jump to final props, exactly ONE arrival pop sound still plays (a skip is never silent — the kid still gets her pop), badges/count-up apply instantly, buttons appear. Second tap dismisses.
- Watchdog stays, now tier-aware: `AUTO_CLOSE = tier.total + 8`.

---

## 4. Buttons row + "Open another"

Row at the card's foot: **[ Yay! ]** (primary, unchanged) · **[ Open another! ✨ 100 ]** (secondary, only when `result.coinsAfter >= result.cost`) · small text link **"What's inside?"** (opens the odds page §7).

- Open Another fires new c→s remote `OpenCapsuleAgain(capsuleKey)`. Server: rate-limit 1 per 1.2s, verify the character is within 24 studs of that capsule's stand, then `CapsuleService.tryOpen(player, capsuleKey, false)` — every existing validation (coins, pool) re-runs. Capsules are free-currency; chains are pure play.
- **No pressure styling:** the button never pulses, never counts down, never says "streak" or "last chance". It's just there when you can afford it, absent when you can't (absence, not a greyed-out tease).
- **Chaining + a latent bug fix:** the current `play()` *drops* any `CapsuleResult` that arrives while `busy` (a gifted friend arriving mid-reveal today silently loses its reveal — data is fine, moment is lost). v2 keeps a 1-deep queue: a queued result auto-skips the current reveal to done, 0.15s crossfade, next ceremony plays.

---

## 5. Code restructure plan

### Files

- `src/StarterPlayer/StarterPlayerScripts/CapsuleRevealUI.lua` — **rewrite** (~500 lines): director + beats + Timeline (inline, ~70 lines).
- `src/StarterPlayer/StarterPlayerScripts/RevealFx.lua` — **NEW** (~250 lines): screen-space FX helper, SquishFx's sibling.
- `src/StarterPlayer/StarterPlayerScripts/BeaconFx.lua` — **NEW** (~140 lines): world beam + cheer toast client.
- `src/StarterPlayer/StarterPlayerScripts/OddsUI.lua` — **NEW** (~100 lines): "What's Inside?" panel.
- `src/ReplicatedStorage/Shared/RevealConfig.lua` — **NEW** (~60 lines): the Tiers table + beacon threshold, shared so server watchdog assumptions/thresholds and client ceremony agree.
- `src/ReplicatedStorage/Shared/Remotes.lua` — +3: `SparkleBeacon` (s→c), `CheerDiscovery` (c→s), `OpenCapsuleAgain` (c→s).
- `src/ServerScriptService/Server/CapsuleService.lua` — payload adds `capsuleKey`, `cost`, `coinsAfter`; `OpenCapsuleAgain` handler.
- `src/ServerScriptService/Server/CheerService.lua` — **NEW** (~90 lines): reveal windows, per-pair cooldowns, cheer relay.
- `Main.server.lua` — beacon fire inside the existing `onOpened` wiring (it already receives `player, isNew, def` and has WorldService in scope for capsule positions); dedupe the existing epic+ `shoutToOthers` so beacon events don't double-toast; init CheerService; add `OwnerDebug "demoReveal:<rarity>"`.
- `CapsuleConfig.lua` — the mythic/legendary weight swap (§0).

### `play()` becomes a director over a skippable Timeline

```lua
function CapsuleRevealUI.play(result, onClose)
    if busy then queuePush(result, onClose); requestSkip(); return end
    busy = true
    local tier = tierFor(result)      -- RevealConfig.Tiers[rarity] + gift/family/known-pacing skins
    local tl = Timeline.new()
    armSkipAndDismiss(tl, tier)       -- dim tap: <0.15s ignore → skip → dismiss; Esc; watchdog tier.total+8
    task.spawn(function()
        local ok, err = pcall(function()
            introBeat(tl, tier)                        -- dim + PEARL capsule drop-in
            for i = 1, tier.wobbles do
                wobbleBeat(tl, tier, i, result.rarity) -- rock + chime(pitchFor(i)) + glowBleed(i / tier.wobbles)
            end
            preBurstBeat(tl, tier)                     -- hold / rise / slow-mo inflate
            burstBeat(tl, tier, result)                -- pop + RevealFx bursts/rings/flash
            cardBeat(tl, tier, result)                 -- pop-in | flip-in | slow-flip + shineSweep
            extrasBeat(tl, tier, result)               -- variant stamp, coin countUp, gift ribbon
            buttonsBeat(tl, result)                    -- Yay! / Open Another / odds link; canDismiss = true
        end)
        if not ok then warn("[CapsuleRevealUI] " .. tostring(err)); dismiss(true) end
        drainQueue()
    end)
end
```

`Timeline`: `:wait(t)` (returns instantly once skipped), `:tween(inst, info, props)` (plays + registers; on skip `Cancel()` + apply `props` directly), `:skip()` (idempotent). Beats read `tl.skipped` before spawning particles so a skip is clean, not a blur.

**Kept from v1 verbatim:** the pcall + watchdog safety net, `canDismiss` guard, Esc handling, `stage` auto-fit (mobile free), `StreamerMode.mask` at both giftFrom render points, the real-card-art big layout vs placeholder-card fallback branch.

### `RevealFx` (screen-space, inside `stage` so autofit scales everything)

`burst(pos, n, color)` (ImageLabels using `rbxasset://textures/particles/sparkles_main.dds`, tweened out) · `ring(pos, color)` · `orbiters(parent, n, color)` · `rays(parent, color, layers)` · `shineSweep(card)` (UIGradient offset −1→1) · `starRain(palette, density)` · `hearts(...)` · `flash(maxOpacity, dur)` — **hard rule: ≤0.6 opacity, ≥0.25s, max one per reveal** · `countUp(label, from, to, dur)`. Adopts SquishFx's FX budget verbatim: sliding-window cap (~80 live UI particles), halved by `UiTheme.isCompact()` and again by the `CalmSparkles` attribute — the gentler-effects toggle applies to the ceremony too.

### Sound (v1 = zero uploads)

Everything from `SoundConfig` already in the game: `Chime` pitch-laddered per wobble (cloned per play, Debris-cleaned), `CapsuleReveal` on card land, `HappyPopVariants` picks for pops (pitch per tier), `Pop` for the squash, quiet high-pitch Chime ticks for count-ups. Optional v2 owned uploads (ElevenLabs pipeline, safe cadence — upload, wait for Approved, then publish, per the established gotcha):

1. `CapsuleWobble` ×3 variants — soft jelly *gloop* per wobble (chime then moves to glow-bleed only; wobbles get tactile)
2. `RarityRiser` — 1.2s ascending shimmer under the epic+ pre-burst hold (the "inhale")
3. `LegendaryFanfare` — 2s warm bell flourish on legendary/mythic card land (the "exhale")
4. `RainbowGliss` — harp glissando for the Rainbow sweep
5. `GiftUnwrap` — bow-and-paper rustle for gift reveals
6. `TinyCheer` — warm synth crowd "yaay!" when a cheer arrives (§6)

Each is flavour on top of a fully working v1 — none is load-bearing.

---

## 6. The social beat — Sparkle Beacon + Cheer

**Server (Main's `onOpened` wiring + CheerService):** when `isNew and SortOrder >= 3` (epic+) **or** a Rainbow upgrade lands, fire `SparkleBeacon` to all clients: `{ revealId, byUserId, byName, defId, rarity, capsulePos }` (`revealId` = monotonic counter; `capsulePos` from the land's capsule stand, which Main/WorldService already knows). The existing plain-text `shoutToOthers` is suppressed for these events (beacon replaces it; no double-toast).

**Client (BeaconFx):**
- **World beam:** a client-local tall neon cylinder (CanCollide/CanQuery false) at `capsulePos`, rarity-coloured, transparency 0.2 → 1 over 8s, with 3 staggered sparkle bursts from a ParticleEmitter at its top; Debris 9s. Visible across the land — a lighthouse saying *something wonderful happened over there*. The discoverer sees their own beam glowing behind the reveal dim.
- **Cheer toast** (everyone except the discoverer): "✨ `mask(byName)` discovered `FriendName`! **[ Cheer! 🎉 ]**" — 8s life, one preset button, zero text entry. Tap fires `CheerDiscovery(revealId)`.
- **CheerService validation:** cheerer ≠ discoverer, both in-server, `revealId` ≤ 60s old, **one cheer per (cheerer, revealId)**, and a **30s per-pair cooldown** on top. Relay to the discoverer aggregates client-side: first = "🎉 `mask(name)` cheered your discovery!", further within 10s just update the count ("🎉 3 friends cheered!") — so even a coordinated group can't flood a child's screen, and love-bombing is mechanically impossible.
- **Why it matters beyond warmth:** running to a beacon + cheering are exactly the shared-session moments the 2026 discovery algorithm measures ("Intentional Co-Play Days"). At today's 2–5 CCU the beacon degrades gracefully — with zero witnesses it's still a private lighthouse moment for the discoverer, and it costs nothing.

---

## 7. "What's Inside?" — the kid-readable odds page

Entry points: the "What's inside?" link on the reveal button row + a page in the Collection Book. Content is **generated from `CapsuleConfig[capsuleKey].RarityWeights` renormalized to /100** — the page can never drift from the real odds.

- Header: "Out of every 100 Sparkle Capsules, about…"
- One row per tier, colour dot + count + the tier's own `KidFriendlyReveal` phrasing: "**50** cozy friends · **26** sparkly friends · **14** amazing friends · **7** legendary friends · **3** mythic Sparkle friends" (post-swap numbers). Bars drawn as dots-of-ten so a 6-year-old can count them.
- Honest footnotes, plain sentences: "Sometimes more, sometimes fewer — every capsule is a surprise." · "Capsules are always opened with Sparkle Coins you earn by playing. Never Robux." · "Already know the friend? They shine up ✨→🌈 and you get bonus Sparkle Coins. There are no misses." · "Family friends aren't in capsules — you earn them by restoring the lands, and they'll always be waiting for you."
- No urgency copy anywhere. Nothing on this page ever counts down.

---

## 8. TikTok LIVE segment kit (owner-facing)

1. **"Count the wobbles with me!"** — the core LIVE segment. Chat counts each wobble aloud; wobble 4 is the scream. The ladder chime gives viewers an audio cue even at phone-speaker quality.
2. **Capsule Train** — Open Another chains on stream; coins are earned on-camera first ("we squish, we earn, we open").
3. **Beacon runs** — when anyone in the server pulls epic+, Chris sprints to the beam and smashes Cheer on camera; models the kindness loop.
4. **Rehearsal mode:** `OwnerDebug "demoReveal:<rarity>"` plays the ceremony client-side with a real def but **grants nothing** and renders a small "Practice ✨" ribbon on the card — so rehearsal clips can never misrepresent a real pull. On LIVE, pulls are real: capsules are free-currency, so showing them is never gambling content.

---

## 9. Verification plan (per the autonomous-build convention)

- Studio: `demoReveal` each of the 6 skins + variant/gift overlays + skip-at-every-beat + queue (fire two results back-to-back) + watchdog (comment out `canDismiss`) + compact layout + CalmSparkles halving.
- Server: OpenCapsuleAgain range/rate/coins rejections; CheerService pair-cooldown + revealId expiry + dedupe; beacon threshold.
- Exact-math checks: chime pitch ladder values, coin count-up totals vs `VariantConfig`, odds page sums to 100 for all three capsules.
- Multiplayer paths (cheer arrival, beacon witnessed, gift-during-reveal queue) = family-playtest items, consistent with WO-2/WO-5 precedent.

**Ship order:** 1) weight swap + payload fields → 2) CapsuleRevealUI rewrite + RevealFx (the recordable core) → 3) Open Another → 4) Beacon + Cheer → 5) OddsUI → 6) v2 SFX uploads whenever convenient.

### Law compliance (as assessed by the design agent)

Bullet-by-bullet against THE LAW:

- **Kid-safe verbs/vocabulary:** every beat is wobble/sparkle/pop/discover/cheer; all copy reuses existing strings (KidFriendlyReveal, Friendship Bonus, Discovered) plus "cheered your discovery". No new dark vocabulary anywhere.
- **Capsules FREE forever / no paid randomness:** untouched — v2 changes only presentation; Open Another spends earned coins through the existing `tryOpen` validation and is never purchasable. The odds page states "never Robux" in kid language.
- **Trading lock / gift spirit:** this spec adds no trading. The Cheer loop is the deliberate counter-move to the competitor's scam-ridden trade boards: it delivers the *social status moment* of a big pull (the actual thing kids want from trading) with zero property transfer, so nobody can ever be talked out of anything. Gift reveals keep the giver-keeps-theirs framing and the existing StreamerMode masking.
- **Style/convenience-only monetization:** nothing here is sold.
- **No pressure mechanics:** Open Another never pulses, never counts down, and is absent (not teased) when unaffordable; the odds page has zero urgency copy; the beacon toast expires silently. Nothing decays or goes backward.
- **No near-miss manipulation (the big one):** the telegraph is a *pure monotone function of the actual result* — wobble count, glow colour, and chime pitch can never overshoot the tier you truly got. There is no "almost legendary" state, ever; a common wobbles once and is done. Suspense comes from not knowing whether another wobble is coming, not from faking one. This is the honest inversion of slot-machine near-miss design, and the spec encodes it as a hard rule ("never-overshoot") in RevealConfig.
- **No losers:** duplicates remain upgrades/bonuses; the odds page says "there are no misses" explicitly.
- **No free-text from kids:** Cheer is a single preset button; every new surface is preset-only.
- **Stranger-safety / love-bombing impossible:** per-pair 30s cooldown + one-cheer-per-reveal dedupe + client-side aggregation ("3 friends cheered!") caps inbound social volume mechanically; names pass through StreamerMode.mask at every render point. **One deliberate bend, flagged:** the beacon toast shows DisplayName for non-friends, matching the game's existing live convention (shoutToOthers, leaderboards, gift shout-outs). If Chris wants the stricter "a kind visitor" rule, it's a one-line change in BeaconFx — but it should then be applied game-wide for consistency, which is a separate work order.
- **Server-authoritative:** all grants unchanged server-side; OpenCapsuleAgain re-runs full server validation (range, rate, coins); cheers are server-validated relays; the beacon is server-initiated. The client only ever renders.
- **Photosensitivity (implied by kid-safe):** hard cap of one soft flash per reveal, ≤0.6 opacity, ≥0.25s; CalmSparkles halves all ceremony FX.
- **Honesty on stream:** the owner demo mode watermarks itself "Practice ✨" and grants nothing, so recorded rehearsals can't impersonate real pulls.

### Effort estimate

L. Client: CapsuleRevealUI full rewrite (~500 lines incl. inline Timeline) + new RevealFx (~250) + new BeaconFx (~140) + new OddsUI (~100). Shared: new RevealConfig (~60), Remotes +3 events, CapsuleConfig 1-line weight swap. Server: CapsuleService payload +3 fields and OpenCapsuleAgain handler (~40), new CheerService (~90), Main wiring/dedupe/demo trigger (~40). Zero asset uploads for v1 (chime pitch-shift covers all audio); 6 optional ElevenLabs uploads for v2. Core ceremony is Studio-verifiable solo via the demoReveal trigger; cheer/beacon multiplayer paths land on the existing family-playtest checklist. Roughly one focused build session in the project's established WO cadence, shippable in 5 independent slices (weight swap → ceremony → Open Another → beacon/cheer → odds page).

### Viral impact (honest)

4/5. The reveal is the proven recordable surface in this genre — the competitor's 50.9M visits were carried by unboxing/trade clips, and its 11.9-minute sessions show the reveal spike is real even when the world around it is shallow. v2 adds what raw unboxing clips lack: a *countable, chantable* suspense mechanic (wobble-counting) that gives TikTok LIVE chat a native participation verb and gives kid clips a scream-moment timestamp (wobble 4). It's honest escalation, so it compounds instead of burning trust like the competitor's scam economy is doing (26.9K CCU → 3.1K in 6 weeks). Why not 5: a reveal amplifies attention, it doesn't generate it — at single-digit CCU the beacon usually fires unwitnessed, and clips still need Chris's marketing flywheel to find an audience. This is the best possible multiplier waiting on traffic, not a traffic source itself.

---

## 6. FULL SPEC — The Switcheroo Station: The Switcheroo Station — spare-copy swaps via the Sparkle Express (phased: machine now, friend-ritual later, negotiation board never)

# The Switcheroo Station
### A kid-safe swap system for Squishy Smash — full design spec
*Grounded in the live codebase (PlayerDataService / CapsuleService / GiftService / Remotes / doc 14 Law & Landmines), 2026-08-06.*

---

## 1. Recommended architecture (and honest tradeoffs)

**Verdict on the three hypotheses:** none survives alone; the winning design is **B's foundation + C's delivery + A held as Phase 2.**

- **Hypothesis A (double-gift "Friendship Swap") alone is not a swap.** Both sides gain, nothing is scarce, so there is no economy, no tier lists, no "I finally got it" story — it's Gifting v1 with a second confirm button. Worth building, but as a *ritual on top of* a real spare economy, not instead of one.
- **Hypothesis B (spare-copy swaps, player-to-player) is the right economy but the wrong first delivery.** At single-digit CCU a walk-up counterparty rarely exists; and even with an Adopt Me-style license quiz, a two-party negotiated exchange is where all seven scam patterns live. Adopt Me *discourages* scams; the Law demands *impossible*.
- **Hypothesis C (the machine) is the right first delivery but needs B's foundation** (per-friend copy counts, spares) to have anything to swap, and needs a soul — raw "Swap-o-Matic" vending is cold. The fix is lore: the machine is a **side platform of the Sparkle Express**, the coaster that already exists in Pudding Hills. Spare friends *board the train with a tiny suitcase to go find a new best friend in another world*; a well-traveled friend *steps off the train for you*. "Cross-server DataStore pool" becomes "the Express visits every world." Sending a friend away is reframed from loss to kindness — which is the emotional truth of the design anyway, because only spares travel and the collection never regresses.

**The three phases:**

| Phase | What | Liquidity needed | Scam surface | When |
|---|---|---|---|---|
| **1 — The Switcheroo Station** | Spare-copy foundation + cross-server mystery swap machine | **Zero** (seed fallback works at 0 CCU) | **Zero** (no counterparty) | Now |
| **2 — Friendship Switcheroo** | Two players at the Station swap spares in a simultaneous, server-rendered, atomic ritual | 2 players co-present | Near-zero (no claims, no sequencing) | After Phase 1 family playtest + the reveal-ceremony upgrade |
| **3 — Open negotiation board** | Multi-slot trade board with counter-offers | High | High — this is where TSD's 7 scams live | **Never. Recommend permanently out of scope.** |

**Honest tradeoffs of this ordering:** Phase 1 will not reproduce Trade Squishy Dumplings' social electricity — machine swaps are solitary. What it buys: it works at today's player counts, it retro-fits the copy-count economy safely, it gives every duplicate capsule pull a purpose (a real D7 retention lever — completionists currently hit a coin-only dead end past Rainbow), and it de-risks Phase 2 by shipping the hard data-model change alone. TSD's own numbers argue for patience: 87% off peak in 6 weeks, 11.9-minute sessions — the negotiated-trading spike is a churn engine. We copy the *format* that spiked it (collect → swap → unbox content) and refuse the churn.

---

## 2. Phase 1 full spec — The Switcheroo Station

### 2.1 Storybook naming (the word "trading" never appears anywhere)

- **The place:** *The Switcheroo Station* — a tiny candy-striped depot on a side platform of the Sparkle Express, Pudding Hills, its own district near the travel hub (per the world-geometry rule: own district, not piled at spawn; run the **workspace-wide** clearance scan before fixing coordinates — the garden/swing overlap lesson — and respect the coaster rim boundary at roughly ±130–138).
- **The keeper:** *Whistlestop*, a plump owl conductor (SquishyModelFactory archetype + cap; static guide figure like the Soft Dumpling guide — NOT a squishable friend).
- **The verb:** *Switcheroo!* Deposit = "send a spare friend on an adventure." Receive = "welcome a traveler."
- **The currency of stories:** *Travel Stamps* (provenance — §4).
- Player-facing copy bank (glyph-safe per the landmine list — no coin glyph, no ✕):
  - Prompt: **"Visit the Switcheroo Station"**
  - Empty state: **"No spare friends yet! Extra friends from Sparkle Capsules become spares — they'd love an adventure."**
  - Confirm: **"Send this spare [Name] to find a new best friend? [Name] stays in your Collection Book — a spare is going traveling!"** Buttons: **"All aboard! ✨"** / **"Not yet"**
  - Cap reached: **"The Express is resting its wheels — more adventures tomorrow!"** (limited things come back and say so; no timer shown)
  - Left-today pill: **"2 adventures left today"** (same pattern as the gift pill precedent)

### 2.2 Foundation: spare copies (the data-model change everything rides on)

**Profile (PlayerDataService.lua):**
```lua
-- NEW fields in Profile type + newProfile():
Copies    : { [string]: number },  -- total copies ever obtained per defId
Stamps    : { [string]: { travels: number, from: string?, fromIsFriend: boolean? } },
Switcheroo: { DayIndex: number, UsedToday: number,
              Stories: { {defId: string, dir: "sent"|"met", from: string?, t: number} } } -- ring buffer, 30 max
```
- **Derived, never stored:** `consumed(defId) = 1 + (Variants[defId] or 0)` (base discovery + one copy per variant step, Max=2). `spares(defId) = math.max(0, (Copies[defId] or 0) - consumed(defId))`.
- **Migration (in the sanitize/load path, same style as the existing recompute-DiscoveredCount code):** if `data.Copies` is missing, seed `Copies[id] = 1 + (Variants[id] or 0)` for every discovered id. Pure-upside migration: nobody starts with fewer than they "have," nobody loses anything; pre-existing beyond-Rainbow dupes were already converted to coins and stay converted.
- **Grant pipeline (CapsuleService.tryOpen + the gift-share path):** every copy obtained does `Copies[defId] += 1` *before* the existing discover/variant logic. Beyond-Rainbow duplicates keep the 25-coin `MaxDuplicateCoins` **and** now also bank a spare — strictly better than today, so the change itself obeys "nothing goes backward."
- **Excluded from swapping:** the Family Three quest cards get `SwapExcluded = true` in their definitions (they're one-grant finale rewards; naturally spare-less anyway, but belt-and-suspenders — the picker filter and the server validator both check it).
- **Snapshot (StateSync):** add `copies`, `stamps`, and `switcheroo = { adventuresLeft = cap - UsedToday }`. Collection Book renders a small **"x2 spare"** badge on cards with spares and the Travel Stamp line on the card detail view.

### 2.3 New shared config — `SwitcherooConfig.lua`
```lua
DailyCap = 3,                 -- adventures per UTC day (DailyService day-index)
PoolKeyPrefix = "SwitcherooPool_v1_",  -- one DataStore key per rarity tier (RarityConfig)
PoolMaxEntries = 150,         -- oldest entries age out silently (no player is owed them)
UndiscoveredWeight = 4,       -- draw prefers friends the player hasn't discovered, 4:1
StampTiers = { {3, "Well-Traveled"}, {7, "World Wanderer"} },  -- additive badges, never lost
```

### 2.4 UI flow (preset pickers only — zero free text)

1. ProximityPrompt on the depot desk (**on a BasePart** — the Model-parent landmine) fires server-side → server sends **`OpenSwitcheroo`** with the player's spare list.
2. **Page 1 — pick a spare.** Card grid of ONLY spares (server-computed list; client never decides eligibility). Each tile: real card art, spare-count badge, rarity gem. No spares → the empty-state page with a "Collection Book" button. No timers, no queue, nothing counts down.
3. **Page 2 — the calm confirm.** One big card, the confirm copy above, two buttons. No rush mechanics; the panel sits open as long as the kid likes.
4. **"All aboard!"** → client fires **`SwitcherooDeposit(defId)`** → train-whistle + tiny-suitcase boarding animation plays while the server works → steam hisses, the arrival door opens on a glowing silhouette → **full rarity-escalated reveal** (this is a flagship customer of the planned reveal-ceremony upgrade: per-tier FX, per-tier chime, suspense before the tint — the machine's mystery output is exactly what the current 4/10 reveal is failing to serve) → the card lands with its **Travel Stamp**: *"Once loved by Addy!"* (Roblox friend) or *"A traveler from a faraway world!"* (everyone else).
5. Result pill updates: "2 adventures left today." At cap: the resting-wheels line.
6. **StreamerMode:** SwitcherooUI and the reveal call `StreamerMode.mask()` at every name render point, same as ToastUI/GiftUI/CapsuleRevealUI already do.
7. **Compact/mobile HUD** verified per the standing doc-14 acceptance criterion (`ForceCompactHud`), both modes screenshotted.

### 2.5 Remotes additions (Remotes.lua)
```lua
-- client -> server
Remotes.SwitcherooDeposit = "SwitcherooDeposit"  -- defId: send a spare, receive a traveler (atomic)
-- server -> client
Remotes.OpenSwitcheroo   = "OpenSwitcheroo"      -- {spares, adventuresLeft}: depot prompt opened the panel
Remotes.SwitcherooResult = "SwitcherooResult"    -- {card payload à la CapsuleResult, stamp, adventuresLeft}
```
`SwitcherooResult` reuses the CapsuleResult payload shape (CapsuleRevealUI already renders gift-share arrivals via `giftFrom`; this adds a `stamp` field and a "traveler" reveal skin) — dedicated remote, shared renderer.

### 2.6 Server: `SwitcherooService.lua` — validation and atomicity

**Validation, in order, all server-side:** profile loaded and **not a temp profile** (a DataStore-outage session must refuse with a gentle "the Station is snoozing" toast — same principle as ProcessReceipt's NotProcessedYet rule, a deposit into a temp profile would evaporate); prompt-range check against the depot; `defId` exists, not `SwapExcluded`; `spares(defId) >= 1` (**the last copy is unswappable by construction** — it isn't a spare); `UsedToday < DailyCap` with the DailyService UTC day-index.

**Atomic order of operations (the invariant: the kid's spare is never debited unless the traveler is already in hand):**
1. **Select the incoming friend FIRST.** `UpdateAsync` on the deposited friend's rarity pool key; the transform picks one entry — filtered against the recipient's block list (`GetBlockedUserIdsAsync`, pcall'd, best-effort), **excluding the player's own deposits** (no solo self-cycling), preferring undiscovered defIds at `UndiscoveredWeight`, oldest-first within a preference band — removes it, returns it. One retry on failure.
2. **Pool empty or DataStore down → Whistlestop's Pouch:** seed a same-rarity friend from the roster, same undiscovered weighting, stamp *"a traveler from a faraway world."* The machine **never fails and never waits** — works at 0 CCU, no pending state, no countdown, honest fiction (the Express visits many worlds).
3. **One in-memory mutation, then save:** `Copies[deposited] -= 1`; run the incoming through the standard grant pipeline (`Copies += 1` → discover / variant-upgrade / overflow coins — worst case is variant progress or 25 coins *plus* the copy banks as a spare, so even a "dupe" result is net-neutral-or-better in spares and strictly positive in outcomes); `UsedToday += 1`; write `Stamps[incoming]`; append to `Stories`; mark dirty, request save. Nothing between pop and save can fail in-band; a server crash in that window costs the shared pool one entry and no child anything.
4. **Push the deposit to the pool, best-effort, after.** Entry: `{d=defId, u=UserId, n=DisplayName, t=(myStamps[defId].travels or 0)+1, ts=os.time()}`. A failed push loses one economy entry, never a player's property. Cap at `PoolMaxEntries`, drop oldest.
5. Fire `SwitcherooResult`; feed telemetry + `DailyService.noteEvent` (a rotating quest template *"Visit the Switcheroo Station OR open a Sparkle Capsule"* — the OR keeps it completable for spare-less players).

**Rarity is always exact-matched.** A Legendary spare can only ever become a Legendary friend. No cross-tier drift, ever — this single rule deletes the entire "value mismatch" category of harm.

### 2.7 Friend vs. stranger (per the Law)
Stamps show a display name **only** when `IsFriendsWith` the depositor; everyone else is *"a kind visitor"* / *"a faraway world."* There is no reply channel, no contact surface, no way to find who received your friend — love-bombing has no mechanism to exist. Per the doc-14 landmine, Studio test accounts return empty friend/block lists: add `OwnerDebug treatAsFriend:UserId` / `treatAsStranger` overrides, and put the real-account friend-name branch on the family-playtest checklist.

### 2.8 The competitor's 7 scam patterns → mechanically impossible

| # | TSD scam pattern | Why it CANNOT happen here (not "discouraged" — no mechanism exists) |
|---|---|---|
| 1 | **Add-it-after promise** ("I'll give you the rest later") | The swap is one atomic server transaction with no counterparty, no promises, no sequencing, no second act. Phase 2 keeps this: one slot, one simultaneous exchange, nothing "after." |
| 2 | **Last-second switcheroo** (swap the item as the victim confirms) | No counterparty controls the other side; the machine's draw happens after your single confirm and is rarity-locked. Phase 2: the server validates the exact defIds both players saw; any re-pick voids both confirms. |
| 3 | **Fake rarity/variant claim** | Items are never *claimed* — they are server-rendered from the true profile (real card art, real rarity gem, real variant badge). There is no free text in which to lie, and nothing the other party asserts is ever an input. |
| 4 | **Pressure rush** ("someone else wants it!") | No timers, no queue, no visible other party, no countdown anywhere in the flow (the Law already bans them). A confirm page with two buttons cannot be rushed by a stranger who cannot see it. |
| 5 | **Off-board deal** ("skip the board, just gift it to me first") | Items move ONLY through the atomic ritual. Crucially, the existing gift-share is non-destructive by design — the giver always keeps theirs — so the classic "you go first" con is structurally *harmless*: going first costs nothing. There is no destructive transfer to socially engineer. |
| 6 | **Phishing** (off-platform links, "free item" sites) | No free-text input from kids, no link surfaces, no chat needed to complete anything. The one text field (Magic Words) matches a server-side table of OUR codes and can never transfer items between players. |
| 7 | **Trust trade / lending** ("give it to me, I'll give it back") | No lending mechanic exists; nothing can be handed to another player outside the atomic ritual; and the collection itself (Discovered + Variants) is not transferable property at all — only spares move, only through the machine. |

### 2.9 Caps, cooldowns, and the no-pressure audit
3 adventures/UTC day (mirrors the gift-limit spirit: enough for the ritual, no farm). No per-pair cooldowns needed in Phase 1 (no pairs). The "N adventures left" pill follows the accepted gift-pill precedent; nothing on screen ticks, decays, or goes backward; the cap message promises tomorrow explicitly. Deposits are free — no coin fee; the Station is kindness, not commerce (and the coin sink job belongs to the Boutique/Garden).

### 2.10 Acceptance criteria (Studio-verifiable now / family-playtest later)
**Studio:** migration seeds `Copies` correctly for an existing profile (Rainbow friend → 3); spare math exact across capsule dupes; last-copy never appears in the picker AND server rejects a forged `SwitcherooDeposit` for it; exact-rarity always; empty-pool seed path; pool round-trip across two Studio local servers; temp-profile refusal; cap boundary at 3→0 and next-day reset; forged-remote fuzzing (bad defIds, SwapExcluded ids, spam); compact-HUD screenshots; `execute_luau` module-cache landmine respected when unit-testing live modules. **Family playtest:** friend-name stamp on a real account pair; the 6-year-old's read of "send a spare on an adventure" (watch for ANY sadness at the boarding animation — if Addy or the 6yo hesitates or grieves, soften the copy or add a "wave goodbye" beat, this is the emotional acceptance test of the whole feature); whether 3/day feels generous.

---

## 3. Phase 2 sketch — the Friendship Switcheroo (build only after Phase 1 proves out)

Two players stand at the Station together (the depot is the ONLY place swaps happen — a ritual space, never a walk-up ambush surface). Each picks one spare; the server renders **both true cards side by side** (no claims possible); a mandatory calm storybook beat — *"Take a good look!"* — with no timer; then both **hold ✨ for one second**; one atomic server exchange (each side: spare out, standard grant pipeline in, mutual Travel Stamps). Guards: **same-rarity required for non-friends** (Roblox friends may swap adjacent tiers — richer trust for real friendships, per the Law's friends-get-richer-FX principle); one player-swap per pair per day (love-bomb guard); block-list respected; any re-pick voids both confirms; no multi-slot, no counter-offers, no chat dependency, ever. Gate it behind a **Switcheroo Ticket**: Whistlestop's three-question *"Safe or Silly?"* picture quiz (preset answers, unlimited gentle retries, everyone passes eventually — Adopt Me's Trade License pattern, storybooked). Phase 2 also adds the "Swap Stories" journal page in the Collection Book (the 30-entry ring buffer ships silently in Phase 1's profile).

**Phase 3 (the open negotiation board): recommend never.** Every one of TSD's seven scams is native to multi-slot negotiated boards; their only defense is a confirm button and a wiki page teaching children to spot cons. That is the exact opposite of the Law.

---

## 4. The value economy's safe substitute → tier-list / wiki / TikTok content

TSD's content engine is price volatility plus scam drama. Ours is **scarcity + provenance + honest mystery**, which produces the same content *formats* without the harm:

1. **Real scarcity, wiki-able:** spares are finite and earned; past **Friend-of-the-Week** spares (the 8 event friends) become genuinely scarce in the pool — "what's riding the Express this week" is a natural fan-wiki page, and the weekly rotation gives it a publishing cadence.
2. **Published honest mechanics as brand:** we *publicly document* the Station's rules (exact rarity match, 4:1 undiscovered preference, pool-fed-by-real-kids). TSD's wiki teaches scam defense; ours teaches how the magic works. "The swap game your parents can read the rules of" is a differentiator worth pitching to the same outlets that covered TSD's codes (Destructoid/GameRant/ProGameGuides — our Magic Words channel already exists for exactly this, with per-channel attribution).
3. **Provenance = story units:** Travel Stamps and tiers (*Well-Traveled* at 3 journeys, *World Wanderer* at 7 — additive, never lost) make individual cards narratable: "this Moonbat has visited seven worlds." That's a TikTok clip, a LIVE-stream segment ("let's see who steps off the Express"), and a book tie-in (the Express is a ready-made picture-book setting for the KDP series — cross-media flywheel).
4. **The reveal IS the unboxing format:** steam, door, silhouette, stamp — a native short-form clip mirroring the blind-box craze (Labubu-wave) with zero paid randomness. Pairs directly with the reveal-ceremony upgrade; ship them together and every Switcheroo is filmable.
5. **Discovery algorithm fit:** Phase 1 lifts D7/session (duplicates now always progress something; a new daily ritual chain: capsule → garden → Station). Phase 2 is a *measured* co-play driver ("7-Day Intentional Co-Play Days") — two kids physically meeting at a depot to swap is precisely the signal Roblox now rewards.

---

## 5. What to tell the owner — which Law bullets bend, which hold

**One bullet bends, on purpose, and here is the exact sentence:** *"NO trading. Gifts only — sharing a friend never costs the giver theirs."*
- It bends to: **"No negotiated trading, ever. Swaps move only SPARE copies, only through atomic rituals, and the collection itself can never shrink."**
- The **spirit-test** the lock exists for, verified clause by clause: *never talked out of her collection* — Discovered and Variants are structurally non-transferable; only spares move; the last copy is not a spare by arithmetic, not by policy. *Never scammed* — Phase 1 has no counterparty; Phase 2 has no claims (server renders truth), no sequencing (atomic), no timers, no multi-slot; the seven known patterns are each mechanism-deleted (§2.8). *Never sad after a swap* — exact rarity always, output is always a discovery, a variant step, or coins-plus-a-banked-spare; nothing regresses; and the boarding is framed as kindness, with the family playtest explicitly watching the 6-year-old's face at that moment.
- **What does NOT bend:** gifts stay exactly as they are — sharing still never costs the giver theirs. Capsules stay free; the Station is free; its randomness is free and earned like capsules (Paid Random Items policy untouched; in-experience item exchange is platform-allowed for all-ages, per the Adopt Me precedent). Monetization untouched. No pressure, no losers, no free text, stranger-safe, server-authoritative — all hold outright, demonstrated line-by-line through this spec.
- **Sequencing advice:** ship the foundation + Station now (it works at current CCU and its worst case is "a pleasant solo machine"); publish the rules page; let the girls playtest; decide Phase 2 only after watching them use Phase 1. The negotiation board stays off the roadmap permanently — write that refusal down in doc 14 so a future build agent doesn't "improve" it back in.

### Law compliance (as assessed by the design agent)

Bullet-by-bullet: (1) Kid-safe/storybook verbs — the entire feature is narrated as kindness (send a spare friend "on an adventure," welcome a "traveler"); the word "trading" appears nowhere player-facing; HONORED. (2) Vocabulary locks — untouched; new terms (Switcheroo, Travel Stamp, spare) extend the register; HONORED. (3) Free capsules / no paid randomness — Station is free, its mystery draw is earned like capsules, no monetization touches it; HONORED. (4) "NO trading. Gifts only" — THIS IS THE ONE BULLET THAT BENDS, explicitly and by owner request: a deposited spare does leave the player's spare count, so "never costs the giver theirs" is no longer universally true for the NEW swap verb (gifts themselves remain fully non-destructive). The bend is contained so the lock's stated spirit survives mechanically: only spares move (Discovered/Variants are structurally non-transferable), the last copy is unswappable by arithmetic, exact-rarity matching plus always-positive outcomes mean no swap can end in loss, and all seven known scam patterns are mechanism-deleted rather than discouraged (spec §2.8). (5) Style/convenience monetization only — untouched; the Station is deliberately not a coin sink; HONORED. (6) No pressure mechanics — no timers, no countdowns, no decay, no pending states (atomic same-moment exchange), cap message promises tomorrow explicitly, "N adventures left" pill follows the accepted gift-pill precedent; HONORED. (7) No losers — every swap yields a discovery, a variant step, or coins plus a banked spare; the machine never fails or makes you wait; HONORED. (8) No free text — preset card pickers only; the Phase 2 quiz is picture-choice; HONORED. (9) Stranger-safety — names shown only for Roblox friends (else "a kind visitor"), block-list filtering of pool draws, no reply/contact channel so love-bombing has no mechanism, Phase 2 adds per-pair daily limits; StreamerMode masking at all render points; HONORED. (10) Server-authoritative — eligibility computed server-side, forged-remote validation list specified, atomic debit-only-after-credit-in-hand invariant, temp-profile refusal mirroring the ProcessReceipt rule; HONORED.

### Effort estimate

L for Phase 1 done properly (multi-day per doc-14's scale). Touches: PlayerDataService (Copies/Stamps/Switcheroo fields + load-path migration + snapshot), CapsuleService + gift-share grant pipeline (Copies increment, beyond-Rainbow spare banking), NEW SwitcherooConfig/SwitcherooService/SwitcherooUI, Remotes (+3), WorldService (depot district build + Whistlestop via SquishyModelFactory), CollectionBookUI (spare badges + stamp line), CapsuleRevealUI (traveler skin, rides the planned reveal upgrade), DataStore pool with cross-server tests, StreamerMode hook points, compact-HUD verification. Cut-line to M: ship foundation + Station with the plain existing reveal, defer stamps UI polish and the quest template. Phase 2 is a separate M later; Phase 3 is deliberately never.

### Viral impact (honest)

3/5 for Phase 1 alone, honestly — a solo machine cannot reproduce Trade Squishy Dumplings' two-player social electricity, and our CCU is too low for word-of-mouth compounding yet. What it does earn: a native unboxing/reveal clip format for TikTok LIVE, a weekly wiki-able scarcity beat (past Friend-of-the-Week spares in the pool), provenance stories ("this friend has visited 7 worlds"), and a real D7 retention lever (every dupe now progresses something). Rises to 4/5 with the reveal-ceremony upgrade shipped alongside plus Phase 2, whose depot co-play ritual feeds the exact "Intentional Co-Play Days" signal the 2026 discovery algorithm measures. It will never 5/5 the TSD spike — that spike is fueled by value volatility and scam drama we are deliberately refusing, and TSD's own trajectory (87% off peak in 6 weeks, 11.9-minute sessions) is the argument that the spike is not the prize; parent-trusted durability is.

---

## 7. FULL SPEC — Viral Gap Plan: Squishy Smash Viral Gap Plan — Depth, Press, Discovery, Cadence, and the Wave (everything beyond Reveal + Swap)

# SQUISHY SMASH — VIRAL GAP PLAN
*Growth strategy beyond the reveal upgrade and the swap system (sibling designers own those; slot-in notes only). Grounded in the live codebase at `C:\Users\chris\Roblox-squishy` — file paths cited are real hook points, verified today.*

**The one-sentence thesis:** Trade Squishy Dumplings proved the audience (50.9M visits in 74 days) and is now proving the failure mode (-87% CCU, 11.9-minute sessions, scam-riddled). Our play is to catch its falling audience with the thing it structurally cannot offer — a squishy collector world that is deep, calm, and impossible to be scammed in — while stealing its two legitimately good growth machines: a rankable value ladder and the codes-article press channel.

**Ranked priority (impact / effort):**
1. Discovery Metrics fixes — impact 5, effort M (the algorithm lever; nothing else matters if D1 is weak)
2. Collection Depth "Sparkle Patterns" — impact 5, effort M (the tier-list fuel + the swap system's inventory)
3. Codes press channel + wiki — impact 4, effort S recurring (cheapest real SEO in the genre)
4. Update cadence / Up-and-Coming — impact 4, effort S (process, not code)
5. The Wave positioning — impact 4, effort S (a 30-60 day window, then it closes)
6. The Refuse List — impact 3 direct / 5 strategic (it is the brand; costs are real and quantified below)

---

## 1. COLLECTION DEPTH — the Sparkle Pattern system (impact 5, effort M)

**The gap.** The competitor's economy runs on a THREE-axis ladder: rarity tier x variant (Galaxy/Glitter) x mutation. That combinatorial space is what fans rank, tier-list, and argue about — the arguing IS the content ecosystem. We have two axes (5 rarities x 3 variant states via `VariantConfig.lua`) and a duplicate past Rainbow is just 25 coins (`VariantConfig.MaxDuplicateCoins`). 56 x 3 = 168 collectible states. Not enough surface for a fan wiki to rank.

**The design: Sparkle Patterns.** A third, horizontal axis — a "coat" a friend can wear.

*Core rules (each one is a Law lock):*
- Every capsule open rolls a pattern alongside the friend. First discovery rolls one; **every duplicate rolls one too** and it ADDS to that friend's pattern collection. This is the critical anti-sad choice: patterns are rolled at discovery but never ONLY at discovery — a kid who rolled Classic on her favorite friend is never locked out; every future dupe is another chance. Purely additive, never lost, no bad-luck permanence.
- Patterns accumulate per friend as a set (a sticker album inside the album). The kid picks which owned pattern the friend WEARS (Book UI toggle, same interaction pattern as Equip Buddy). Nothing is ever overwritten.
- Zero power. Zero coin value differences between patterns beyond a small flat "new pattern!" bonus (+15 coins, flat, on top of existing variant/dupe coins — respects the flat-bonus economy rule from the Sparkle Chain design in `GameConfig.lua`).
- All patterns obtainable forever from day one. Odds posted openly in-game and on the wiki (an honest-odds page is ALSO a parent-trust artifact and easy press copy: "the collector game that publishes its odds — and takes no money for pulls").

*The pattern roster (8 at launch — programmatic only, zero uploads):*
- **Classic** — guaranteed baseline (every friend has it from discovery)
- **Berry Swirl** — ~1 in 6 — warm pink tint + drifting berry-colored sparkle particles
- **Mint Drizzle** — ~1 in 6 — mint tint + slow drip-sparkle
- **Honey Glaze** — ~1 in 12 — amber tint + Glass-material sheen on the body part
- **Starlight Freckles** — ~1 in 25 — navy-tint + white ParticleEmitter freckle field
- **Moonlit** — ~1 in 25 — soft blue glow (PointLight) — **odds x3 in the Moonlit Capsule**
- **Galaxy Swirl** — ~1 in 100 — ForceField-material shimmer + purple/teal particle spiral
- **Golden Crumb** — ~1 in 250 — reuses `applyGolden()` (SquishyModelFactory.lua:657) verbatim

Land-biased odds (Moonlit x3 in Moonlit Hollow; give Goo Coast a bias on Mint Drizzle, Pudding Hills on Honey Glaze) create hunt STRUCTURE — "where do I farm Moonlit?" is a wiki page, a TikTok video, and a reason to travel — without any FOMO, because every pattern drops everywhere, always, forever.

**Why this is tier-list fuel:** 56 friends x 8 patterns x 3 variant states = 1,344 collectible states, with genuine scarcity gradient (Golden Crumb Rainbow Galaxy Dumpling is a ~1-in-many-thousands flex) but no tradeable "value" to scam over. Fans rank by beauty and rarity, not price. We seed the first tier-list ourselves on the wiki (see section 2) so the ranking conversation has a template.

**Implementation map (all existing hook points, verified):**
- `CapsuleService.lua` tryOpen, lines ~98-128: after the discover/variant block, roll `patternId` server-side; append `patternId` + `patternIsNew` to the CapsuleResult payload.
- `PlayerDataService.lua`: add `Patterns = { [friendId] = { [patternId]=true } }` + `WornPatterns = { [friendId] = patternId }` to the profile + StateSync snapshot. Tiny DataStore footprint.
- New `PatternConfig.lua` in Shared (mirrors VariantConfig's shape: name, tint Color3, particle spec, weight, per-capsule bias) so client Book/reveal and server roller always agree.
- `SquishyModelFactory.lua`: generalize `applyGolden()` into `applyPattern(model, patternId)` — tint + material + particle per config. Golden Crumb calls the existing golden path.
- Book UI: pattern chips on the card detail (the variant badge row already exists — extend it); worn-pattern toggle via a new `WearPattern` remote (validated server-side like EquipCosmetic).
- Buddy: worn pattern applies to the companion via BuddyService (it already re-applies variant auras); show-off surface for free.
- New remote: c->s `WearPattern`; CapsuleResult payload grows two fields. No other contract changes.

**Slot-ins for the sibling designs (note only, not my spec):**
- *Reveal upgrade:* the pattern roll is a natural SECOND beat in the reveal (friend appears... then the pattern shimmers on). Hand the reveal team `patternIsNew` + `PatternConfig` and let them own the choreography. Recommend patterns ship WITH or immediately after the new reveal so the reveal has escalation material on day one.
- *Swap system:* patterns are the swap inventory that makes swapping interesting without touching anyone's friends. "Pattern sharing" under the gift spirit (giver keeps theirs) or whatever the swap team designs — the per-friend pattern SET storage is deliberately swap-ready (granting a pattern to another player is one map write, idempotent, additive).

---

## 2. CODES AS A PRESS CHANNEL (impact 4, effort S, recurring ~45 min/week)

**The gap.** The competitor's press footprint is ~90% codes articles. Codes articles are evergreen SEO pages that outlets UPDATE monthly — one placement compounds. We already have the entire redemption stack (`CodeService.lua`: server-side-only table, per-player persistence, normalization, attribution words per channel). What's missing is cadence, a canonical source editors can cite, and outreach.

**Cadence.**
- 2 scheduled codes per month (add on the 1st and 15th, batched into the Friday publish nearest those dates) + 1 code per named update + milestone codes (visits milestones: `1MSQUISHES`).
- **Codes NEVER expire.** This is Law (no LAST CHANCE) and it is also the single best editorial hook in the genre: every codes article about us gets to say "all codes still work" — editors love it because their page never goes stale, and it is a one-line demonstration of the no-pressure brand. Make "codes never expire in Squishy Smash" the standing first line of our codes pitch.
- Naming: storybook words in the existing voice — update-named (`SPARKLEPATTERNS`, `GOOCOAST`, `WONDER`), book-flavored (`SPLOINK` lineage), seasonal words that RETURN and say so. Rewards stay in the established band (150-300 coins, occasional keepsake cosmetic like the Storybook Halo — a code-exclusive cosmetic that is permanently redeemable is fine; one that vanishes is not).
- Mechanics note: the table is hard-coded in `CodeService.lua`, so a new code costs a publish. Extract it to a server-only `CodesConfig` module (10-minute refactor) and batch adds with the weekly publish. That is enough for a solo dev; a DataStore-backed live table is a someday, not a now.

**Canonical source of truth: squishysmash.com/codes.** One page on the existing Netlify site: current codes, rewards, how to redeem (3 screenshots), date added, "codes never expire" banner, and the game link. This is the page editors cite and aggregators scrape. Add `/codes` to the vanity-redirect set alongside /play /app /book.

**Outreach ladder (realistic for our size):**
- Tier 1 now (they cover small games and take submissions): RobloxDen (submit-a-game flow), TryHardGuides (tips email), Pocket Tactics, Roblox codes aggregators. Pitch = game link + /codes URL + the never-expire hook + "free capsules, no paid pulls" as the angle that makes us article-worthy beyond codes.
- Tier 2 at traction (~100K+ visits or a visible Up-and-Coming appearance): ProGameGuides, Sportskeeda, Destructoid, GameRant. These mostly chase search volume — they come when "squishy smash codes" has queries, which the Tier-1 pages and TikTok CTAs create. Chris's existing TIKTOK magic word already trains viewers to search for codes; every LIVE should say the codes page URL-free ("search Squishy Smash codes").
- Refresh the pitch on every named update (new code + one sentence of news = a reason to re-email).

**Fan wiki: seed it ourselves.** Create the Squishy Smash Wiki on Fandom with the structural pages fans and editors need: Codes (mirrors /codes — this is what aggregators scrape), the 56-friend roster (one sortable table + card-art gallery; we own the art), Sparkle Patterns odds + our own starter tier-list ("Community Pattern Rankings — add yours!"), Lands, and — counter-programming the competitor's scam-guide page — a "Kindness Guide" (how gifting works, why nobody can be scammed here). Label it honestly as started by the developer, open to fans. A dev-seeded wiki is standard practice; the point is that empty wikis never bootstrap at low CCU, and a structured one gives the first 50 fans somewhere to contribute. Maintenance: 15 min/week alongside the codes batch.

---

## 3. DISCOVERY METRICS — feeding the 2026 algorithm (impact 5, effort M)

The algorithm weighs D1/D7, session length, like ratio, and 7-Day Intentional Co-Play Days. Concrete changes per signal:

**D1 / first 90 seconds — get the drive-by kid to a capsule reveal.**
Current funnel (verified in `TutorialService.lua` + `GameConfig.lua`): welcome toast -> wake 3 sleepy friends (~9 clicks; a 3-pad starter cluster sits at spawn) -> +100 coins -> a TOAST says "Try the Sparkle Capsule!" -> first capsule is free (`FirstCapsuleIsFree`). The bones are good — the free first capsule already exists — but the handoff is a text toast, and a 6-year-old (or a bored 9-year-old algorithm tourist) does not read toasts. Fixes, in order of value:
1. **Capsule beacon on TutorialDone:** the moment the tutorial completes, the land's Sparkle Capsule starts visibly calling — a vertical light beam, a gentle bounce, and a client-side sparkle trail on the ground from the player to the capsule (particle breadcrumbs, cheap, StreamingEnabled-safe since the capsule is near spawn). Kill the trail on first `CapsuleResult`.
2. **Spawn facing the starter cluster,** nearest sleepy friend within ~8 studs, so the first squish happens inside 10 seconds. (WorldService spawn orientation tweak.)
3. **Frictionless first open:** the free capsule prompt fires the reveal immediately on ProximityPrompt trigger — no confirm step on the free one.
4. **Instrument it:** median time-to-first-CapsuleResult, via the existing batch-1 telemetry. Target: under 90 seconds at the median, under 60 for the fast path. This number is the D1 proxy; watch it weekly.
The story tutorial does not need cutting — 3 pops is ~30-45 seconds — it needs the FIRST minute to be squish-squish-squish-REVEAL, with the Lost Sparkle framing arriving after the first dopamine beat, not before. (The reveal upgrade team owns what happens when the capsule opens; this section's job is guaranteeing every new player REACHES that moment before the algorithm's patience runs out.)

**Session length — surface the depth the 12-minute competitor lacks.**
We have a coaster, slides, a zip line, teacups, a garden, photo spots, hidden bits, three lands. A first-session kid sees a hill and a capsule. Add a **Wonder Compass**: one HUD chip suggesting the single next undiscovered thing ("Ride the Sparkle Express!", "Something glitters near the pier...", "Plant your first seed!"). Rules: rotates only through things this player has NOT done (from the profile — discovered set, garden state, ride flags); never a timer, never a count-down, dismissible, one at a time. After the first reveal, the guide offers a three-way signpost moment (ride / hunt / plant) so the second five minutes is chosen, not wandered. This converts existing world depth into minutes without building anything new. Effort: S-M (client UI + a "done flags" slice in the snapshot).

**Co-play days — the measured invite loop.**
"7-Day Intentional Co-Play Days per User" means bringing a friend is an ALGORITHM input, not just warmth. Wire `SocialService:PromptGameInvite` (the platform's safe, consented invite sheet — no free text, fully Law-compliant) at pro-social peaks:
- Garden: when plants are grown-and-unwatered-by-others, the plot's sign offers "A friend could sprinkle these! Invite a friend" (kindness watering in `GardenService` is already the best co-play loop in the game — this makes it acquisitive).
- After receiving a gift: "Play together!" invite affordance on the thank-you beat.
- Photo spots: a with-a-friend photo gets a special frame border — then the invite prompt when a solo kid uses a 2-person spot.
- After co-op wins (Everybody Squish completion, Surge x2 window): the celebration screen carries the invite button.
Law check: every one of these is pure-upside framing (a friend ADDS bonus sparkle; nothing is ever gated on having friends), and PromptGameInvite is Roblox's own consent flow — no love-bombing vector, respects platform friend/privacy settings.

**Like ratio — the ethical version.**
Never incentivized (against Roblox rules AND gross). Pattern: after a genuinely joyful, EARNED beat — the finale, the first Rainbow upgrade, the first garden harvest — a small one-time toast: "Having fun in Pudding Hills? A thumbs-up helps other families find Squishy Smash." No reward, no button that pays, maximum two lifetime asks per player (persist a flag in the profile). Asking at joy-peaks is honest sampling; our 96%+ moments are real.

---

## 4. UPDATE CADENCE & UP-AND-COMING (impact 4, effort S — process)

Up-and-Coming measures growth velocity against OUR OWN baseline — a low-CCU game's superpower, because small absolute spikes register. The move is to stack every growth lever on the same weekend, every time.

**The rhythm (solo-dad realistic):**
- **Weekly publish, every Friday ~3pm ET** (before the weekend kid-traffic peak, feeding the 8:30 ET Friday LIVE): whatever shipped that week — a micro-feature, a new pattern, a codes batch, a fix wave. Friend of the Week already rotates itself (zero-work weekly content — say its name in the update notes anyway; "new visitor every week" reads as liveness).
- **Named update every 4-6 weeks**, batched from the weekly work but ANNOUNCED as an event: The Sparkle Patterns Update, The Wonder Update, The Garden Party Update. Each named update = new code + thumbnail refresh + update-notes post + a LIVE built around it + the press re-pitch (section 2). Naming rule: the update is named for the thing a kid can DO, in our verbs.
- **Title tag liveness:** append the current named update to the title — "Squishy Smash [SPARKLE PATTERNS]". Signals an alive game in search results next to the competitor's daily-update energy, at zero mechanical cost. Never "LAST CHANCE", never countdown language — the tag is an invitation, not a deadline.

**Icon / thumbnail CTR strategy.** Roblox has no native icon A/B, so alternate deliberately: two icon candidates, two weeks each, compare impressions-to-plays by surface (Home vs Search) in Creator Analytics; keep the winner, challenge it next cycle. Kid-CTR heuristics for candidates: ONE big-eyed friend face filling ~60% of frame, high saturation, capsule or rainbow burst behind, at most two words of text (thumbnails legible at 100px). Refresh the primary thumbnail every named update (the update's hero — a Golden Crumb friend, the garden, the coaster) but keep the ICON's silhouette stable once a winner emerges: the icon is brand memory, the thumbnails are news.

**What to batch vs. drip:** drip small visible things weekly (patterns are perfect drip content — add pattern #9, #10 over time; each is one config entry); batch structural work into the named updates. Never hold a fix for a beat.

---

## 5. THE REFUSE LIST — what we will not do, and what it honestly costs (impact 3 direct / 5 strategic, effort S)

**Refused: paid capsule pulls / crates.** Their revenue engine and their retention whip. *Honest cost:* we forgo the genre's highest-ARPU mechanic; our per-player revenue will be a fraction of a crate game's, and Robux-funded UA (buying ads with crate margin) is off the table. *Counter-position:* LTV through longevity and the cross-media funnel (books, site, future plush) — a trusted game gets YEARS of a childhood and the parent's willing wallet for style passes; a crate game gets 74 days. Free capsules with published odds is also our single strongest press sentence.

**Refused: FOMO — timers, decay, vanishing limiteds.** *Honest cost:* urgency is a real DAU multiplier; "last day for Galaxy" spikes are a large part of the competitor's 690K/day. We give up the log-in-or-lose lever entirely. *Counter:* our re-engagement is pull, not push — the offline garden literally grows while you're away (coming back is a gift, not a rescue), streaks forgive a missed day, and returning seasonal things SAY they return. Calm is retention for 6-9s whose sessions are parent-scheduled anyway — you cannot FOMO a kid whose screen time ends at 7pm, you can only make her sad.

**Refused: open trading with player-set values (and any steal/loss mechanic).** *Honest cost — the big one:* the trade meta IS the competitor's content ecosystem. Tier lists, value hubs, scam guides, trade-win TikToks — all of it exists because items have negotiable prices. Refusing open trading refuses that ecosystem's engine. *Counter:* Sparkle Patterns rebuild the RANKING conversation (rarity, beauty, hunt spots) without negotiable value, and the sibling swap system — under the owner's re-examined lock — can rebuild the EXCHANGE conversation with the spirit intact: whatever ships, a 6-year-old must never be talked out of her collection, never scammed, never sad after. Note for the swap team: Adopt Me's Trade License pattern (a 3-question safe-or-scam quiz gating higher-stakes exchange, plus history and reporting) is the proven all-ages template if the lock loosens; it is platform-legal for our age band. Meanwhile "nobody can be scammed here" is itself a content angle their game hands us daily — their own wiki lists seven scam patterns; ours lists zero because zero are possible.

**Refused: scam-drama and outrage content.** *Honest cost:* scam exposés and trade-betrayal storytimes are high-engagement TikTok fuel we will never touch. *Counter:* Chris has the one asset no studio can copy — a dad who built the game for his three daughters, who are IN it as earnable Family cards. Wholesome unboxings, family playtests, the book-to-game pipeline. Sincerity is the differentiation; in a feed full of scam drama it also reads as relief.

**Making it legible to PARENTS (store copy).** Add a trust block to the game description, plain words, near the top: "Made by a dad for his three daughters. Sparkle Capsules are always free — earned in game, never bought. No trading, no scams: sharing a friend never costs you yours. Nothing expires, nothing counts down. Purchases are cosmetic only." Mirror it on squishysmash.com/parents. *Does it matter to the 6-9 kid?* Directly, almost none — kids choose by thumbnail, friends, and TikTok. But the PARENT is the gatekeeper of the install (parental controls), the spend (Robux approval), and — most underrated — the word-of-mouth channel (school-parent group chats are a real distribution network for "a game that's actually safe"). The kid-facing surfaces stay pure fun; the trust copy aims one layer up, where the veto and the wallet live.

---

## 6. THE WAVE QUESTION — ride the traffic, position against the mechanics (impact 4, effort S, window ~30-60 days)

**Recommendation: both, split cleanly.** Ride the SEARCH WAVE; refuse the mechanic wave.

The reasoning: the Roblox dumpling games are individually burning down (competitor -87% from peak, 12-minute sessions) but the UNDERLYING driver — the real-world blind-box squishy craze (Labubu, Sonny Angel) — is a multi-year toy trend. "Squishy" search interest outlives any single fad game. And we are not wave-chasers wearing a costume: the game has been Squishy Smash with actual squishies since before the wave. We own the word legitimately.

Concretely:
- **Keep "Squishy" maximally prominent** in title, description first line, and tags. Title format: "Squishy Smash [CURRENT UPDATE] — Collect Squishy Friends". Description first sentence should contain squishy, collect, and friends (the search terms the dumpling audience uses). Genre stays Simulation (where that audience browses).
- **Target the churn, gently.** Roughly 24K peak-CCU worth of players liked collecting squishies and left a game that gave them short sessions and scam anxiety. TikTok/Shorts content aimed straight at them, positively framed: "the squishy game where your collection is safe forever", "free capsules — yes, actually free", pattern-hunt videos, garden welcome-backs. Never name the competitor in kid-facing surfaces; on Chris's adult-facing TikTok, "if squishy trading games left you burned..." is fair and effective.
- **SEO capture:** the /codes page + wiki (section 2) exist to rank for "squishy game codes"-shaped queries the wave generates. This is the durable residue of the wave — build it now while volume is high.
- **Do NOT clone the aesthetic** — no crate/steamer visuals, no dumpling-clone thumbnails. The storybook look is the shelf differentiation; a clone thumbnail buries us in a row of identical fad games that are all declining together.
- **Timing honesty:** wave traffic decays on the competitor's curve — treat the next 30-60 days as the discounted-attention window, then the position quietly converts to the evergreen one: the collector game parents trust. Everything in sections 1-4 is the moat that outlasts the wave.

---

## FIRST 30 DAYS — solo-executable sequence (alongside Tue/Fri TikTok LIVE + the book funnel)

*Rule of thumb: game-code work Mon-Wed, publish Friday 3pm ET, LIVE Friday 8:30, press/wiki touches in 30-minute Saturday slots. Nothing here assumes a second person.*

**Week 1 — the funnel and the shelf (mostly S tasks).**
- Build: capsule beacon + sparkle-trail on TutorialDone, spawn-facing fix, frictionless free-first-open, time-to-first-reveal telemetry. (The D1 lever — do this before anything else.)
- Build-small: ethical like-prompt (2-lifetime-cap flags), PromptGameInvite at the gift-received beat (first of the co-play hooks).
- Ship words: store-copy parent-trust block + title/tag SEO pass + genre/tag audit.
- Web: squishysmash.com/codes page + /codes redirect; extract `CodesConfig` from CodeService; add 2 new codes to launch the cadence.
- Outreach: submit to RobloxDen + TryHardGuides + Pocket Tactics with the never-expire hook.
- Friday publish + LIVE theme: "the game got easier to fall into" (show the beacon path on stream).

**Week 2 — Sparkle Patterns (the M build).**
- Build: PatternConfig + server roll in CapsuleService + profile/StateSync slices + applyPattern in SquishyModelFactory + Book pattern chips + WearPattern remote. Hand `patternIsNew` + config to the reveal-upgrade sibling for choreography; confirm the swap sibling sees the per-friend pattern-set storage shape before it ships.
- Web: seed the Fandom wiki (Codes, Friends roster from card art, Patterns odds + starter tier-list, Kindness Guide).
- Friday publish: patterns can soft-land dark (config in place, rolls off) if the reveal integration isn't ready — do not rush the reveal team's beat.

**Week 3 — THE SPARKLE PATTERNS UPDATE (the stacked spike).**
- Everything fires the same weekend: named update live, title tag flips to [SPARKLE PATTERNS], new thumbnail (a Golden Crumb hero), code `SPARKLEPATTERNS`, wiki updated same hour, press re-pitch to Tier 1 with the news, Friday LIVE is a pattern-hunt show (roll capsules on stream, chase a Moonlit in Moonlit Hollow), book funnel cross-post. This is the Up-and-Coming velocity play: one coordinated spike against a small baseline.
- Build-light this week (the update IS the work): Wonder Compass v1 if capacity allows, else it moves to week 4.

**Week 4 — co-play + measure + set the rhythm.**
- Build: garden friend-watering invite prompt + photo-spot friend-frame + co-op-win invite affordance; Wonder Compass v1 if it slipped.
- CTR: swap to icon candidate B for its two-week window; log the candidate-A baseline from Creator Analytics.
- Measure and retro against the four algorithm signals: median time-to-first-reveal (target <90s), average session length (target: beat the competitor's 11.9 min — we should, with the Compass), co-play days (any movement from the invite hooks), like ratio (should hold 95%+ with the ethical prompt). Codes attribution counts tell you which channel worked.
- Set the standing calendar: codes on the 1st/15th, Friday publishes, next named update ~week 8 ("The Wonder Update" — Wonder Compass + 2 new patterns + whatever the swap team has landed).

**What is deliberately NOT in the 30 days:** the reveal upgrade and the swap system (sibling-owned; weeks 2-3 create their landing zones), cross-server anything (MemoryStore pools only matter at liquidity we don't have yet), paid UA, and any Discord community push (a dead Discord at single-digit CCU is worse than none — revisit at sustained triple-digit CCU).

### Law compliance (as assessed by the design agent)

Bullet-by-bullet against THE LAW:

- Kid-safe verbs / vocabulary: every new surface uses the canon lexicon — Sparkle Patterns, Wonder Compass, Kindness Guide, "a cozy friend appeared". Pattern names are food/storybook words (Berry Swirl, Honey Glaze, Golden Crumb). No combat/horror/vulgar anywhere in the plan.
- Free capsules forever / no paid randomness: patterns roll only from free earned-coin capsules; the plan explicitly REFUSES paid pulls (section 5) and quantifies the revenue cost honestly. Published odds strengthen this lock rather than bending it.
- Every friend stays earnable: patterns are additive cosmetics on friends, all obtainable forever from any capsule; land-biased odds change WHERE hunting is best, never WHETHER something is obtainable. Code-exclusive cosmetics remain permanently redeemable (never-expire codes).
- Trading lock + its spirit: this plan builds NO trading. It designs pattern storage to be swap-ready for the sibling system and flags the Adopt Me license pattern as the proven all-ages template IF the owner loosens the lock — spirit preserved: nothing in patterns is losable, gift semantics (giver keeps theirs) are assumed for any pattern sharing.
- Style/convenience monetization only: no new monetization is introduced; the refuse list re-commits to it.
- No pressure mechanics: DELIBERATE BENDS EXAMINED — (1) the title tag "[SPARKLE PATTERNS]" is liveness signaling, not a deadline; no countdown or LAST CHANCE language is ever used. (2) Land-biased pattern odds create hunt structure; compliant because every pattern drops everywhere, always, with odds posted openly. (3) The stacked update-weekend spike is marketing rhythm, not in-game urgency — nothing in-game expires. (4) Wonder Compass suggests, never counts down, dismissible. Codes never expire — the anti-FOMO rule turned into a press hook.
- Pure-upside care loops: friend-watering invites and photo-frame bonuses only ADD sparkle; nothing is gated on having friends or logging in.
- No losers: pattern rolls have no misses (Classic is guaranteed at discovery; every dupe adds coins even without a new pattern via the existing +15 flat bonus on new ones and existing dupe coins otherwise).
- No free-text from kids: like-prompt is a toast with no input; invites use SocialService:PromptGameInvite (platform consent sheet); pattern wearing is a preset toggle; wiki/press work is adult-side.
- Stranger safety: no new stranger surfaces; invite prompts respect platform privacy settings; StreamerMode masking is untouched.
- Server-authoritative: pattern rolls, WearPattern validation, like-prompt lifetime flags, and code redemption all live server-side (CapsuleService/PlayerDataService/CodeService hook points cited from the real files).
- Honest-marketing bend: competitor contrast content is confined to adult-facing channels and never names the competitor in kid-facing surfaces; the ethical like-ask is unincentivized and capped at two lifetime prompts, complying with Roblox's incentivized-rating rules.

### Effort estimate

Overall L across 30 days for a solo dev, decomposed: D1 funnel fixes (beacon/trail/spawn/telemetry) = S-M, touches TutorialService, WorldService spawn, CapsuleService prompt, client FX + batch-1 telemetry. Sparkle Patterns = M, the one real feature: new PatternConfig (Shared), CapsuleService roll (~lines 98-128), PlayerDataService schema + StateSync slice, SquishyModelFactory applyPattern generalizing applyGolden (line 657), Book UI chips + WearPattern remote, BuddyService pass-through — zero asset uploads. Codes channel = S one-time (CodesConfig extraction, /codes page on the existing Netlify site, wiki seeding) + ~45 min/week recurring. Co-play invite hooks = S (PromptGameInvite at 3-4 existing beats in GardenService/GiftService/PhotoSpotService). Cadence/CTR/store copy = S, process + metadata only. Wonder Compass = S-M, client UI + done-flags snapshot slice (allowed to slip to week 4/8). Nothing touches the reveal choreography or swap mechanics (sibling-owned); their integration points are one payload field and one storage shape.

### Viral impact (honest)

3.5/5, honestly. What this plan reliably buys: a materially better D1 funnel (the highest-leverage algorithm input), a rankable collection space that gives fans and the swap system something to talk about, a compounding SEO/press surface (codes + wiki) that the competitor proved works even for small games, and a coordinated-spike rhythm tuned to how Up-and-Coming actually measures growth. What it cannot buy: the spark itself — virality for a single-digit-CCU game still hinges on Chris's TikTok content catching, a creator picking it up, or the wave-churn audience actually converting; no in-game system manufactures that. The plan's real claim is asymmetry: if a spike comes from ANY source (a LIVE that pops, a book reader wave, one lucky Short), the game now converts and retains it instead of leaking it, and the algorithm sees the retention. I'd rate it 5/5 as substrate, 2/5 as spark — 3.5 blended. The single biggest risk to impact is sequencing drift: if the week-3 stacked spike is diluted (patterns shipping quietly across three Fridays instead of one named update), the Up-and-Coming velocity play is lost while the work cost stays identical.
