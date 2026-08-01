# 14 — Fun Upgrade Plan: "A World That Grows With You"
### Build directions for Opus 4.8 (or any Claude Code build agent)

*Written 2026-07-18 by Fable 5 from a 10-agent review (4 code-review lenses on
the live game, 4 asset sweeps across every Builder Hub project, 2 research
passes on top 2025-26 kid Roblox games + play psychology for ages 6-9), then
adversarially fact-checked against the repos and design-audited against the
game's own locks. This doc is the work order. Build in §6's order; each Work
Order (WO) is one buildable, verifiable, publishable unit.*

---

## 0. How to use this document

1. **Read `CLAUDE.md` at the repo root first** — it has the full file map, the
   dev loop (`rojo serve` on port **34872**, Rojo plugin in Studio, then Play),
   and the server↔client contract. This doc does not repeat it.
2. **Build in §6's order, one WO at a time.** Build → playtest in Studio (MCP
   or manual) → verify → commit → push. Chris publishes (Alt+P) — a
   **creator-only human gate**; nothing reaches the kids until he publishes and
   old servers cycle out. Never claim something is "live" — say "built,
   verified in Studio, awaiting publish."
3. **Every UI-touching change must also be verified in compact/mobile HUD**
   (set the `ForceCompactHud` attribute on LocalPlayer): no overlap, nothing
   offscreen, screenshot both modes. This is a standing acceptance criterion
   for every WO — the girls play on phones/tablets.
4. **Validate with the focus group.** Chris's daughters (8/8/6) are the real
   QA. After each shipped WO, give Chris one thing to watch for when the girls
   play (docs/12_PLAYTEST_CHECKLIST.md has the format).
5. **The Law (§1) and the Landmine List (§2) override everything else here.**
   If a direction in a WO conflicts with §1, §1 wins — flag it, don't build it.

Priorities: **P1** = biggest fun payoff. Effort: S (< half a day), M (a
day-ish), L (multi-day). Risk notes flag anything touching uploads/moderation.

---

## 1. THE LAW (design locks — never violate, never "improve")

- **Kid-safe, storybook-safe.** No combat, weapons, horror, scary, vulgar,
  romance, blood. Verbs: squish, squeeze, bounce, boop, pop, sparkle, discover,
  collect, decorate, help, friendship.
- **Vocabulary:** Joy Meter (not health) · Squish Power (not attack) · Happy Pop
  (not defeat) · Squishy Friends (not enemies) · Play Zone (not arena) ·
  Discovered (not won/pulled).
- **Sparkle Capsules stay FREE forever** (earned coins only). No paid
  randomness of any kind, ever. Every friend stays earnable.
