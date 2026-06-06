# Claude Code Instructions for QB1-Roblox

You are helping Chris build a Roblox game using **Luau** and **Rojo**. Chris is
new to Roblox (coming from Hytopia), so favor clear explanations and small,
testable steps.

## Project Goal

Build a Roblox arcade football game called **QB1-Roblox**.

Long-term core loop:

```
Player spawns -> Round starts -> Targets appear -> Player throws footballs
-> Hits add score -> Timer ends -> Leaderboard updates -> Player earns coins
```

## Where Things Live (Rojo file map)

Local files are synced into Roblox Studio by Rojo. See `default.project.json`.

| Local folder | Roblox location | What goes here |
|---|---|---|
| `src/ReplicatedStorage/Shared` | ReplicatedStorage.Shared | ModuleScripts shared by client AND server (config, remote names) |
| `src/ServerScriptService/Server` | ServerScriptService.Server | Server-only logic (round loop, scoring, data) |
| `src/StarterPlayer/StarterPlayerScripts` | StarterPlayer.StarterPlayerScripts | Client LocalScripts (input, UI logic) |
| `src/StarterGui/ClientUI` | StarterGui.ClientUI | On-screen UI (added later) |

### Rojo file-name rules (important)

- `Name.lua` -> a **ModuleScript** named `Name`
- `Name.server.lua` -> a **Script** (runs on the server automatically)
- `Name.client.lua` -> a **LocalScript** (runs on the player automatically)

## Current Files

- `src/ReplicatedStorage/Shared/GameConfig.lua` - tunable numbers (timers, points)
- `src/ReplicatedStorage/Shared/Remotes.lua` - RemoteEvent names + setup/get helpers
- `src/ServerScriptService/Server/ScoreService.lua` - server-authoritative scores
- `src/ServerScriptService/Server/RoundService.lua` - the round-loop heartbeat
- `src/ServerScriptService/Server/Main.server.lua` - server entry point (wires it all up)
- `src/StarterPlayer/StarterPlayerScripts/Main.client.lua` - client entry point (logs + input)

## Tech Rules

- Use Roblox **Luau**. Top of each script file uses `--!strict` where practical.
- Keep the Rojo-compatible file structure above.
- Prefer **ModuleScripts** for reusable systems.
- **Server-authoritative always:** scores, coins, purchases, round state, data
  saving, and anti-cheat live on the **server**. The client may only ASK; the
  server VALIDATES and decides.
- RemoteEvents: define their names once in `Remotes.lua` so client and server
  never disagree. Validate every `OnServerEvent` on the server.
- Use `task.wait` / `task.spawn` (not the old `wait` / `spawn`).
- Keep code beginner-readable and comment the non-obvious parts.

## Development Style

Work in small, testable steps. For each feature:

1. Say which files you will create or edit.
2. Build the smallest working version first.
3. Tell Chris exactly how to test it in Roblox Studio (what to press, what to
   look for in Output).
4. Then improve it.

## Safety

- Before large changes, summarize the plan first.
- Before deleting files, ask first.
- Prefer additive changes over destructive rewrites.
- Never put scoring/currency logic only on the client.
- Never hard-code Roblox API keys in source.

## Build Order (current milestone first)

1. [DONE] Project + Rojo sync + client/server startup
2. [DONE] Shared GameConfig
3. [DONE] Round timer (RoundService)
4. [DONE] Server score system (ScoreService) + click-to-score placeholder
5. **NEXT:** On-screen UI for score + timer (replace Output prints)
6. Real throw input + football projectile
7. Target hit detection
8. Moving targets
9. End-of-round screen
10. Coins -> data saving -> cosmetic shop -> mobile controls -> sound -> polish

## How To Test (Studio)

1. In the project folder run `rojo serve`.
2. In Studio open the Rojo plugin and click **Connect**.
3. Press **Play**. Open the **Output** window (View -> Output).
4. You should see `[QB1 Server] Started...`, `[QB1 Client] Started...`, then
   `[QB1 Round]` lines ticking every second, and `[QB1 Score]` when you click.
5. Paste any red errors from Output back to Claude Code to fix.
