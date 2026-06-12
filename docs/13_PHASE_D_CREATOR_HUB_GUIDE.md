# 13 — Phase D: Creating the Products in Creator Hub (Chris's step)

> **✅ DONE (2026-06-11).** All 9 products were created, the IDs below are
> wired into `MonetizationConfig.lua`, and the Phase D build shipped the same
> day (see doc 11's build log). This guide stays as the reference for price
> changes, icon swaps, or future products.

This is the one Phase D step only the account owner can do: creating the Game
Passes and Developer Products on the Creator Hub website. It takes about
15 minutes. When you're done, paste the IDs into the table at the bottom (or
just tell Claude in chat) and the Phase D build session wires everything up.

**Prices below were locked on 2026-06-10. No coin packs in v1. Sparkle
Capsules stay free forever** (nothing random is ever sold for Robux — that's
our Paid Random Items / kid-safety line).

---

## The shopping list

### Game Passes (one-time purchases) — create 3

| # | Name | Price | What it will do in-game |
|---|------|-------|--------------------------|
| 1 | Extra Buddy Slot | 99 R$ | Walk with TWO buddies at once |
| 2 | Coin Boost | 149 R$ | +25% Sparkle Coins from every Happy Pop (stacks with Sparkle Surge) |
| 3 | Sparkle Club VIP | 249 R$ | Golden ✨ VIP sparkle + exclusive aura on your buddy's name tag, a VIP welcome shout-out, and +1 daily gift (6/day) |

Copy-paste names + descriptions (short, honest, kid-tone):

> **Extra Buddy Slot** — Bring TWO squishy buddies on your adventure! Both
> friends follow you everywhere across all three lands.

> **Coin Boost** — Earn +25% Sparkle Coins from every Happy Pop, forever!
> More coins for capsules, the Boutique, and your Squishy Room.

> **Sparkle Club VIP** — Join the Sparkle Club! A golden VIP sparkle and an
> exclusive aura for your buddy, a special welcome when you arrive, and one
> extra gift to share every day.

### Developer Products (premium Boutique cosmetics) — create 6

These appear on a new "Premium" shelf in the Sparkle Boutique. The game will
only let each one be bought once per player (it remembers ownership), and
buying auto-wears it, same as the coin items.

| # | Name | Type | Price |
|---|------|------|-------|
| 1 | Strawberry Beret | hat | 79 R$ |
| 2 | Rainbow Heart Balloon | balloon | 99 R$ |
| 3 | Unicorn Horn | hat | 149 R$ |
| 4 | Comet Trail | trail | 199 R$ |
| 5 | Golden Halo | hat | 249 R$ |
| 6 | Aurora Ribbon | trail | 249 R$ |

One shared description works for all six (tweak if you like):

> A premium sparkle for your buddy! Auto-wears the moment you get it, stays
> yours forever, and everyone in the world can see it.

(If you'd rather launch with fewer, create any subset — the config adapts.)

---

## Before you start (1 minute)

- Log into **the account that owns Squishy Smash** (the game is under your
  user, not a group).
- The game must be published — it is. ✓
- Each product needs an **icon image**: up to **512×512**, `.jpg`/`.png`/`.bmp`,
  and nothing important near the corners (it's shown in a **circle**).
  - Don't stress about icons today — any cute square screenshot or card-art
    crop works, and you can replace them later without changing the IDs.
  - ⚠️ Moderation caution (lesson from the June 10 strike): keep icons
    simple and obviously wholesome — a single friend's face, a hat on a plain
    pastel background. Avoid busy abstract pink-toned collages.
  - ✅ **A matching icon pack is ready in `marketing/product_icons/`** — one
    512×512 PNG per product, named to match this guide (`pass_*` /
    `prod_*`), all circle-safe. Just upload each file as you create its
    product (`_contact_sheet.png` previews the whole set; regenerate or
    tweak any of them via `marketing/make_product_icons.py`).

---

## Creating the Game Passes (official Creator Hub path)

For each of the 3 passes:

1. Go to **create.roblox.com** → **Creations** → click **Squishy Smash: The
   Lost Sparkle**.
2. In the left menu: **Monetization** → **Passes**.
3. Click **Create a Pass**.
4. Upload the icon, enter the **name** and **description** from the list
   above, click **Create Pass**.
5. Put it on sale: back on **Monetization → Passes**, hover the pass → **⋯**
   → **Sales** → turn ON **Item for Sale** → enter the price in **Price in
   Robux** → **Save Changes**.
6. Grab the ID: hover the pass → **⋯** → **Copy Asset ID** → paste it into
   the table below.

## Creating the Developer Products

For each of the 6 cosmetics:

1. Same experience page → **Monetization** → **Developer Products**.
2. Click **Create a Developer Product**.
3. Upload the icon, enter the **name**, **description**, and **price**, then
   click **Create Developer Product**.
4. Grab the ID: hover the product → **⋯** → **Copy Asset ID** → table below.

---

## Paste the IDs here (or just tell Claude in chat)

```
GAME PASSES
Extra Buddy Slot (99):       _____1874460336_______
Coin Boost (149):            ____1874900312________
Sparkle Club VIP (249):      ___1875272322_________

DEVELOPER PRODUCTS
Strawberry Beret (79):       ___3604067414_________
Rainbow Heart Balloon (99):  ______3604067788______
Unicorn Horn (149):          ___3604067990_________
Comet Trail (199):           _____3604068204_______
Golden Halo (249):           ____3604068473________
Aurora Ribbon (249):         ______3604068682______
```

---

## What happens after you paste the IDs (Claude's side)

- A `MonetizationConfig.lua` holding the IDs + the premium catalog entries.
- Server: `UserOwnsGamePassAsync` checks on join (+ purchase prompt
  handling), and `ProcessReceipt` for the Developer Products — idempotent,
  server-authoritative, granted once and persisted in the profile (old-server
  safe via the serialize carry-through).
- Boutique gets a **Premium shelf** (R$ price tags, "Owned ✓" states, the
  same gentle confirm); VIP perks + second buddy + coin boost wired in.
- Studio test purchases are **simulated and free**, so the whole flow gets
  playtested before anything goes live. Then the usual: Alt+P publish +
  Restart Servers.

## Guardrails (unchanged, for the record)

- Sparkle Capsules stay free — nothing random is sold for Robux, ever.
- All 48 friends stay earnable by every player; coin paths never get removed.
- Sell style and convenience, never power. No coin packs in v1.
