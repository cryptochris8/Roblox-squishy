--!strict
-- GiftConfig
-- Gifting v1: GIFTS, not trades. Walk up to another player, tap 🎁, and give
-- Sparkle Coins or SHARE a friend you've discovered — the recipient gets the
-- discovery and the card reveal, and YOU KEEP YOURS (sharing, never losing, so
-- nobody can be talked out of their collection). Same-server only, picked
-- amounts only (no typing), and a small daily limit so generosity stays gentle
-- and nobody gets pestered for more. Shared so the client picker and the server
-- validator always agree.

local GiftConfig = {}

-- The only coin amounts a gift can be (the picker offers exactly these, the
-- server accepts exactly these — no free-typed numbers anywhere).
GiftConfig.CoinPresets = { 25, 50, 100, 250 }

-- Gifts a player can SEND per UTC day. Small on purpose: enough for "one for
-- each sister and a friend", not enough to farm or feel pressured about.
GiftConfig.DailyGiftLimit = 5

-- How close you must be to see the 🎁 prompt on another player...
GiftConfig.PromptDistance = 10

-- ...and how far apart the two of you may drift before the server says
-- "walk closer" (generous, because kids wander mid-confirm).
GiftConfig.SendRange = 30

return GiftConfig
