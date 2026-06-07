# Squishy Smash — Roblox

A wholesome, storybook-safe Roblox collector game (ages ~4–8 friendly). Squish
sleepy **Squishy Friends** in **Pudding Hills** to fill their **Joy Meter**, watch
them **Happy Pop** into sparkles, earn **Sparkle Coins**, open a **Sparkle Capsule**,
and fill your **Squishy Book** with the 48 official launch friends.

Built with **Claude Code + Rojo**: Claude edits these local files, Rojo syncs them
into **Roblox Studio**, and Studio runs/tests/publishes the game.

## Run it

```powershell
cd D:\Roblox
rojo serve
```

Then in Roblox Studio: open a Baseplate, open the **Rojo** plugin in **Edit mode**,
click **Connect**, then press **Play**. Walk up to a sleepy friend and click it to
squish; talk to **Soft Dumpling** and use the **Sparkle Capsule** machine.

## What's here (Pudding Hills MVP)

- Server-authoritative squish → Joy → Happy Pop → Sparkle Coins loop
- The "wake up 3 sleepy friends" tutorial quest (+100 coins, first capsule free)
- The Sparkle Capsule (kind, never gambling-flavored) with a Friendship Bonus for duplicates
- The 48-card **Squishy Book** with locked/unlocked friends, zone/event tabs, and Equip Buddy
- A cozy placeholder Pudding Hills world

All character/card data comes from `src/ReplicatedStorage/Shared/SquishyDefinitions.lua`
(generated from `data/raw/`). Design docs live in `docs/`. See `CLAUDE.md` for the
full file map, the server↔client contract, and the kid-friendly content rules.

## Kid-safe by design

No combat, weapons, horror, or scary mechanics — only squish, bounce, sparkle,
discover, collect, and friendship. No monetization in this MVP.

> The earlier QB1 football learning prototype is preserved on git tag
> `qb1-prototype` and in `archive/qb1/`.
