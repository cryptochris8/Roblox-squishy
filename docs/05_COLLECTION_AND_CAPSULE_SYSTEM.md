# 05 — Collection and Capsule System

## Collection Book

The Collection Book should show all 48 launch cards, locked/unlocked state, card number, character name, pack/world, rarity, large card image, short lore, and equipped buddy status.

Use tabs: All, Pudding Hills, Goo Coast, Moonlit Hollow, Events.

Locked cards should use silhouettes, card number, and pack color hint. Do not use scary locked visuals.

## Capsule machine

Call it a Squishy Capsule or Sparkle Capsule.

Player-facing language: Open Capsule, Discover a Friend, New Card Discovered, Already Discovered — Friendship Bonus.

Avoid pull, gamble, loot box, jackpot, and betting.

## Capsule reveal flow

Player approaches capsule, confirms opening, soft sparkle animation plays, capsule wobbles, card back appears, card flips, full card image appears, text says “Discovered Soft Dumpling!”, and the card is added to the Collection Book.

## Duplicate handling

Show “Friendship Bonus!” and grant Sparkle Coins or stickers. Never make the player feel punished.

## MVP rarity odds

Common 55, Rare 25, Epic 12, Legendary 6, Mythic 2.

The raw JSON contains pack-specific pity/unlock data. Preserve it for later, but start simple.

## DataStore plan

Save SparkleCoins, DiscoveredCards keyed by character id, EquippedBuddyId, TotalSquishes, TotalHappyPops, and CompletedQuests. Use DataStore only after local prototype works.
