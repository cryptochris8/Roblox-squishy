# 08 — Asset Import and Placeholder Plan

## Card images

Upload real card images to Roblox Studio through Asset Manager. Copy each Roblox asset id and paste it into the matching character entry as `ImageAssetId` or `CardImageAssetId`.

Example:

```lua
ImageAssetId = "rbxassetid://1234567890"
```

## Start with sample cards

Use the 8 sample cards in `assets/card_samples/` to test Collection Book and capsule reveal first.

## 2D render strategy

These are 2D renderings of consistent 3D-style characters. Treat them as official canon art.

For MVP: use card images in UI and simple Roblox part models in the world.

Later: create 3D Roblox buddy models for the most popular characters, starting with Soft Dumpling, Goo Ball, Blushy Bun Bunny, Galaxy Dumpling, and Glow Ghost Puff.

Do not delay the game because 3D models are not ready. The card art is already strong enough to carry the collection system.
