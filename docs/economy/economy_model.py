#!/usr/bin/env python3
"""
Squishy Smash - coin economy model (WO-0.1, docs/14_FUN_UPGRADE_DIRECTIONS.md section 5 WO-0 item 1).

Encodes the LIVE faucet/sink numbers (each cited to file:line in
docs/economy/ECONOMY_MODEL.md) plus the upgrade plan's projected additions
(chain bonus / co-squish / weather / garden / picnic-race-firefly trickles /
rotated Sparkle Bit pool), then prints three 30-minute session profiles:
coins today vs projected, and the WO-0 acceptance check
(projected top-end <= ~1.5x today's top-end).

Run:  python economy_model.py            (stdlib only, no deps)
Tune: edit CONSTANTS / PLAN / PROFILES and re-run. Keep ECONOMY_MODEL.md's
      tables in sync with this output (this script is the calculator; the md
      is the citation + rationale layer).
"""

# ---------------------------------------------------------------------------
# 1) LIVE GAME CONSTANTS (source of truth: the Lua files; cites in the md)
# ---------------------------------------------------------------------------

# Expected coins per Happy Pop, per land pack. Pads pick uniformly from the
# 16-friend pack (SquishService.pickDefForPack), so EV = sum(CoinReward)/16.
# Sums tallied from SquishyDefinitions.lua (8 commons + 4 rares + 3 epics +
# 1 mythic per launch pack).
POP_EV = {
    "pudding": 344 / 16,   # 21.50  commons 8-10, rares 16-18, epics 28-30, mythic 120
    "goo":     388 / 16,   # 24.25  commons 10-14, rares 18-19, epics 32-34, mythic 130
    "moonlit": 440 / 16,   # 27.50  commons 12-18, rares 20-24, epics 36,    mythic 140
}

TUTORIAL_REWARD   = 100    # GameConfig.TutorialRewardCoins
FIRST_DAY_TOTAL   = 130    # FirstDayConfig steps: 20+0+30+30+50
SHARD_REWARDS     = {"pudding": 150, "goo": 250, "moonlit": 400}   # ZoneConfig
FINALE_REWARD     = 1000   # GameConfig.FinaleRewardCoins (one-time, lifetime)
BIT_COINS         = 25     # GameConfig.SparkleBitCoins
BIT_ALL_BONUS     = 300    # GameConfig.SparkleBitAllBonus
BIT_COUNT         = 26     # SparkleBitConfig.Bits (10 + 8 + 8)
PAGE_COINS        = 25     # StoryPageConfig.PageCoins (one-time each)
PAGE_ALL_BONUS    = 300    # StoryPageConfig.AllBonus (one-time)
PAGE_COUNT        = 18
QUEST_AVG_REWARD  = (50 + 45 + 35 + 60 + 70) / 5   # 52 - DailyQuestConfig pool avg
SURGE_MULT        = 2      # SocialConfig.SurgeCoinMultiplier
SURGE_GOAL_PP     = 15     # SocialConfig.SurgePopsPerPlayer (solo goal = 15 pops)
SURGE_DURATION_S  = 60     # SocialConfig.SurgeDurationSeconds
EVENT_REWARD      = 150    # SocialConfig.EventRewardCoins (everyone online, on success)
EVENT_GOLDEN_MULT = 3      # SocialConfig.EventGoldenCoinMultiplier
EVENT_GOAL_PP     = 4      # SocialConfig.EventGoalPerPlayer (golden pops per player)
COIN_BOOST_MULT   = 1.25   # MonetizationConfig.CoinBoostMultiplier (pass; pop stream only)
CAPSULE_COST      = 100    # CapsuleConfig Cost (all three capsules)
DUP_SPARKLY       = 30     # VariantConfig level-1 bonusCoins
DUP_RAINBOW       = 60     # VariantConfig level-2 bonusCoins
DUP_MAXED         = 25     # VariantConfig.MaxDuplicateCoins
WEEKLY_BEFRIEND   = 400    # WeeklyConfig.Cost (sink)
CODE_TOTAL        = 150 + 150 + 200 + 250 + 300    # CodeService (one-time, lifetime = 1050)
STREAK_DAY        = lambda d: 20 + 10 * (min(d, 7) - 1)   # GameConfig streak (20 base, +10/day, caps day 7)

