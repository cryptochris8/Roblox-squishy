# 00 — Start Here

This package gives Claude Code the full direction for building **Squishy Smash on Roblox**.

## What this project is

Squishy Smash is a wholesome Roblox collector/simulator game connected to the Squishy Smash storybook world, the official 48 launch character cards, the existing iOS app concept, and future events, giveaways, toys, books, and Shopify products.

The Roblox game should feel like the player is walking inside the world of the cards and the storybook.

## Source material included

- `docs/book2_the_lost_sparkle_manuscript_draft.md` — storybook manuscript and chapter/spread notes
- `data/raw/launch_squishy_foods.json` — Squishy Foods launch pack
- `data/raw/goo_fidgets_drop_01.json` — Goo & Fidgets launch pack
- `data/raw/creepy_cute_pack_01.json` — Creepy-Cute Creatures launch pack
- `data/raw/dumpling_squishy_drop_01.json` — future weekly/event pack
- `assets/card_samples/` — sample official card images
- `generated_lua/` — starter Lua module data generated from the JSON

## Development stack

Use Claude Code in terminal, Roblox Studio for testing and publishing, Rojo for syncing local files to Studio, and Git for saving work.

Do not require MCPs, Open Cloud, or Robux monetization for the first prototype.

## Immediate coding priority

1. Project structure and Rojo mapping
2. Shared data modules from `generated_lua/`
3. Player data: Sparkle Coins, discovered cards, total squishes
4. Pudding Hills starter zone with placeholder squishy friends
5. Kid-friendly squish interaction and Happy Pop reward
6. Collection Book UI using the 48 launch roster
7. Capsule machine that discovers cards
8. Basic save/load with DataStore after local systems work

For the MVP, do not build all three full zones at once. Start with Pudding Hills and build the systems cleanly so Goo Coast and Moonlit Hollow can be added next.
