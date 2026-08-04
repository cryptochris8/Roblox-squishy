# TikTok LIVE Playbook — Squishy Smash

*Drafted 2026-07-31 (first live: tonight). Researched via 4 parallel web-research passes + an adversarial verification pass (~100 web lookups); every correction applied. TikTok ships UI by region/account — anything tagged `[VERIFY IN APP]` gets confirmed on the actual phone/laptop, and the app wins over this doc.*

## Why LIVE is the right move

A live is the only format where the "dad who built a game for his daughters" story tells itself continuously — and every piece of plumbing it needs already exists: the **TIKTOK Magic Word** (250 Sparkle Coins, live in the game) is simultaneously the on-screen CTA, a free gift to every viewer, and per-channel attribution (redemptions after a stream = the measurement loop; **even 2–3 redemptions is real data**). The funnel: LIVE → profile → bio link (`squishysmash.com/hub`) → /play, /book, /app. Nothing on a TikTok LIVE is clickable, so the bio link is the entire conversion surface.

## Step zero — eligibility (check FIRST, everything depends on it)

- **Which account shows the LIVE option?** Phone → **+** (Create) → swipe the bottom carousel: if **LIVE** appears, that account can host. Requirements: host 18+ (TikTok's own safety page) and ~1,000 followers (secondary-source consensus; varies by region). No same-day workaround if absent — third-party "unlock LIVE" services are scams. `[VERIFY IN APP]`
- **Is Appalachian Studios a Business account?** Business accounts reportedly have limited LIVE features (e.g., no gifts). Host on the PERSONAL account regardless; the Studios account is the chat/mod seat. `[VERIFY IN APP]`
- **Mutual follow now:** host + Studios accounts must follow each other before the Studios account can be added as a LIVE moderator (mutual-follow prerequisite per TikTok's own moderator doc).

## Tonight's runbook

### Pre-flight (start ~90 min before; going live 8:30–9:00 PM ET)

**Roblox side:**
- [ ] Creator Hub → Squishy Smash → settings → enable **Private Servers, price FREE** (Roblox's docs list "recording/streaming without other users" as an intended use). Create one from the game page; play there tonight — no other kids' usernames or chat on stream.
- [ ] Play the **PC Roblox client, never Studio** (Studio can leak the two unpublished commits and dev UI).
- [ ] Hide the in-game chat UI via the top-bar chat toggle (belt-and-suspenders) `[VERIFY toggle location]`.

**TikTok side (host account):**
- [ ] **Enable LIVE replay/save BEFORE going live** — off by default; replays keep ~30 days. Mandatory, not optional.
- [ ] Bio: link set to `squishysmash.com/hub`; bio text clearly identifies an adult creator ("Dad building Squishy Smash for my 3 girls").
- [ ] LIVE settings → **Moderators → add the Appalachian Studios account**. Set keyword filters ON.
- [ ] Pre-write the title — the LIVE title limit is short (~32 chars): **"I built this game for my girls"** (30) or **"Dad-built Roblox game, live"** (27). Category: Gaming. Keep the word "giveaway" OUT of the title.
- [ ] Phone on Do-Not-Disturb (phone rig broadcasts everything on screen).

**Rig — prepare BOTH, whichever works is tonight's; the other is the tested backup:**
- **Rig A (best show): TikTok LIVE Studio on the Windows laptop.** Official free app — download ONLY from tiktok.com (`tiktok.com/studio/download`); supports Windows and macOS per TikTok's help center. Log in as host via QR → Game/Window Capture on the Roblox client → webcam corner source → one text overlay (see below) → title + Gaming category → preview → Go LIVE. If access isn't granted at login, there's an apply-for-access flow inside the app `[VERIFY IN APP]`. Face cam + lighting + audible warmth is what makes scrollers stop — pure screen share underperforms.
- **Rig B (co-primary, rehearse it too): phone Mobile Gaming mode.** + → LIVE → switch mode from Camera to **Mobile Gaming / Stream Games** → title → Go LIVE → approve screen-record → open Roblox mobile and play; mic stays live. Games-only mode (streaming Roblox is the intended use). `[VERIFY the mode appears]`
- **Not tonight:** OBS/RTMP — stream keys are now mostly gated behind TikTok Creator Networks (application process). LIVE Studio does game capture + overlays natively anyway.
- [ ] **Local recording backup** regardless of rig: Windows Game Bar (Win+Alt+R) or LIVE Studio's own record — the raw footage stays Chris's whatever TikTok's replay window does.

**The one on-screen overlay + the canonical pin (no URLs — this is policy, not style):**
TikTok's 2025 guidelines update suppresses lives that push off-platform purchases and bans clickable links/QR codes on LIVE. The reach-safe CTA architecture:
> **Overlay/pin text: "Type TIKTOK in Squishy Smash for 250 free Sparkle Coins — free Roblox game, link in my bio"**

Books come up as *story* ("this world started as a bedtime story — the real book's in my bio link"), never as a purchase push. Domain spoken out loud sparingly — 2–3×/hour at natural peaks, "link in my bio" the rest of the time.

### Run-of-show (60 min, stretch to 90 if chat is alive)

1. **Open mid-gameplay** — a Sparkle Capsule reveal or the coaster, already moving. The first ~15 minutes are the heaviest algorithm-testing window; never open with setup fiddling or waiting-for-people. Scrollers land mid-stream with ~3 seconds of patience.
2. **The loop (repeat ~every 10 min for new arrivals):** greet every entrant by name → narrate the game warmly → drop the Magic Word ("if you just got here — type TIKTOK in the game, 250 free coins") → one story beat.
3. **Sticky note with 5 fallback topics** (the anti-dead-air system): why capsules are free forever / the girls are actual cards in the game (Family Three) / the books & the LOSTSPARKLE halo / the garden that grows while kids are offline / what's being built next.
4. **Ask answerable questions to the room** (even an empty room): "parents — what do your kids play right now?" "loot boxes: yes or no?" Substantive comment threads outweigh emoji spam. Chat arrives 5–20 s late — pause after questions.
5. **Zero-viewer stretches are normal and expected.** Keep performing; the algorithm tests the stream the whole time, the replay becomes clip material, and ending early teaches TikTok the stream doesn't retain.
6. **Clip capture:** LIVE Studio's **Highlight** (Ctrl+1) saves the past 2 minutes, up to 3 per live — hit it after every capsule reveal, good chat exchange, or origin-story beat.
7. **Close:** announce the schedule ("every Tuesday and Friday, 8:30, after my girls are in bed"), soft follow-ask ("the follow button is how TikTok tells you"), tease next Friday's plush drawing (see below) — then immediately **schedule the next LIVE Event** (countdown card + Remind-Me push notifications) `[VERIFY menu path]`.

### The two-account setup (Studios on the laptop)

Allowed and normal — TikTok's moderator feature exists precisely so a trusted second account works chat. Rules of the seat:
- **Mute the laptop completely** (system mute) — the viewer stream replays host audio seconds late; audible speakers near the mic = echo loop on stream.
- Watch/comment via browser at `tiktok.com/@HOSTHANDLE/live` (login required). **Mod tools (pin/mute/block) may not surface in the browser** — keep the Studios account also logged into TikTok on Chris's own spare device or the TikTok for Windows app as the mod console. **Never the girls' devices.**
- **DO:** pin the canonical comment early and keep it pinned · re-post key info every 5–10 min with *varied* wording (repeat text gets silently spam-filtered) · answer FAQs in studio voice (what it is, ages, free-forever capsules, the books) · relay missed questions ("@host — Sarah asked about capsule odds") · mute/block anything gross fast · keep a timestamp log (wall-clock + what happened) as the clip map.
- **NEVER:** send gifts to the host's own LIVE from the Studios account (**self-gifting is the brightest prohibited line in the whole setup** — monetization rules, account-level risk) · pose as an unaffiliated fan · manufacture hype · rapid-fire identical comments.

### Kid-safety rails (the account-survival section)

- **The daughters: story, never presence.** Not on camera, not audible, not in the streamed private server (their real usernames are persistent identifiers). Creators report 24-hour LIVE bans just for a child's face on a live. They exist on stream as "my three girls are the reason this exists — they're actual cards in the game." Door closed; after-bedtime slot helps.
- **All speech aims at parents** ("if your kids play Roblox…"), never at kids ("hey kids!") — brand position, suppression-avoidance, and COPPA posture in one.
- Apparent-minor commenters: warm generic hello, move on. Never ask age/location/anything personal; never read out personal info a kid types; delete + pin over any address that appears in chat.
- **Gifts: acknowledge, thank, never encourage** — and never tie anything to them.
- **Never say or hashtag Squishmallows** on a live or clip — ad-libs are where the rule leaks.

## The giveaway — NOT tonight (announce it tonight, run it from live #2/#3)

Night one stacks too many unverified surfaces (giveaway-disclosure rules, address collection, minor entrants) onto TikTok's most-enforced format. Tonight's giveaway IS the Magic Word — everyone wins 250 coins. Announce: *"starting next Friday, one family wins a plush every stream."* Then, during the week:

1. **Post the entry video** ("Free plush drawing at Friday's 8:30 live — parents, comment SPARKLE on THIS video to enter, full rules pinned") and pin the rules comment. Entries live on the video, not in live chat (persistent, auditable, and comment-picker tools work on videos, not lives).
2. **The 8-line rules block** (pin it; a `/giveaway` page on the site is the cleaner permanent home): no purchase necessary · US residents **18+** ("parents enter, kids win the plush at home") · entry = comment SPARKLE on this video, one per person · prize + approx value (keep well under $500) · random selection on [date], odds depend on entries · winner announced by @username, must DM within 48–72h or an alternate is drawn · *"This giveaway is in no way sponsored, endorsed, administered by, or associated with TikTok"* · household/alt accounts of the host excluded.
3. **Draw OFF-stream** (or announce the already-selected winner on stream with zero draw theatrics — the only official TikTok giveaway policy text retrievable bans "gambling, gamification, or randomization methods" in Shop contexts, and on-camera draw mechanics on a LIVE are the auto-moderation pattern to avoid; no wheels ever). Next-day comment on the entry video names the winner = public record.
4. **Fulfillment:** winning ADULT DMs; collect name + US shipping address only, in DM, never in chat, never from a minor (if the winner reads as a minor: redraw). USPS Ground Advantage ~$5–12; share tracking in DM only.
5. **Hard lines:** never any gift/coin tie ("send a rose to enter" is gift-baiting + an illegal lottery) · never follow-to-enter as a *requirement* · never "everyone who comments wins" · never the words "raffle"/"lottery" · magic words and the giveaway stay separate lanes (the code is free and shouted to all — never "comment to unlock the code").
6. **Prizes:** best = unbranded/generic squishy plush; acceptable = branded plush from the personal collection with the spoken + written disclaimer ("from my own collection — we're not connected to [brand] in any way"), never in the title/caption/hashtags, never framed as a Squishy Smash prize (Jazwares is actively litigious and "Squishy Smash gives away Squishmallows" is the implied-affiliation trap). **Long-term prize = a signed book copy** — zero trademark surface, pure brand, already in stock.

## Cadence, growth, repurposing

- **Slot:** Tue + Fri 8:30 PM ET ("after the girls are in bed" — on-brand and inside the 8–10 PM parent-scroll window). Consistency beats day-picking; 2×/week is the sustainable solo-dad floor that still compounds. 60–90 min per live (under ~30 min doesn't give the algorithm time to test the stream into feeds).
- **After every live:** schedule the next LIVE Event immediately → post 1–3 clips within 24 h (Highlight exports; TikTok + YouTube Shorts, captions carry "live every Tue/Fri 8:30 ET"; Shorts cross-posts use the SHORTS word for attribution).
- **What travels as clips:** capsule/rare reveals · the origin-story beat said naturally mid-game · parent-ethics beats (free capsules forever, no paid randomness) · genuinely good answers to real parent questions · world tours (the offline-growing garden). Clip titles lead with the dad angle, not the game name — nobody knows the game yet.
- **Attribution check the morning after:** TIKTOK redemption count server-side. Even 2–3 = the funnel works.

## Honest expectations

Single-digit (including zero) viewers for the first several lives is the universal experience — the algorithm needs multiple sessions to learn who to route in. **Win condition for live #1: the tech worked, 60 minutes streamed, 1–3 highlights captured, the next live is scheduled.** Not a viewer number. The compounding loop (fixed slot + LIVE Events + clips between lives + the magic-word attribution) is what turns week 4 into something different from week 1 — this is also the fastest realistic route to the go-viral plan's "first 1k followers in 6–8 weeks" target.

## RETENTION TOOLKIT (researched 2026-08-02 — 3 web passes + adversarial verify, fixes applied)

### The gift answer, settled (Chris asked about gift goals + gifting)
- **Gift Goals: permanently off the table for this brand.** The native LIVE Goal widget is TikTok-sanctioned and technically compliant, but it's a persistent "send gifts" scoreboard with top-3-contributor prizes — a leaderboard of spenders on a channel whose promise to parents is "we never ask for anything." There is no viewer-count at which this becomes on-brand, and **never map gifts to anything in the game** (no "if the goal fills, I build X in-game") — that's the gift→reward pattern the Monetization Guidelines police, landing inside a game played by 6-9-year-olds.
- **Gifts stay passive:** enabled, never mentioned. When one arrives (senders are 18+ by TikTok rule — any gift is by definition from an adult), thank them warmly by name once, move on. Note: gift receiving has its own eligibility gate — if the account isn't gift-enabled yet, the whole topic is moot; check LIVE Center. Reality check: ~1.5–4% of live viewers ever gift, mostly 1-coin Roses — at this size, gift revenue is statistically zero regardless of tactics.
- **"Gifting others" — the one on-brand version:** viewer-to-viewer gifting doesn't exist natively. What DOES work: **Chris drops a 1-coin Rose in other wholesome family-gaming creators' LIVEs** — they thank "@squishysmash's builder" by name in front of their audience. Cheapest networking a 5-viewer channel has, and it's kindness, which is the brand.
- **Battles / LIVE Match: hard no, forever.** The format is a timed gift-spending competition — pressure by design. Viewer Wishes (gift-mapped requests) and the top-gifters Viewer Ranking widget: same skip.

### Do-now list (ranked for a 1–10 viewer room)
1. **LIVE Events every week** (Tue + Fri, scheduled 1h–10d ahead) — the only native mechanism that push-notifies people you're live. Zero cost, zero risk.
2. **The pin + Q&A mode.** Pin the Magic Word CTA; turn on Q&A so parents' questions ("is it safe? does it push purchases?") become structured on-screen content — trust is the product.
3. **Curated co-hosting** (up to 4 on split screen, works from LIVE Studio): the only real *discovery* lever at this size — borrow a like-minded family-gaming or indie-dev host's audience. Outreach required. Never random matching; never battles.
4. **Follower goal via the native Goal widget** — officially supports follower goals, not just gift goals (per the Add-widgets help article). "Road to 100 sparkle friends 🌟" is a shared micro-mission with zero pressure. Confirm the toggle in your build.
5. **Guessing Game** if the account has it (points-based prediction widget rolling out to select gaming creators): "Will this capsule be a Rainbow? Yes/No" is exactly what it's for. [VERIFY IN APP]
6. **Fan Club:** leave enabled if offered (badges/entrance spotlights for regulars = real community value), **never pitch the join path on-mic** (joining runs through a small gift). Super Fan ($9.99 paid tier, replaced LIVE Subscriptions Sept 2025): premature; paywalled closeness sits awkwardly with a kids brand.

### LIVE Studio scene collection (build once, ~30 min)
Portrait canvas (1080×1920 30fps; run the built-in speed test). TikTok's app owns the bottom third (its own comment layer — put NOTHING there, and skip the Chatbox overlay in Portrait; it double-chats) and the top strip. Four scenes, hotkeyed F1–F4:
1. **Open** — go live already in-game and talking, or ≤60–90 s of key art WITH face cam + voice over it. Never minutes of static "starting soon" — FYP drops viewers mid-stream; a static screen is an instant scroll.
2. **MAIN** — Window Capture of Roblox (not Display — no notification leaks) · face cam top-right ~20% (non-negotiable: the dad IS the brand) · magic-word banner upper-middle, always on, readable at phone size · follower-goal widget · land banner mid-left ("🍮 Exploring: Pudding Hills" — one Text source per land, toggle visibility) · Alert source: follows ON (every 1, gentle sound), gifts quiet-OK, viewer-ranking OFF.
3. **BRB** — art + "Refilling the cocoa — back in 2 min! 🍫" + the magic-word banner still earning.
4. **Ending** (last 2–3 min every stream) — "Next LIVE: Friday 8:30 PM ET" card. This converts tonight's handful into Friday's returners.
Countdown source rule: **informational countdowns fine** (pre-show timer, "capsule at :45"); urgency-styled countdowns attached to asks are off-Law. Local recording ON every stream. Chatbox overlay's real use: Landscape scenes + baked-in chat context on highlight clips.

### Session structure (the craft that holds people)
- **The rolling reset:** every 10–15 min, 20 seconds of "just arrived?" — name, "this is the game I built for my daughters," what's happening, what's next. Viewers land mid-stream with ~3–10 s of patience; the algorithm widens distribution on 30-s+ dwell.
- **Promised payoff:** announce a concrete centerpiece up top and in every reset ("at the top of the hour we open the rainbow capsule"). Capsule reveals at :15/:45 as ritual beats.
- **THE GARDEN IS THE CLIFFHANGER MACHINE:** plant on Tuesday's live → os.time() offline growth → **the harvest is literally ready Friday 8:30**. "The berries we planted Tuesday are ready — we harvest live" is a built-in come-back mechanic almost no streamer has. End every stream on this hook.
- **Small-room loops:** greet by name within 30 s (100% coverage is possible at this size) · read comments ALOUD and restate before answering · **chat as game-director** — binary choices that work at n=1 ("Goo Coast or Moonlit Hollow?", a named viewer picks the capsule) · empty-room protocol: narrate decisions as if to one person; occasional playful one-tap asks TO THE ROOM ("tap if you think this one's a Rainbow") — never a standing like-meter, never like-thresholds that trigger in-game events (firing Everybody Squish via OwnerDebug is a treat you give, not a meter viewers fill).
- **Pre-live post:** a short video ~1 h before going live — engagers are far likelier to be shown the LIVE ring.

### Anti-patterns (ranked retention killers)
Dead air (narration IS the stream) · menus/settings on camera · reading chat silently · alt-tabbing (dev machine = repo/keys exposure risk; everything lives in scenes) · over-asking (gift-begging is an enforceable violation; ONE soft follow-ask per 15–30 min max) · speaking URLs (say "link in my bio") · bad audio (viewers forgive pixels, not crackle) · 15–20 min without format variation · visibly reacting to the viewer count.

### Game-side hooks (the structural advantage — he owns the code)
- Works today: garden cliffhanger · capsule ritual beats · Friend of the Week as the fixed Friday segment · OwnerDebug-fired Everybody Squish as the top-of-hour spectacle (framed as a treat).
- **Streamer Mode — BUILT (2026-08-03), unblocks the "play with viewers on camera" segment once it's published.** Today's Quests → **📸 Streamer Mode**. On YOUR screen only, every other player becomes a storybook alias ("Bubble Friend", "Cozy Friend") — the Roblox player list is hidden, overhead names go away, chat is masked (sender + body), and every shout-out, gift card, buddy tag, prompt and leaderboard row is rewritten. Your own name stays visible; nobody else's game changes. **Live-check before every stream: flip it on, confirm the Roblox player list disappears** (the instant confirmation, even solo), then look at one other player. Aliases are stable for the session, so you can say "nice find, Bubble Friend!" and mean one person.
  - Still true regardless: never say a kid's name out loud, and the daughters stay off the streamed server entirely (that rule is about minors on LIVE, not about usernames).
- Cheap build-once idea: pre-seed dated stream words in ONE publish (TIKTOK0805, TIKTOK0808… activated by date via os.time) — per-stream attribution without a code-edit+Alt+P before every stream.

### Analytics to actually watch (LIVE Center, ~60 days history)
**Average watch time, week over week** — that's the retention number; viewer count is noise at this size. Then: new followers per live, and which highlight clips drove entrances. Post 1–3 highlights after every stream (Ctrl+1 saves the past 2 min; auto-highlights + trim/captions/post tools in LIVE Center). No second-by-second LIVE retention curve exists — don't hunt for one.

## [VERIFY IN APP] — the 10-minute checks tonight

1. Which account shows LIVE on the + screen (step zero). 2. Studios account: Business or Personal. 3. LIVE Studio login grants Go-LIVE (else: in-app application; else: Rig B). 4. Phone Mobile Gaming mode appears. 5. Replay/save toggle ON pre-stream. 6. Moderator add flow (mutual follow first). 7. Whether mod pin/mute works from the browser (else spare-device console). 8. Real title character limit. 9. LIVE Event scheduling path. 10. Roblox chat-hide toggle location.
