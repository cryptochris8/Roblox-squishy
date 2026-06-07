# QB1-Roblox

A beginner Roblox arcade football game, built with **Claude Code + Rojo**.
Claude edits the local files here; **Rojo** syncs them into **Roblox Studio**;
Studio runs, tests, and publishes the game.

## Requirements

- [Roblox Studio](https://create.roblox.com/docs/studio/setup)
- [Rojo](https://rojo.space/) (installed via [Rokit](https://github.com/rojo-rbx/rokit))
- Git

## Quick start

```powershell
# 1. Install the toolchain (one time)
rokit install

# 2. Make sure the Rojo Studio plugin is installed (one time)
rojo plugin install

# 3. Start syncing
rojo serve
```

Then in Roblox Studio: open a Baseplate, open the **Rojo** plugin, click
**Connect**, and press **Play**. Watch the **Output** window for `[QB1 ...]`
messages.

## Project layout

```
default.project.json          Rojo file map (local files -> Studio)
rokit.toml                    Pinned tool versions (Rojo, etc.)
CLAUDE.md                     Instructions/context for Claude Code
src/
  ReplicatedStorage/Shared/   Shared modules (GameConfig, Remotes)
  ServerScriptService/Server/ Server logic (Round + Score services, Main)
  StarterPlayer/.../          Client LocalScript (Main.client)
  StarterGui/ClientUI/        On-screen UI (added later)
```

## How it works (the golden rule)

The **server** owns the truth (scores, round state, rewards). The **client**
only shows things and asks the server to do things. The server always validates.
See `CLAUDE.md` for the full rules and build order.