- **NO trading.** Gifts only — sharing a friend never costs the giver theirs.
- **Monetization sells style & convenience only.** No coin packs, no power.
- **No pressure mechanics.** Nothing decays, nothing is ever lost for taking a
  day off, **nothing visible ever counts down or goes backward**, no
  "LAST CHANCE" FOMO. Limited-time things always come back and SAY SO in their
  UI. No sad/hungry/neglected states — care loops are **pure upside** (caring
  adds sparkle; not caring changes nothing). **Copy rule:** no text may imply
  anything felt bad, waited, or lacked while the player was away ("your buddy
  is SO happy you're back!" — never "your buddy missed you").
- **No losers.** Races/contests celebrate every finisher; likes-only voting
  (no downvotes, no elimination, no single-winner contests that shame the 6yo).
- **No free-text input from kids** (names, messages). Preset pickers only.
- **Stranger-safety by default.** New player-to-player interactions need:
  per-pair server cooldowns, respect for the local block list, richer FX
  reserved for Roblox friends, and display names shown only for Roblox friends
  (everyone else is "a kind visitor"). Love-bombing and pile-on must be
  mechanically impossible.
- **Server-authoritative everything** that grants coins/items/progress.

---

## 2. THE LANDMINE LIST (hard-won gotchas — read before touching code)

**Engine / Luau**
- **Client owns character physics.** Server writes to a character's
  `AssemblyLinearVelocity` don't stick. Bounce/launch = server tags parts
  (`SquishyBouncy` + attrs) + client applies velocity (`BouncePads.lua` is the
  pattern). Proven empirically — don't re-litigate.
- **`RenderFidelity`/`CollisionFidelity` are edit/plugin-only writes.** A
  runtime script write THROWS ("lacking capability Plugin") and takes the whole
  build down. Bake onto the `ServerStorage.MeshBodies` templates in Edit (via
  the MCP plugin), never at runtime.
- **Never touch mesh `SurfaceAppearance.AlphaMode`** — Overlay is correct; the
  card meshes composite a ColorMap over a grey base. A grey/white friend for a
  beat on stream-in is texture download lag, not a bug.
- **ProximityPrompt parented to a Model silently never renders** — must sit on
  a BasePart.
- **Luau parse trap:** `T.Field: Type = x` (type annotation on table-member
  assignment) is a parse error that takes down every requiring script. Use a
  typed local, then assign.
- **Never rotate an archetype's Body part** in SquishyModelFactory — the model
  pivot inherits the rotation and `PivotTo(identity)` tips the shape over.
- **Never `:Play()` a Sound the same frame you set `SoundId`** — preload/gate
  it (pattern in New-roblox-game's CLAUDE.md).
- **Glyphs:** 🪙 and ✕ render as boxes in Roblox fonts. Proven-good:
  ⭐✨💝🎁🧸💖🌈😄. Write "150 coins", "X" for close. (WO-8 uploads a real coin
  glyph image that fixes this properly.)
- **StreamingEnabled:** far lands don't exist client-side until you're near.
  Verifying a far zone = teleport the character there first (wait 5-10s).
  Client FX must re-attach on `ChildAdded` when parts re-stream (SquishFx
  does).
- **World geometry rule (Chris taught us three times):** use the WHOLE land.
  New structures default to their own district, never piled at spawn. Positions
  authored compact get `spread()`/`spreadAbs()` via ZoneConfig.Spread (1.45).
  ZoneConfig `shardSpots` are FINAL post-spread literals — never re-spread
  them.
- **Studio local-server test players aren't real accounts** — `IsFriendsWith`
  and block lists return empty, so friends-vs-strangers branches are
  untestable solo. Add OwnerDebug overrides (`treatAsFriend:UserId` /
  `treatAsStranger`) when building any such branch, and flag the real-account
  behavior as a family-playtest checklist item.

**Uploads / moderation (this account has been falsely banned twice)**
- **Textured-mesh uploads are HIGH-RISK** (auto-extracted UV atlases of pink
  kawaii characters false-flag as sexual content). Rules: eyeball every texture
  first; trickle ONE upload per ~8 min with a moderation check between
  (`tools/mesh_pipeline/trickle_upload.ps1` is the template); NEVER batch
  images or meshes. The account is shared with Gnarly Nutmeg — either game's
  uploads can 403 both. At any 403 storm: check Roblox messages for a
  moderation notice FIRST.
- **Audio cadence (the one allowed steady drip):** wordless SFX have cleared in
  minutes with zero flags ever — upload at most ~1/min, pause for a
  moderation-status check every 10, HARD-STOP at the first flag and check
  Roblox messages. Never faster; never images/meshes at this cadence.
- **Risk ladder (empirical):** wordless SFX = minutes, zero flags ever · cute
  illustrated cards/icons = fast · instrumental music = slow (hours-day;
  publish only AFTER Approved) · spoken-word audio = real review, probe ONE
  clip first · textured meshes = the danger zone.
- **Already-uploaded assets on Chris's account (creator userId 7230402132) are
  ZERO new moderation risk** — insert by existing assetId. §3 lists which
  pools are genuinely uploaded vs local-only. **Do not assume; check the
  upload-state JSON for an assetId before calling anything "Approved."**
- **Decal ids render BLANK in ImageLabels.** Images upload as Decals; resolve
  to the underlying Image id in Studio (`InsertService:LoadAsset` →
  Decal.Texture). Audio ids are usable directly; audio upload is free
  (2000/30 days).
- **All Roblox/Meshy/ElevenLabs API calls must use PowerShell 5.1 / .NET**
  (Invoke-RestMethod / HttpClient with hand-built MultipartFormDataContent —
  5.1 has no `-Form`). Norton's TLS interceptor breaks curl and Python HTTPS.
  Keys live in `HKCU:\Environment` (read the registry; never print values).
- **New-roblox-game's upload-state JSONs are UTF-8 with BOM** — Python needs
  `encoding='utf-8-sig'` (or use PowerShell `ConvertFrom-Json`).
- **MCP creator-store search/insert is UNSAFE for audio** (once inserted a
  random meme song). Insert known ids only, or `AssetService:SearchAudio`.
- **Verify `game.GameId == 10292103666` / PlaceId 105594294243426** before
  resolving assets or trusting a Studio window — rojo once dressed a throwaway
  baseplate up as the real place. `servePlaceIds` locks the plugin but not
  HTTP-API mini-syncs.
- **Studio-only quirk:** a `serverplaceid=0` delivery quirk makes some live
  images/audio read not-loaded IN STUDIO while fine in the published game.

**Operational**
- After every publish, remind Chris: **Creator Hub → Restart Servers for
  Updates** (only matters if servers are live) + close his own client before
  Studio work. Old servers autosaving stripped his profile once.
- **Pass creators self-own their passes** — Chris's account can't test the
  unowned state; use the girls' accounts or `OwnerDebug` (`grantPass:KEY`).
- Playtests during a moderation flag run on **temp profiles** (DataStores 403)
  — the refuse-to-overwrite guard protects real saves; don't panic.
- **Do NOT fill StoryPageConfig captions** — the page art already has the book
  text printed on it. (A reviewer suggested it; it's wrong.)
- **Known data wart:** RarityConfig (55/25/12/6/2) and CapsuleConfig's local
  RARITY_WEIGHTS (50/26/14/7/3) diverge — **CapsuleConfig's is the live one**.
  If you touch capsule logic, unify to one source of truth first.
- **Skip Experience Notifications entirely** — the opt-in API is 13+ only; the
  6-9 core audience cannot receive them. Decision documented here on purpose.
- Meshy budget: ~970 credits remain ≈ 30 meshes. Spend deliberately.

---

## 3. THE ASSET TREASURY (what exists, where, and its risk level)

**In this repo, unused or under-used**
- `data/raw/*.json` — per-friend fields DROPPED at generation: `deformability`,
  `elasticity`, `gooLevel`, `burstThreshold` (hand-tuned 0-1 squish-physics per
  friend!), `behaviorProfile` (6 archetypes), `searchTags`, pack `palette` hex
  triads, `packProgression` pity tables, and a fully-specced dormant 4th-land
  event pack (`dumpling_squishy_drop_01`; see WO-11 for the zone-name strings).
- `SquishyDefinitions.lua` — committed but never read: `ParticlePreset`,
  `DecalPreset`, `Category`, `UnlockTier`, `Feeling` (one display line only).
- `marketing/sfx_audition/` — 6 alternate ElevenLabs takes, never uploaded.
- `archive/qb1/` — working arc-projectile/target/round/score services (the
  "Sparkle Toss" minigame is ~80% written).
- Pipelines (all PROVEN): `tools/card_art/` (card → Decal → Image id),
  `tools/mesh_pipeline/` (card → Meshy → MeshBodies), `marketing/
  make_product_icons.py` (moderation-cleared icon factory), ElevenLabs
  SFX/ambience/music via .NET (SoundConfig wiring pattern + `pick()` pools).

**Book/mobile repo — `C:\Users\chris\Squishy-smash` (nested `squishy_smash\`)**
- **225 per-friend squish/burst mp3s** (`assets\audio\creature|food|goo`) —
  3 squish variants + 1 burst PER FRIEND, ElevenLabs-owned. The single biggest
  unused audio asset. (Roblox today has only 3 shared signature families.)
- **The Lost Sparkle audiobook in TWO voices** — ElevenLabs George
  (`C:\Users\chris\squishy_book2_audiobook_v1.mp3`, 337.6s) AND Chris's own
  voice (`C:\Users\chris\squishy_book2_chris.mp3`, 394.1s). **The SRT
  (`squishy_book2_readalong_horizontal_george_master.srt`) is timed to the
  GEORGE master only** — splitting Chris's longer take needs re-timing first
  (see WO-8.4).
- `assets\audio\vo` — 24 rarity-reveal/celebration VO clips (AUDIT VOCABULARY
  before use — mobile-era lines may say "burst/combo"); `assets\audio\ui` —
  8 UI sounds; `assets\audio\sfx\combo` — 8 escalating combo jingles (map to
  chains).
- `website\public\sprites\*.png` — 48 clean 512px transparent character
  sprites, upload-ready (gift picker, quest icons, badges, tent posters).
- `assets\images\decals` (11 splat/burst decals) + `glyphs` (coin/sparkle/
  check/lock — **coin.png fixes the 🪙 gotcha**).
- Text gold: `book\STORY_BIBLE.md` ("a squishy is a wish that found a shape";
  the Squishkeeper; "a pop is a hello"), `book\manuscript\02_manuscript_v2.md`
  (per-friend field-guide: "Squishkeeper says" quotes, "First spotted at"
  places, signature onomatopoeia), featured-character bio sheet → Collection
  Book flavor text, tent copy, lore plaques. Zero uploads, zero moderation.
- `book\spread_poc\plate_*.png` — character-free watercolor paintings of the
  exact 3 lands → travel-pad destination previews.
- Hero renders (24), arena backdrops (16, incl. a "reveal" variant per theme →
  CapsuleRevealUI backdrops), all-48 poster (`commerce\print_ready`),
  coloring-pack lineart (8), 3 legendary squish animation strips (flipbook for
  reveals).
- Brand font: **Fredoka is a built-in Roblox Enum font** — one UiTheme
  constant brand-matches the game to the book/app for free.

**Other projects — key finds**
- `C:\Users\chris\New-roblox-game` (built deliberately on Squishy's
  architecture; modules port near-verbatim):
  - **15 kid pet meshes ALREADY uploaded + Approved** (bunny, kitten, axolotl,
    puppy, hedgehog, penguin chick, fox kit, bear cub, panda, red panda,
    piglet, baby dino, baby dragon, phoenix chick, unicorn foal) — ids in
    `tools\upload_results\game_assets.json` (BOM! utf-8-sig) +
    `CompanionPerch.luau` shoulder-weld pattern → a "Shoulder Pals" Boutique
    shelf with ZERO moderation risk.
  - **Uploaded prop_* meshes (17, same file, ok:true + assetId):** kid-safe
    subset usable by id today — market_stall, street_lantern, signpost,
    village_well, gate_arch, hay_bale, barrel, campfire, crate_stack,
    quest_board, shop_sign, tent, treasure_chest. (Skip anvil_forge,
    weapon_rack, potion_shelf, gold_pile — off-Law or off-theme.)
  - **The 46 `tools\houses` village GLBs (lamp_post, market_cart, bench_wood,
    rowboat, telescope_brass, mushroom_cluster…) are LOCAL ONLY — no Roblox
    assetIds exist.** Using them means the full HIGH-RISK textured-mesh
    trickle pipeline. Do not call them Approved.
  - **`Telemetry.luau`** — AnalyticsService wrapper. Squishy is LIVE with real
    players and monetization and has ZERO analytics. Highest-leverage code
    harvest in the entire sweep.
  - `src\first\Boot.client.lua + LoadingUi.luau` — branded ReplicatedFirst
    loading screen (code-built, zero assets).
  - `tools\skyboxes\` — **uploaded face ids exist for dawn, bridgeton,
    archivelibrary, fray (state_wave2.json). The NIGHT set is rendered but NOT
    uploaded** — local PNGs at `tools\skyboxes\out\night_*.png`; trickle the 6
    faces (plain sky images, low risk) before any night-sky work.
  - `tools\anim_pipeline\glb_to_rbxmx.js` — GLB → KeyframeSequence converter.
  - `tools\dialog_vo\` — batch ElevenLabs VO → upload pipeline with resume.
- `C:\Users\chris\Roblox-gnarly-nutmeg`: **`BadgeService.lua`** (pcall-guarded,
  id=0 no-ops) + badge-icon PS1 pipeline; **`PhotoMode.lua`** (one-tap kid
  cinematic camera, pure client — direct port).
- `C:\Users\chris\3D-assets\Appalachai-Assets\data\asset-forge\runtime\outputs\`
  — ~190 finished Meshy models on disk incl. **15 NEW squishy-style characters**
  (`squishy_*`: avocado, axolotl, banana, butter, capybara, cat_loaf, cheese,
  donut, duck, fried_egg, frog, mushroom, peach, seal, strawberry) with JSON
  defs = a ready roster-expansion wave, plus Meshy versions of most existing
  roster friends. (Textured-mesh trickle rules apply to anything not yet
  uploaded.)
- Minigame SPECS (pattern-only, Luau rewrite): App-store cleaning-game ("clean
  to reveal" → Squishy Bubble Bath), sorting-game (→ Tuck-In Time),
  balance-game (→ Pudding Cup Tower), Free-fall (→ Sparkle Dive rings),
  GhostSprint (→ Sparkle Sprint fun-run PBs).
- SKIPPED on The-Law grounds: anything combat/horror-flavored, all
  bot/foe/weapon/hazard meshes, unverified-license model zips.

---

## 4. THE FIVE PILLARS OF THIS UPGRADE (why these WOs, in one breath)

1. **Juice the verb** — the 500th Happy Pop must feel better than the 1st, not
   identical. Anticipation ramps, rarity-scaled celebration, chains, surprise.
2. **Something grows because you came back** — the missing engine. Buddy Bond +
   the Sparkle Garden give the game a nurture loop with zero pressure.
3. **Better together, on purpose** — sisters need verbs (boop, race, visit,
   pose, water) not just proximity. Kindness is the game's brand; make it
   playable — and stranger-safe.
4. **Always a tomorrow** — renewable config-driven reasons to return (rotating
   quests/bits/shelves/weekly beats) that never demand a publish.
5. **Spend the treasury** — hundreds of finished, owned assets are sitting in
   folders. Wire them in before generating anything new.

---

## 5. WORK ORDERS

### WO-0 · Guardrails (economy · toasts · FX budget) — P1, effort M, do FIRST
Three cross-cutting budgets every later WO must respect.

1. **Economy model:** before building WO-1/3/5, model a 30-min session's coin
   income at three stages (new player / mid-game / endgame bit-router) as a
   small script or spreadsheet checked into `docs/economy/`. Rules: stacked
   multipliers are CAPPED — weather (WO-6) and Surge do NOT stack (take the
   max); chain bonus caps at +5; co-squish pays full to both but doesn't chain
   twice. Price every new sink from the model. **Acceptance: post-upgrade
   top-end income ≤ ~1.5x current top-end.**
2. **Toast queue:** a priority queue in ToastUI — max 1-2 visible, order
   celebration > social > info, coalesce duplicates, never stack banners.
   First-session pacing gate: fresh profiles get at most one "new system"
   introduction per play session. **Acceptance: trigger surge + weather +
   chain + gift simultaneously → an ordered queue, not a pile.**
3. **FX budget:** pooled particle emitters + a global cap in SquishFx
   (simultaneous burst cap; ~0.5 particle scalar in compact/mobile mode); a
   "Calm Sparkles" toggle that halves FX intensity; no full-screen flashes.
   **Acceptance: 5 simultaneous Legendary pops holds playable frame rate on
   the weakest test device.**

### WO-1 · "Juice the Squish" — P1, effort M, **zero uploads, zero server risk**
All client-side in `SquishFx.lua`/`HudUI.lua` (+ one small server piece), using
data the client already has (`result.joy`, `def.Rarity`, def fields).

1. **Escalating 3-click arc:** squash amplitude 0.16→0.20→0.24 and squish pitch
   0.96→1.05→1.15 keyed off `result.joy`; at joy ≥ 0.67 an "about to pop" state
   (fast shimmy, Joy bar pulse, rising sparkle dribble). Anticipation is free.
2. **Rarity-scaled Happy Pop:** sparkles 26/40/60/90 by rarity (within WO-0's
   FX budget); Rare+ adds a second white burst; Epic/Legendary a brief golden
   light + longer "ta-da" + toast ("WOW! A Legendary Happy Pop!").
3. **Sparkle Chain (server + client):** per-player {count, lastPopAt} in
   SquishService; pop within ~10s chains. +1 coin per step, cap +5. Client
   shows escalating "POP x2! x3!" floaties with rising pitch; x5 = confetti
   ring. **Never show a chain-lost message** — it quietly starts fresh.
4. **Telegraph rare sleepers:** gold-tint the zZz + soft sparkle column for
   Rare+, snore-bubble that inflates and pops for Epic/Legendary. Optional
   land-local toast ("Somewhere in Goo Coast, a very special friend is
   napping…") — **only to players who have that land unlocked** (check
   TravelService state); a treasure-map sentence, never a timer.
5. **Per-friend squish FEEL:** merge `deformability/elasticity/gooLevel/
   burstThreshold` from `data/raw` into SquishyDefinitions (regenerate or a
   merge table); squash scale = deformability, rebound speed = elasticity, pop
   particle volume = gooLevel. 56 friends stop feeling identical.
6. **Wire `ParticlePreset`/`DecalPreset`:** preset→{colors, splat} lookup; pops
   get per-friend colored bursts + a brief fading ground splat.
7. **Silly reaction roll:** ~1-in-6 non-pop squishes trigger a per-archetype
   extra (spin, sneeze+achoo squeak, hiccup hop, jelly wobble, ear flutter);
   ~1-in-12 pops get extra-silly (helium-pitched signature squish via
   PlaybackSpeed, confetti sneeze). Cosmetic only, no reward difference.
8. **Spawn reveal + HUD juice:** respawns grow-in (ScaleTo 0.1→base, Back ease)
   with a poof + yawn squeak — every 1.2s respawn becomes a mini mystery-box.
   Coin pill count-up tween + 1.0→1.15→1.0 bounce on increase.
9. **Instant click feedback:** local micro-squash + soft "pmf" on click
   (rate-limited ~10/s) so mash-clicks always get SOMETHING; authoritative
   SquishResult still drives Joy/pop.

*Verify (mechanical, not vibes):* log particle count per rarity pop (26/40/60/
90 within budget), log the pitch curve values per click, screenshot a
Legendary sleeper's gold zZz, chain to x5 and screenshot the floatie, watch a
respawn grow-in, mash during cooldown and confirm local feedback. Compact-HUD
screenshot per §0.3.

### WO-2 · "Kindness & Together" — P1, effort M-L, no uploads
The sisters need verbs. All patterns already exist in the codebase.
**Stranger-safety rules from §1 apply to every item here.**

1. **Player Boop:** clone GiftService.attachPrompt's ProximityPrompt pattern —
   a "Boop!" on other players. Safety spec (all server-side unless noted):
   per-PAIR cooldown 30-60s; client hides the prompt for users on the local
   block list (`StarterGui:GetCore("GetBlockedUserIds")`); heart-burst FX only
   between Roblox friends — strangers exchange a plain sparkle pop; cap
   concurrent incoming boop FX on one character (~2). Add OwnerDebug
   `treatAsFriend`/`treatAsStranger` overrides so both branches are drivable
   in Studio.
2. **Co-squish shared credit:** 2+ players squishing the same friend within
   its wake window → BOTH get full coins, bigger confetti, "Squished
   together! ✨" toast. Sisters become allies, not rivals, in the core loop.
3. **Emote wheel (platform gap):** on spawn, `SetEquippedEmotes` with a
   curated wheel (Wave/Cheer/Laugh/Dance/Point renamed to Squishy vocabulary —
   "Boop Hello!", "Sparkle Cheer!"). Server auto-plays a cheer on shard/
   finale. Exclusive "Sparkle Dance" emote for Restoring the Sparkle.
4. **Escort travel:** one extra condition at TravelService's unlock check — a
   locked sibling can ride along when an unlocked player is at the pad.
   Scope of a visit: she can squish, bounce, and play freely (fun is fine);
   the land's shard pedestal, guide quest, and land-gated quest progress stay
   locked; warm toast points at her own next shard. Does NOT set the unlock
   flag. Fixes the likeliest source of family-playtest tears.
5. **Race-ify Pudding Plunge:** both top rings occupied within ~10s → 3-2-1
   billboard countdown, simultaneous release, splash-order detection,
   celebrate BOTH riders with equal coins. Finishes within ~1.5s = "Photo
   finish!" — both get the bonus sparkles; otherwise rotate randomized award
   categories (Fastest Splash / Bounciest Splash / Sparkliest Style) so every
   rider gets a title every race and the 6yo wins something about half the
   time. No loser language, ever.
6. **Bounce Bog visibility:** the shipped 2-player super-bounce is invisible.
   Sign → "bounce TOGETHER for a SUPER bounce!"; golden drum glow + "SUPER
   BOUNCE!" billboard while PartyUntil is active; first-time toast. ~20 lines.
7. **Sparkle Photo Spots + PhotoMode:** port Gnarly's `PhotoMode.lua` (one-tap
   cinematic camera, re-theme the exit button) + 2-4 marked pads in a frame at
   each land's landmark; 2+ occupied → countdown → everyone auto-cheers +
   confetti + a screenshot nudge (CaptureService ScreenshotHud). Free organic
   marketing from kids' screenshots.
8. **Friendship Picnic:** a blanket-pad circle per land; 2-4 kids standing on
   the pads → shared 3-2-1 → confetti + small equal coins. The family-scale
   shared goal (server-wide meters are too big for a family of 3).
9. **"💝 Kindest Friends" leaderboard:** persistent TotalGiftsSent counter in
   PlayerDataService.noteGiftSent + a third data-driven board at the hub.
   Make it a **weekly-fresh board** (each week starts even — "a brand new week
   of kindness!") and show family/server-friends rows first, so the 6yo isn't
   buried under tenure grinders.
10. **Buddy-to-buddy greetings:** in BuddyService's existing Heartbeat loop,
    two different owners' buddies within ~6 studs occasionally face each other
    + heart-sparkle burst. Engineering: scan on a ~1s accumulator (not every
    frame), compare squared distances, early-out above ~8 active buddies,
    per-pair 60s cooldown.
11. **Together quests:** daily templates "Give a gift 💝", "Bounce the Bounce
    Bog with a friend", "Ride the Sparkle Express with a friend" — one-line
    `DailyService.noteEvent` hooks in services that already detect these.

*Verify:* 2 Studio clients (Start Local Server) — boop both ways incl. the
stranger/friend branches via OwnerDebug, co-squish, race twice (photo-finish
and split finish), escort travel scope checks (capsule prompt locked, squish
works), picnic. Abuse checklist: rapid-fire boops from one client → cooldown
holds; blocked-user prompt hidden. Real friends-list behavior = family
playtest item. Compact-HUD screenshots.

### WO-3 · "Always a Tomorrow" — P1, effort M, no uploads (config + small hooks)
The daily/weekly renewal layer. Everything keys off existing UTC day/week
indexes — zero publishes needed to stay fresh.

1. **FIX THE STREAK (design-lock violation, do first):** DailyService
   hard-resets StreakDays to 1 on a missed day (lines ~72-74) + DailyUI says
   "come back tomorrow to keep it going!" — a loss-framed pressure loop.
   Fix: display ONLY a cumulative lifetime count ("You've played 37 sparkle
   days! ⭐") — nothing on screen can ever go down; keep a consecutive-day
   counter INTERNAL solely to drive the existing login-bonus ramp, with a
   grace day (gap ≤ 2 keeps it). Drop "to keep it going" copy everywhere.
2. **Daily quest pool 5 → 14ish templates** with an `icon` field (big leading
   pictogram per row — the 6yo navigates by pictures): ride the coaster,
   bounce N times, give a gift, visit/decorate your Room, per-land wakes
   ("Wake 5 friends in Moonlit Hollow"), boop 3 friends, find pages. Change
   "Discover a new friend" to "…OR shine one up" so it's never stuck for a
   full-book kid. Guarantee one "gimme" slot/day the 6yo can always close; all
   3 dailies finishable in ~20 min without cross-land travel before shards
   unlock. DailyUI grows a scrolling icon-first list in compact mode.
3. **Rotate the Sparkle Bit hunt:** grow the pool ~26 → ~40 spots, activate a
   deterministic ~12/day by dayIndex (same forDay windowing as quests; shared
   config so client renderer + server validator agree). The hunt stays a hunt;
   the 950/day endgame faucet right-sizes itself (WO-0 model confirms).
4. **Sparkle Star Path:** a visible 30-step illustrated track in DailyUI —
   each play-day drops a star; milestone chests (coins day 3/5, an exclusive
   cosmetic day 7/14, a special "Star Friend" card day 30). **The path NEVER
   regresses** — a missed day simply doesn't advance it; it cycles forever,
   nothing limited. The Star Friend lives OUTSIDE the launch-48 (its own Book
   section) so book-completion is never login-gated. **Acceptance: fake a
   3-day dayIndex gap → star position unchanged.**
5. **Weekly visitor never goes dead:** when the visitor is already befriended,
   the tent offers a small weekly quest ("Show Moshi the moonpool!" / "Meet 3
   Rainbow friends") + a once-a-week treat exchange (give a treat, get a small
   surprise decor item). **Befriending stays at the Pudding Hills hub tent
   permanently** (new players keep the weekly beat); the rotated LAND hosts
   only the visitor's weekly quest spot — which naturally requires that land.
6. **Rotating Boutique shelf:** 2-3 recolored variants of existing cosmetics
   per weekIndex at 300-600 coins (the color/color2 builder hints make
   recolors nearly pure config). Fixed repeating cycle, and **every rotating
   item's card displays "comes back every N weeks ⭐"** so the return promise
   is mechanically true and visible.
7. **Sparkle Swap:** at each capsule stand, pay a KNOWN price (~250 coins) to
   shine up a CHOSEN friend one variant tier. Deterministic, never random.
   **Swap caps at Rainbow; Starlight (WO-4) is Bond-only, ever.**
8. **Completion celebrations + set meters:** per-land/per-pack/per-rarity
   rings in the Collection Book ("Goo Coast Friends: 11/12!") with near-done
   sparkle salience ("Only 1 more!"), and real celebrations for 48/48 (launch
   roster only), a fully Sparkly zone, a full Rainbow book (fixed known
   rewards — e.g. a "Rainbow Keeper" crown). Currently hitting 48/48 shows
   NOTHING. *(Pulled into build-order batch 1 — small, high-payoff, serves
   the most invested kids: likely the daughters.)*
9. **Welcome-back card on join:** streak-days celebration, this week's
   visitor, fresh bits, "Your buddy is SO happy you're back — boop hello! 💖".
   **Copy rule from §1 applies: never neglect framing.** Data already in
   StateSync.
10. **"Perfect Sparkle Day" stopping cue:** completing the 3rd daily fires a
    one-time celebration ("You did everything today — the friends will nap
    now. See you tomorrow! ⭐" + fireworks + buddy cheer). NOT a lockout —
    positive closure. Parents grant more play to games that end cleanly.
11. **Boutique/Room catalog wave 2:** +6-8 coin cosmetics (balloons have only
    TWO options — thinnest shelf), +2-3 room items per kind with per-land
    themes, 1-2 new room slots (a buddy basket that shows the equipped buddy
    sleeping), one big-ticket 3,000-5,000-coin room upgrade (priced via WO-0).
    A finished kid should always see a 1-2-week coin goal.

*Verify:* time-travel by faking dayIndex/weekIndex; streak survives a 1-day
gap and the display never decreases; star path unchanged after a 3-day gap;
quest icons readable with text covered (the non-reader test); rotating-shelf
card shows its return promise; compact-HUD screenshots of DailyUI + Book.

### WO-4 · "Buddy Bond" — P1, effort M-L, no uploads
The nurture loop, part 1. Buddies currently follow you and never need you.

1. **Bond levels 1-5 per friend** (`profile.Friendship[defId]`): doing things
   WITH your equipped buddy raises Bond — Happy Pops nearby, rides ridden,
   dailies finished, boops given. **Bond only ever goes up.** Tiers add
   visible flair via the existing variant-aura/tag pipeline: bigger sparkle
   aura, heart badge on the tag, a new idle trick per tier (bounce, spin, sing
   its signature squish), slight size growth at max.
2. **Care micro-interactions (pure upside):** boop your buddy → giggle (its
   signature sound) + hearts; sit at a picnic with buddy out → it "shares a
   treat" animation; random idle happy wiggles. NO hunger, NO sadness, NO
   timers, and no copy implying it lacked anything while you were away.
3. **behaviorProfile idle personalities:** map the 6 dropped archetypes
   (creature/jelly_cube/goo_ball/dumpling/stress_ball/mochi) to distinct idle
   snippets (hops+looks / corner jiggle / wobble-roll / steam puff /
   squeeze-pulse / double-bounce). Buddies stop being interchangeable.
4. **Preset nicknames:** ~60 kid-safe names (Sir Squish, Bubbles, Captain
   Wiggle…) in NicknameConfig; picker in the Book's detail card; nickname
   shows on the overhead tag. Server validates from-the-list. NO free text.
5. **"Starlight" variant tier** beyond Rainbow, earned ONLY by maxing a
   friend's Bond (never by dupes, never by coins) — ties the variant ceiling
   into the nurture loop so play and collection both matter. Family cards'
   "Love" Feeling gets a special heart aura.
   **Book-UI note:** before adding Starlight badges + bond hearts + nicknames
   to the card detail, mock the compact-mode detail card layout — the card
   already carries art/rarity/variant/equip; don't let it become a dashboard.
6. **Favorite Friend star** in the Book → that friend displays on a pedestal
   in your Squishy Room.

*Verify:* Bond math server-side (game-VM probe pattern from CLAUDE.md); watch
each archetype idle; nickname persistence round-trip; Starlight unreachable
via Swap; compact detail-card screenshot.

### WO-5 · "The Sparkle Garden" — P1, effort L, no uploads — **the flagship**
Offline growth (Grow a Garden's engine) fused with Squishy kindness.

- **Plots:** a garden district per land (WorldService pattern, own district
  per the world rule). **Capacity spec: every player is guaranteed a plot** —
  beds spawn per-player from the profile on join (beds-per-land ≥ max server
  size, or instanced per player); your garden renders from YOUR profile on
  whatever server you land; unclaimed beds show as empty soil. Optionally 1-2
  pots in the Squishy Room.
- **Loop:** buy Sparkle Seeds with earned coins (renewable sink, priced via
  WO-0) → plant → growth accrues from `os.time()` deltas computed on join —
  **it grows while you're at school** → "Look how big it got!" → harvest pays
  coins + sometimes a decor item or Sparkle Bits. Multiple seed types with
  different day-scales (1-day sprout → 5-day Rainbow Bloom).
- **THE LAW applied:** plants NEVER wilt, die, or get stolen. Growth only
  accumulates. No timers to miss.
- **Kindness watering (v1 = same-server, online owners only):** visitors can
  WATER another player's rendered garden — small growth boost, both get
  sparkle hearts, immediate toast to the owner. Never take. Caps: ~5 waters
  given/day (GiftConfig pattern) AND ~3 waters received per plot per day (so
  visitors can't max a kid's growth and remove her agency). **Attribution:
  name shown only for Roblox friends; everyone else is "a kind visitor"** —
  acceptance criterion, since it's invisible in casual testing. The offline
  "someone watered while you were away" surprise ships LATER riding the
  cross-server mailbox pattern already earmarked for gifts — do NOT write to
  offline profiles from another server (session-lock architecture; the
  project has been burned by concurrent writes before).
- **Hooks:** daily quest "Water a friend's garden"; harvest feeds a badge;
  welcome-back card reports growth (this is what makes WO-3.9 sing — growth
  framing, never neglect framing).
- Store per-plot {seedId, plantedAt, wateredBonus} in PlayerDataService;
  serialize round-trips unknown keys already (keep that invariant).

*Verify:* fake os.time offsets server-side for each growth stage; two-client
watering incl. both attribution branches (OwnerDebug override) + both caps;
harvest coin math vs the WO-0 model; persistence across rejoin AND across a
server hop; a full-server bed-capacity check.

### WO-6 · "Sparkle Weather" — P2, effort M
Shared "it's happening!" moments. **Weather VARIANTS (per-friend stamps) are
DEFERRED** — see the sequencing note below.

- **Weather:** per-land gentle events every ~10-20 min on the SurgeService/
  SocialSync pattern — Pudding Drizzle, Glow Tide, Shooting Stars. Visual
  layer (particles within the WO-0 FX budget, lighting tint) + a **forecast
  board at the travel hub** ("Glow Tide returns soon!") so nothing external is
  ever needed and nothing is ever missed forever. No countdown-anxiety copy.
- **Coin bonus:** pops during that land's weather pay a bonus — **weather and
  Surge do NOT stack (take the max)** per WO-0.
- **Rainbow Moment (rare):** while active, everyone's next free daily capsule
  guarantees a not-yet-discovered friend. **Full-book fallback (define in
  config):** a choose-a-friend shine-up (one tier, capped at Rainbow) or a
  fixed coin gift, announced in the same celebratory frame.
- **Sequencing note (collection-axis budget):** the Book must not become a
  5-axis grind matrix for 6-9yos (Sparkly/Rainbow × Starlight × weather
  stamps × bond × stickers). Ship Bond→Starlight (WO-4) FIRST and let the
  girls react. Only then consider weather variants, and prefer per-LAND
  weather completion meters over per-friend stamps. Requires the WO-4.5
  detail-card mockup before any second axis lands.

*Verify:* force weather via OwnerDebug; multiplier max-not-stack math logged;
forecast board copy check; Rainbow Moment on a full-book test profile hits
the fallback; compact-HUD banner placement.

### WO-7 · "Platform Free Wins" — P1, effort S-M each, mostly no uploads
1. **Badges (~15):** port Gnarly's `BadgeService.lua` + a BadgeConfig mapped
   to EXISTING hooks: First Happy Pop, First Capsule, First Discovery, 3
   shards, Sparkle Restored, 10/25/48 Discovered, first Sparkly, first
   Rainbow, all bits, all pages, **"Kindest Friend" (first gift)**, first
   coaster ride, met the Family Three. Icons via `make_product_icons.py`
   (already moderation-cleared style). Idempotent pcall AwardBadgeAsync.
   **Chris creates the badges in Creator Hub** (5 free/day — spread over 3
   days) and pastes ids; id=0 no-ops until then.
2. **Telemetry port** from New-roblox-game: FTUE funnel (first squish → first
   capsule → first shard → first travel → finale) + economy events (earn/
   spend/receipts) via existing service hooks. The live game currently flies
   blind.
3. **Branded loading screen** (Boot + LoadingUi port): storybook "book
   opening" + rotating gentle tips ("Boop a sleepy friend to wake them!").
   Kills the raw StreamingEnabled join on kid devices.
4. **"What's New" storybook signboard** at the hub fed by ChangelogConfig —
   3 icon+line entries, kid-readable. Feeds the discovery-freshness story.
5. **Creator checklist for Chris (no code):** turn ON free private servers
   (the family/birthday feature; guarantees the girls land on one server so
   gifting always works) · schedule weekly platform **Events** for the Friend
   of the Week (card art as thumbnail, batch weeks ahead) · rotate the 6
   committed thumbnails · mention "Play in your own family server — free!" in
   the description.

*Verify:* badge award replay test (AwardBadgeAsync fires once, second trigger
no-ops via UserHasBadgeAsync); **Telemetry COPPA check: grep the ported
module for HttpService/RequestAsync — AnalyticsService calls only, no
external endpoints, no PII in custom event fields**; loading screen shows
instantly on a cold join and always releases (45s ceiling); What's New board
renders at kid eye-height; each badge hook exercised once in Studio (events
appear in the analytics debugger within ~24h — note for Chris, not a blocker).

### WO-8 · "Sound & Story Treasury" — P2, effort M-L, **uploads (low-risk audio), phased**
Spend the owned-audio goldmine. §2's audio cadence applies: ≤1 upload/min,
moderation check every 10, hard-stop on any flag. Spoken word gets a ONE-clip
probe before its batch.

1. **Per-friend voices (phased):** upload the 225 per-friend squish/burst mp3s
   land-by-land at the §2 cadence (quota 2000/30d is plenty). Extend
   SoundConfig.SignatureSounds to key by friend id with the existing pick()
   pools; fall back to Pmf/Sploink/Thup. Every friend becomes audibly ITSELF —
   kids will learn them like Pokémon cries.
2. **UI sound pass:** the 8 UI mp3s (tap/confirm/coin ding/reveal stinger)
   wired through UiTheme so every button answers. The 8 combo jingles back
   WO-1's chain at x3/x6/x10/x15.
3. **Capsule ceremony upgrade:** stage the reveal in beats — wobble → 2 player
   taps to crack → silhouette tease → pop + THAT friend's signature squish +
   card flourish; nearby players see a small over-head flourish (sibling
   spectator moment). **Tap-to-skip for already-discovered friends; the full
   ceremony always plays for new discoveries and Epic/Legendary** (daily
   opens must not become friction). Rarity VO from `assets\audio\vo` only
   AFTER a vocabulary audit (mobile-era lines may be off-Law). Odds logic
   untouched.
4. **"Read to me" story pages (the signature feature):** the SRT is timed to
   the GEORGE master (337.6s) — Chris's own-voice master is 394.1s, so
   **either** split George's mp3 with the SRT as-is, **or (preferred,
   dad's-voice magic) re-time Chris's master first** — forced alignment
   (aeneas/whisper) or hand-marking the 18 cut points — then ffmpeg-split.
   Upload (probe ONE clip first; spoken-word review is real) → a play button
   in the StoryPages viewer. The 6yo pre-reader can suddenly "read" the whole
   book in-game, in her dad's voice. Do NOT touch captions (§2).
5. **Guide voice lines:** short ElevenLabs storybook-narrator lines for quest
   beats + daily panel open ("Wake up three sleepy friends!") via the proven
   dialog_vo pipeline — icon-first UI reinforcement for the pre-reader.
6. **Flavor text (zero uploads):** "Squishkeeper says" lines + "First spotted
   at" places from the Book-1 manuscript/bio sheet into the Book's detail card
   and the Weekly tent; STORY_BIBLE canon lines into the finale ("the light
   that comes from being found") and guide dialogue. A Squishkeeper lore nook
   at the stargazing circle.

*Verify:* every uploaded id confirmed **Approved** before wiring into
SoundConfig (and publish only after Approved); PreloadAsync/IsLoaded battery
in Studio (remember the serverplaceid=0 quirk — trust the published check);
VO vocabulary audit checklist committed with the wiring PR; ceremony skip
path timed (< 2s for a known friend); read-along clip boundaries spot-checked
against 3 pages (start/mid/end).

### WO-9 · "World Play Expansion" — P2, effort L (pick à la carte)
1. **Moonlit Hollow deficit (the finale land has the least to do):**
   (a) interactive stargazing — sit the circle, a constellation of a random
   discovered friend draws in the sky (SquishyDefinitions colors);
   (b) Moonpool Float — drifting lily-pad Seats (clone the Lazy Goo River
   state machine); (c) firefly-catch — walk-through wisps, +1 coin sparkle
   pops, bits-style refresh.
2. **Bouncy jelly dunes:** Goo Coast's 10 JellyDunes are decorative
   (CanCollide=false, untagged — WorldService ~902-915) — the land's own
   theme promise. Tag them SquishyBouncy + attrs; BouncePads does the rest.
   An hour of work.
3. **True night for Moonlit:** client-side Sky swap on zone change (SoundScape
   already crossfades music by zone — same pattern). **The night skybox is
   NOT yet uploaded** — trickle the 6 local PNGs from New-roblox-game
   `tools\skyboxes\out\night_*.png` first (plain sky images, low risk, one at
   a time), resolve Decal→Image ids, then swap. Dawn's ids already exist in
   `state_wave2.json` if a second sky is wanted.
4. **Role-play stations (pretend-play props, near-free):** Shopkeeper counter
   spot at the Boutique, tea-party picnic set (4 sit prompts + teapot),
   storyteller stump at the stargazing circle, and a lighthouse-keeper
   lookout prompt at Goo Coast (part-built spyglass — the telescope_brass
   mesh is LOCAL-ONLY, not uploaded; don't count on it). Props + Seats +
   prompts; siblings invent the rest.
5. **Minigame wave (each M, each with a daily-quest hook):**
   - **Squishy Bubble Bath** (care verb — most on-brand): a muddy friend at
     the tide pools; scrub-boop to reveal them sparkling; before/after +
     coins.
   - **Tuck-In Time** (Moonlit): carry wandering mini-squishies to the bed
     matching their color. **The lullaby LOOPS until every friend is tucked
     in — the game cannot be failed;** finishing within the first loop grants
     bonus sparkles (celebration, not survival). Acceptance: idle through 3
     loops → still a full success.
   - **Pudding Cup Tower:** stack wobbly cups; together-bonus on shared
     towers.
   - **Sparkle Dive** (Goo): leap the lighthouse, steer through sparkle rings
     to the splash pool (client-owns-physics pattern like BouncePads).
   - **Sparkle Toss:** reskin `archive/qb1` Throw/Target/Round/Score services
     into a carnival stall (lob berry beanbags through moving sparkle rings).
6. **Shoulder Pals shelf:** the 15 Approved pet meshes (ids in
   `game_assets.json`, utf-8-sig!) + CompanionPerch weld → a new Boutique
   shelf (most coin-priced, 2-3 rarest as Phase D premium — style-only,
   within The Law). ZERO moderation risk (already Approved).
7. **Village accents (by existing assetId only):** the kid-safe uploaded
   prop_* set — market_stall, street_lantern, signpost, village_well,
   gate_arch, hay_bale, barrel, campfire, crate_stack, quest_board, shop_sign,
   tent, treasure_chest — as district accents. Accents, not replacements; the
   candy part-built look stays the star. (The 46 `tools\houses` GLBs are
   local-only = full high-risk trickle if ever wanted; default is DON'T.)
8. **Playground Spotlight:** each day one apparatus gets a sparkle ring + a
   together-goal ("50 Bounce Bog bounces today — everyone bouncing shares the
   sparkle!") feeding the Surge meter. Rotation makes built content feel new.
9. **Museum/Story Nook (absorbs the most unused art at once):** a small
   gallery building — hero renders, the all-48 poster, coloring-pack "how a
   squishy gets its colors" corner, Squishkeeper plaques, a physical Lost
   Sparkle book model (cover art). Image uploads = low risk, trickled.
10. **Replay the Story (effort S — the non-destructive answer to "I want to
    start over," see §7):** a "Tell it again! 📖" prompt (guide dialogue or
    the storyteller stump from item 4 / the Story Nook from item 9) that
    RE-RUNS the Lost Sparkle beats as a memory — tutorial welcome, each
    land's clue dialogue, the shard-appears moment, the Restore-the-Sparkle
    celebration (FinaleUI replay) — while touching NOTHING: no profile
    writes, no coins (economy-neutral so it can't be farmed), collection
    and shards stay exactly as they are. Pure story theater driven by the
    existing QuestService/TutorialService/FinaleService dialogue + FX with
    a replay flag. Kid-need served: re-feeling the beginning without losing
    anything. Nice stream demo, too. Acceptance: run a full replay on a
    completed profile → StateSync snapshot byte-identical before/after.

*Verify (per item shipped):* ride/play each new apparatus end-to-end in
Studio; Tuck-In idle-through test; jelly-dune bounce heights logged client vs
server (client applies); night-sky swap on land hop both directions; every
inserted assetId renders (not grey) in a published-place check; museum decals
Approved before wiring; compact-HUD for any new UI.

### WO-10 · "Sparkle Keeper & Seasons" — P2-P3, effort M-L
1. **Post-finale staircase:** "Sparkle Keeper" ranks. Data note: pops and
   discoveries are already lifetime-tracked (TotalHappyPops /
   DiscoveredCount); **add persistent TotalGiftsSent (WO-2.9 — ordering
   dependency) and a TotalBitsFound counter** (increment in SparkleBitService's
   award path; profile.SparkleBits is wiped daily and can't be used) before
   building ranks. Each rank = a title on the tag + a small SYSTEM unlock
   (rank 2: second garden plot · rank 3: buddy emote wheel · rank 4: room
   slot · rank 5: a golden replay of the shard quest). Nothing resets; ranks
   sell status, not power. The finale stops being a hard stop.
2. **Sparkle Saturday calendar:** one config module of 8-12 authored weeks —
   each week names a spotlight land (bonus pops there, WO-0 capped), a
   featured playground goal, a featured shelf, a weather emphasis. Announced
   by the existing shout-out system. The fixed weekly ritual (GaG/PS99's
   Saturday clock) WITHOUT needing weekly publishes.
3. **SeasonConfig framework + first season:** date-windowed decor overlays per
   land (snow-capped pudding mountains, lantern festival), a seasonal visitor
   at the tent, 2-3 seasonal items labeled "visiting this month — returns
   every year! ⭐". **Seasonal magic words never expire-and-die: they re-arm
   every year in their season** ("this magic word wakes up every December!") —
   CodeService already persists per-player redemption; annual re-arm is a
   config field. Never "last chance."
4. **Sparkle Sprint** (GhostSprint pattern): a marked fun-run loop per land
   with personal-best toasts ("Your best yet!") — self-comparison, never
   sibling-comparison. Doubles as a new-player land tour.
5. **Personal-best panel** beside the leaderboards ("YOUR best sparkle day:
   14 Happy Pops!") and family-first board rows so the 6yo sees her family
   near her name, not rank 4,000.

*Verify:* rank thresholds vs real lifetime data on Chris's profile (read-only
probe); season window flips by faking the date inputs; seasonal item card
shows the returns-every-year promise; sprint PB persists and never displays a
regression; calendar module reviewed against WO-0's multiplier caps.

### WO-11 · "Candy Cloud Kitchen" — P3, effort XL, **gated on Chris's explicit go**
The 4th land is already designed in the data: the 8 event friends carry
`Zone = "Candy Cloud Kitchen Event"` in SquishyDefinitions and
`RobloxZone = "Candy Cloud Kitchen"` in PackConfig (grep BOTH strings), with
palette #FFD1DC/#FFB5A7/#F6C089 and a dormant IsEventPack. When Chris
green-lights:
1. Cards for the 8 event friends (mobile-repo card pipeline →
   upload_cards.ps1 → CardImageAssets) — they currently break the "full card
   reveal" promise.
2. Meshes for the 8 (Meshy budget: ~240 credits) — STRICT trickle rules.
3. The land itself at x=1800, post-finale-gated ("the restored Sparkle
   reveals a new path in the sky") — generalize `ZoneConfig.spreadAbs` to
   read centers from Zones first (it hardcodes 0/600/1200). Bespoke build per
   the world rules: own districts, cloud/kitchen theming, 4th capsule + music
   + bits + pages slots, a playground piece, travel pad.
4. Roster headroom beyond that: the 15 Appalachai `squishy_*` characters
   (capybara! seal! duck!) are a ready "Squishy Safari" event-pack wave —
   card art + trickled meshes when wanted.

*Interim (not gated):* Candy Cloud Kitchen teaser — the Weekly tent's sign
mentions where the visitor is FROM; the travel plaza gets a cloud-wrapped
"someday" signpost. Costs an hour, plants the dream.

---

## 6. BUILD ORDER (authoritative — §0 defers to this)

1. **Batch 1 — pure wins (one day):** WO-0 guardrails · WO-3.1 streak fix
   (it's a Law violation) · WO-3.8 completion celebrations + set meters ·
   WO-7.1-3 (badges/telemetry/loading screen).
2. **WO-1** (juice) — the every-minute fun multiplier.
3. **WO-2** (together) — before the next family playtest.
4. **WO-3** (rest of renewal) + **WO-4** (Buddy Bond).
5. **WO-5** (Sparkle Garden — flagship; announce as an update moment).
6. **WO-8** (audio treasury, phased alongside everything).
7. **WO-6** (weather), **WO-9** à la carte, **WO-10**.
8. **WO-11** when Chris says go.

After each publish: remind Chris → Restart Servers (if servers are live) →
suggest a platform Event post + one "watch for this" note for the girls.

## 7. EXPLICIT SKIP LIST (documented decisions — do not build)

- Experience-notification opt-in (13+ only; core audience can't receive).
- Trading, in any form. Theft/steal mechanics (GaG's spice — wrong for 6-9).
- Paid randomness, coin packs, luck boosts. Capsules stay free.
- Hunger/decay/neglect states; visible streak resets or ANY on-screen number
  that can go down; "LAST CHANCE" anything; expiring one-shot promo codes
  (seasonal words re-arm annually instead).
- Downvotes, eliminations, single-winner contests, stranger-voting.
- Free-text input from kids anywhere.
- Offline profile writes from other servers (wait for the mailbox pattern).
- Filling StoryPageConfig captions (text is on the art).
- Runtime writes to RenderFidelity/CollisionFidelity; touching mesh AlphaMode.
- Batch uploads of images/meshes (audio follows §2's slow cadence only).
- Renaming "creepy_cute" pack surfaces in kid-facing UI without Chris — the
  in-game surfaces already use friend-level names; leave internal ids alone.
- **Player-facing reset/wipe button** (considered + rejected 2026-08-01):
  a self-serve reset deletes Robux-purchased premium cosmetics that the
  idempotent ProcessReceipt will never re-grant (real-money loss), is the
  most off-Law control possible ("nothing visible ever goes backward"), and
  the 6-9 audience + shared family devices guarantee accidental/sibling
  wipes of whole collections. The real kid-need ("feel the beginning again")
  is WO-9.10 Replay the Story; a true fresh start is an alt account
  (Roblox-native, what every collection game relies on). The OWNER-only
  reset button stays — it's a demo/playtest tool, double-gated so kids can
  never trigger it.