# ---------------------------------------------------------------------------
# 2) PLAN PROJECTIONS (docs/14 section 5 - values recommended by this model)
# ---------------------------------------------------------------------------

CHAIN_CAP            = 5     # WO-1.3: +1 coin per chain step, capped at +5. FLAT -
                             # add AFTER multipliers so surge can't double the cap.
WEATHER_MULT         = 1.5   # WO-6: recommended (doc names no number; must be < surge x2)
WEATHER_UPTIME       = 0.20  # share of a session the local land's weather is active
SEED_YIELD_MULT      = 1.5   # WO-5: harvest coins = seed price * this (parameterized)
SEED_SPROUT          = 50    # 1-day seed  -> harvest 75
SEED_BLOOM           = 300   # 5-day Rainbow Bloom -> harvest 500 (450 + decor-roll value)
SEED_BLOOM_DAYS      = 5
PICNIC_COINS         = 15    # WO-2.8: per completed picnic circle (recommended, equal to all)
RACE_COINS           = 20    # WO-2.5: per race, EVERY finisher (recommended)
FIREFLY_COINS        = 1     # WO-9.1c: per firefly wisp (in the doc)
ROTATED_BITS_PER_DAY = 12    # WO-3.3: ~12 of ~40 spots active per day (keeps all-found bonus)
STAR_PATH_PER_DAY    = 10    # WO-3.4: milestone chests amortized (rec. 100@d3 + 150@d5, 30-day cycle)

GARDEN_NET = {   # net coins/session from harvests minus replanted seeds
    "new": -SEED_SPROUT,                                          # plants 1, harvests tomorrow
    "mid": 2 * SEED_SPROUT * (SEED_YIELD_MULT - 1),               # 2 sprout cycles/day = +50
    "end": 2 * SEED_SPROUT * (SEED_YIELD_MULT - 1)                # sprouts + a 5-day bloom
           + SEED_BLOOM * (SEED_YIELD_MULT - 1) / SEED_BLOOM_DAYS,  # amortized  = +80
}

# ---------------------------------------------------------------------------
# 3) SESSION PROFILES (assumptions - stated in ECONOMY_MODEL.md "Assumptions")
# ---------------------------------------------------------------------------
# surge_frac = share of pops landing inside x2 surge windows. Mechanical ceiling
# for continuous solo popping at r pops/min is r/15 (15-pop goal, 60s window);
# assumptions sit below it: new 3/min -> ceiling .20, mid 4/min -> .27, end 8/min -> .53.

PROFILES = {
    "NEW PLAYER": dict(
        key="new", minutes_popping=15, pops_per_min=3.0,
        pop_ev=POP_EV["pudding"], surge_frac=0.10,
        golden_events=1, bits=4, pages=3, dailies_done=1.5,
        streak_day=1, daily_capsule_ev=0,     # daily capsule = a new discovery, 0 coins
        onetime=TUTORIAL_REWARD + FIRST_DAY_TOTAL + SHARD_REWARDS["pudding"],
        onetime_label="tutorial 100 + First Day 130 + shard 150",
        chain_avg=1.0, picnics=1, races=1, fireflies=0,
        star_path=0, bits_rotated=False,
    ),
    "MID-GAME": dict(
        key="mid", minutes_popping=15, pops_per_min=4.0,
        pop_ev=(POP_EV["pudding"] + POP_EV["goo"]) / 2, surge_frac=0.20,
        golden_events=2, bits=10, pages=2, dailies_done=3,
        streak_day=5, daily_capsule_ev=DUP_SPARKLY,   # typical dupe = Sparkly +30
        onetime=0, onetime_label="(shard 250 / finale 1000 are one-time, excluded)",
        chain_avg=2.5, picnics=2, races=2, fireflies=10,
        star_path=STAR_PATH_PER_DAY, bits_rotated=False,
    ),
    "ENDGAME": dict(
        key="end", minutes_popping=20, pops_per_min=8.0,
        pop_ev=(POP_EV["goo"] + POP_EV["moonlit"]) / 2, surge_frac=0.40,
        golden_events=3, bits=BIT_COUNT, pages=0, dailies_done=3,
        streak_day=7, daily_capsule_ev=DUP_MAXED,     # full book -> maxed dupe +25
        onetime=0, onetime_label="(finale 1000 already claimed)",
        chain_avg=4.5, picnics=2, races=2, fireflies=20,
        star_path=STAR_PATH_PER_DAY, bits_rotated=True,
    ),
}

# ---------------------------------------------------------------------------
# 4) THE MODEL
# ---------------------------------------------------------------------------

def bits_value(found, rotated):
    if rotated:
        # WO-3.3: only the day's active spots exist; all-found bonus kept per day.
        return ROTATED_BITS_PER_DAY * BIT_COINS + BIT_ALL_BONUS
    return found * BIT_COINS + (BIT_ALL_BONUS if found >= BIT_COUNT else 0)

def session_lines(p, projected):
    """Return (label, today_value, projected_value) line items for one profile."""
    pops = p["minutes_popping"] * p["pops_per_min"]
    ev = p["pop_ev"]
    base = pops * ev
    surge = base * p["surge_frac"] * (SURGE_MULT - 1)
    golden = p["golden_events"] * (EVENT_REWARD + EVENT_GOAL_PP * ev * (EVENT_GOLDEN_MULT - 1))
    dailies = p["dailies_done"] * QUEST_AVG_REWARD
    streak = STREAK_DAY(p["streak_day"])
    bits_today = bits_value(p["bits"], False)
    pages = p["pages"] * PAGE_COINS

    lines = [
        (f"Happy Pops ({pops:.0f} pops x {ev:.2f} EV)", base, base),
        (f"Sparkle Surge x2 overlap ({p['surge_frac']:.0%} of pops)", surge, surge),
        (f"Everybody Squish events ({p['golden_events']} x (150 + 4 golden pops x2 extra))", golden, golden),
        (f"Daily quests ({p['dailies_done']:g} x 52 avg)", dailies, dailies),
        (f"Login streak (day {p['streak_day']})", streak, streak),
        (f"Sparkle Bits ({p['bits']} x 25{' + 300 all-found' if p['bits'] >= BIT_COUNT else ''})",
         bits_today, bits_value(p["bits"], p["bits_rotated"])),
        (f"Story pages, one-time ({p['pages']} x 25)", pages, pages),
        ("Free daily capsule (dupe coin EV)", p["daily_capsule_ev"], p["daily_capsule_ev"]),
        (f"One-time quest coins ({p['onetime_label']})", p["onetime"], p["onetime"]),
    ]
    # --- plan additions (today = 0) ---
    additions = [
        (f"+ Sparkle Chain (avg +{p['chain_avg']:g}/pop, cap +{CHAIN_CAP}, flat)",
         pops * p["chain_avg"]),
        (f"+ Weather bonus (max-vs-surge, x{WEATHER_MULT} on {WEATHER_UPTIME:.0%} of non-surge pops)",
         pops * (1 - p["surge_frac"]) * WEATHER_UPTIME * (WEATHER_MULT - 1) * ev),
        ("+ Co-squish shared credit (solo model: 0; family sessions +10-15% pops)", 0),
        (f"+ Garden net (harvests - seeds, yield x{SEED_YIELD_MULT:g})", GARDEN_NET[p["key"]]),
        (f"+ Picnic circles ({p['picnics']} x {PICNIC_COINS})", p["picnics"] * PICNIC_COINS),
        (f"+ Slide races ({p['races']} x {RACE_COINS}, every finisher)", p["races"] * RACE_COINS),
        (f"+ Firefly wisps ({p['fireflies']} x {FIREFLY_COINS})", p["fireflies"] * FIREFLY_COINS),
        ("+ Star Path chests (amortized/day)", p["star_path"]),
    ]
    for label, val in additions:
        lines.append((label, 0, val))
    return lines

def totals(lines):
    return sum(t for _, t, _ in lines), sum(v for _, _, v in lines)

def pop_stream(p, projected):
    """The part of income Coin Boost (x1.25) multiplies: SquishService awards only."""
    pops = p["minutes_popping"] * p["pops_per_min"]
    ev = p["pop_ev"]
    base = pops * ev
    surge = base * p["surge_frac"] * (SURGE_MULT - 1)
    golden_extra = p["golden_events"] * EVENT_GOAL_PP * ev * (EVENT_GOLDEN_MULT - 1)
    stream = base + surge + golden_extra
    if projected:  # weather rides the same multiplier path; chain is flat (post-multiplier)
        stream += pops * (1 - p["surge_frac"]) * WEATHER_UPTIME * (WEATHER_MULT - 1) * ev
    return stream

# ---------------------------------------------------------------------------
# 5) REPORT
# ---------------------------------------------------------------------------

def main():
    W = 78
    print("SQUISHY SMASH ECONOMY MODEL (WO-0.1) - 30-minute session profiles")
    print("=" * W)
    results = {}
    for name, p in PROFILES.items():
        lines = session_lines(p, projected=True)
        today, proj = totals(lines)
        results[name] = (today, proj)
        print()
        print(f"{name}  ({p['minutes_popping']} min popping @ {p['pops_per_min']:g}/min)")
        print("-" * W)
        print(f"{'faucet':<58}{'today':>9}{'projected':>11}")
        for label, t, v in lines:
            ts = f"{t:,.0f}" if t else "-"
            vs = f"{v:,.0f}" if v else ("0" if t else "-")
            print(f"{label:<58}{ts:>9}{vs:>11}")
        ratio = proj / today
        print(f"{'TOTAL coins / 30 min':<58}{today:>9,.0f}{proj:>11,.0f}")
        print(f"{'ratio projected vs today':<58}{'':>9}{ratio:>10.2f}x")
        bt = today - pop_stream(p, False) + pop_stream(p, False) * COIN_BOOST_MULT
        bp = proj - pop_stream(p, True) + pop_stream(p, True) * COIN_BOOST_MULT
        print(f"  (with Coin Boost pass x1.25 on the pop stream: "
              f"today {bt:,.0f} -> projected {bp:,.0f}, x{bp / bt:.2f})")

    print()
    print("=" * W)
    end_today, end_proj = results["ENDGAME"]
    bar = 1.5
    verdict = "PASS" if end_proj <= bar * end_today else "FAIL"
    print(f"WO-0 ACCEPTANCE: projected top-end {end_proj:,.0f} vs today {end_today:,.0f}"
          f" = x{end_proj / end_today:.2f}  ->  {verdict} (bar: <= ~x{bar:g} today's top-end)")

    print()
    print("SINK AFFORDABILITY (1 session/day; today's rates)")
    print("-" * W)
    mid_day = results["MID-GAME"][0]
    end_day = results["ENDGAME"][0]
    sinks = [
        ("Sparkle Capsule open (net of dupe return)", CAPSULE_COST - DUP_SPARKLY),
        ("Sparkle Swap (recommended)", 250),
        ("Rotating shelf item (recommended 450-600)", 600),
        ("Weekly visitor befriend", WEEKLY_BEFRIEND),
        ("Rainbow Ribbon trail (priciest coin cosmetic)", 600),
        ("Room wave-2 item (recommended 250-500)", 500),
        ("Big room upgrade (recommended)", 5000),
        ("Rainbow Bloom seed", SEED_BLOOM),
    ]
    print(f"{'sink':<48}{'price':>7}{'mid days':>10}{'end days':>10}")
    for label, price in sinks:
        print(f"{label:<48}{price:>7,}{price / mid_day:>10.2f}{price / end_day:>10.2f}")
    print()
    print("Lifetime one-time faucets: tutorial 100 + First Day 130 + shards 800")
    print(f"  + finale 1,000 + pages 750 + magic words {CODE_TOTAL:,} = 3,830 coins")
    print("Lifetime one-time sinks today: Boutique coin catalog 3,250 + Room catalog")
    print("  4,150 + 8 weekly visitors x 400 = 3,200  ->  10,600 coins")

if __name__ == "__main__":
    main()
