# Roblox + Claude Code Vibe Coding Starter Guide

This file is meant to be placed inside a fresh project folder and read by Claude Code. The goal is to help a beginner set up a Roblox game-development workflow where Claude Code edits the project files from the terminal, while Roblox Studio is used to test and publish the game.

\---

## 1\. What We Are Building

We are setting up a workflow similar to the Hytopia vibe-coding workflow, but for Roblox.

The basic flow is:

```text
Claude Code in Terminal
        ↓
Local Roblox project files
        ↓
Rojo sync
        ↓
Roblox Studio
        ↓
Playtest, edit, publish
```

Claude Code will help create and edit scripts, ModuleScripts, UI files, configs, game systems, economy logic, shops, leaderboards, abilities, minigames, and documentation.

Roblox Studio will still be used for playtesting, terrain, visual placement, publishing, assets, lighting, and live Studio inspection.

\---

## 2\. Important Concept

Roblox games do not run directly from a normal terminal the way a web app or Node project does.

Roblox games are built and tested inside **Roblox Studio**. To let Claude Code work on the game from the terminal, we use a tool called **Rojo**.

Rojo syncs files from the local computer into Roblox Studio. This allows Claude Code to work with normal files and folders, while Roblox Studio receives those changes.

\---

## 3\. Tools to Install

Install these tools before starting.

### Required

1. **Roblox Studio**

   * Used to create, test, and publish Roblox games.
   * Official download: https://create.roblox.com/docs/studio/setup
2. **Claude Code**

   * Used in the terminal to edit the project, create systems, fix bugs, and generate code.
   * Official product page: https://claude.com/product/claude-code
   * Official GitHub install page: https://github.com/anthropics/claude-code
3. **Visual Studio Code**

   * Optional but strongly recommended as a code editor.
   * Claude Code can work in the terminal, but VS Code makes it easier to inspect files.
   * Download: https://code.visualstudio.com/
4. **Git**

   * Used for version control and rollback safety.
   * Download: https://git-scm.com/downloads
5. **Rojo**

   * Syncs local project files into Roblox Studio.
   * Official docs: https://rojo.space/docs/v7/
   * Installation docs: https://rojo.space/docs/v7/getting-started/installation/

### Recommended Later

These are not required on day one, but should be added once the first prototype works.

1. **StyLua**

   * Formats Luau/Lua code.
   * Helps keep code clean and consistent.
2. **Selene**

   * Linter for Lua/Luau.
   * Helps catch mistakes before testing in Studio.
3. **Wally**

   * Package manager for Roblox projects.
   * Useful when importing community packages.
4. **Luau Language Server**

   * Better autocompletion and type help in VS Code.

Rojo's documentation specifically points toward tools like Selene, StyLua, Wally, and Moonwave as part of a more professional Roblox development workflow.

\---

## 4\. Install Claude Code on Windows

Open PowerShell as your normal user.

Run the official Windows install command from Anthropic:

```powershell
irm https://claude.ai/install.ps1 | iex
```

After installation, close and reopen PowerShell.

Then check that Claude Code works:

```powershell
claude --version
```

Then log in if prompted:

```powershell
claude
```

If the command is not recognized, restart the computer and try again.

\---

## 5\. Install Roblox Studio

1. Go to the official Roblox Creator Hub Studio setup page:

   * https://create.roblox.com/docs/studio/setup
2. Download Roblox Studio.
3. Install it.
4. Open Roblox Studio and sign in.
5. Create a new blank Baseplate project.
6. Save it locally for now.

\---

## 6\. Install Rojo

Rojo can be installed several ways. The current Rojo docs recommend using **Rokit** as a Roblox toolchain manager.

Follow the official Rojo installation docs:

* https://rojo.space/docs/v7/getting-started/installation/

A typical project-based install may look like:

```powershell
rokit add rojo-rbx/rojo
rokit install
```

After installing Rojo, verify it works:

```powershell
rojo --version
```

If Rojo is not recognized, restart the terminal or verify that the install path is available in your PATH.

\---

## 7\. Install the Rojo Roblox Studio Plugin

Rojo requires a Roblox Studio plugin so Studio can connect to the local Rojo server.

General process:

1. Open Roblox Studio.
2. Install the Rojo plugin using the instructions from the Rojo docs.
3. Restart Roblox Studio.
4. Open a Roblox place.
5. Look for the Rojo plugin in the Plugins tab.

\---

## 8\. Create the First Project Folder

Create a folder somewhere easy to find, for example:

```text
C:\\Users\\Chris\\Documents\\RobloxGames\\QB1-Roblox
```

Open that folder in terminal:

```powershell
cd C:\\Users\\Chris\\Documents\\RobloxGames\\QB1-Roblox
```

Initialize Git:

```powershell
git init
```

Create a basic project structure:

```text
QB1-Roblox/
  README.md
  CLAUDE.md
  default.project.json
  src/
    ReplicatedStorage/
      Shared/
    ServerScriptService/
      Server/
    StarterPlayer/
      StarterPlayerScripts/
    StarterGui/
      ClientUI/
```

\---

## 9\. Create `default.project.json`

Create a file named:

```text
default.project.json
```

Paste this starter Rojo config:

```json
{
  "name": "QB1-Roblox",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "Shared": {
        "$path": "src/ReplicatedStorage/Shared"
      }
    },
    "ServerScriptService": {
      "Server": {
        "$path": "src/ServerScriptService/Server"
      }
    },
    "StarterPlayer": {
      "StarterPlayerScripts": {
        "$path": "src/StarterPlayer/StarterPlayerScripts"
      }
    },
    "StarterGui": {
      "ClientUI": {
        "$path": "src/StarterGui/ClientUI"
      }
    }
  }
}
```

This tells Rojo how to map local files into Roblox Studio.

\---

## 10\. Create `CLAUDE.md`

Create a file named:

```text
CLAUDE.md
```

Paste this into it:

```markdown
# Claude Code Instructions for This Roblox Project

You are helping build a Roblox game using Luau and Rojo.

## Project Goal

Build a Roblox arcade sports game called QB1-Roblox.

The first prototype should include:

- A simple player lobby
- A football throwing mechanic
- Moving target dummies or target zones
- A score counter
- A countdown timer
- A basic round loop
- A server-authoritative scoring system
- Client UI for score and timer
- Clean, modular Luau code

## Tech Rules

- Use Roblox Luau.
- Use Rojo-compatible file structure.
- Keep server code in `src/ServerScriptService/Server`.
- Keep shared modules in `src/ReplicatedStorage/Shared`.
- Keep client scripts in `src/StarterPlayer/StarterPlayerScripts`.
- Keep UI logic in `src/StarterGui/ClientUI` when needed.
- Prefer ModuleScripts for reusable systems.
- Do not put important scoring or currency logic only on the client.
- Use RemoteEvents carefully and validate data on the server.
- Keep code beginner-readable.
- Add comments where helpful.

## Development Style

Work in small, testable steps.

For each feature:

1. Explain what files you will create or edit.
2. Create the smallest working version first.
3. Tell me how to test it in Roblox Studio.
4. Then improve the system.

## Safety

Before large changes, summarize the plan.
Before deleting files, ask first.
Prefer additive changes over destructive rewrites.

## First Task

Create a minimal working prototype with:

- `GameConfig` shared module
- `RoundService` server module
- `ScoreService` server module
- `Main.server.lua` to start the game loop
- `Main.client.lua` to print client startup confirmation

After creating the files, explain how to run Rojo and test the project in Roblox Studio.
```

\---

## 11\. Start Claude Code in the Project Folder

From the project root, run:

```powershell
claude
```

Then tell Claude Code:

```text
Read CLAUDE.md and help me build the first Roblox prototype using this Rojo project structure. Start with the minimal working prototype described in the First Task section.
```

Claude Code should then inspect the folder, create the scripts, and explain how to test them.

\---

## 12\. Start Rojo Sync

In the project folder, run:

```powershell
rojo serve
```

Rojo should start a local server, often on a localhost address.

Leave this terminal running.

\---

## 13\. Connect Roblox Studio to Rojo

1. Open Roblox Studio.
2. Open a blank Baseplate place.
3. Go to the Plugins tab.
4. Open the Rojo plugin.
5. Connect to the running Rojo server.
6. Rojo should sync your local files into Studio.

Once connected, your folders should appear inside Roblox Studio in places like:

```text
ReplicatedStorage > Shared
ServerScriptService > Server
StarterPlayer > StarterPlayerScripts
StarterGui > ClientUI
```

\---

## 14\. First Test

In Roblox Studio:

1. Press **Play**.
2. Open the Output window.
3. Look for messages from client and server scripts.
4. Confirm that scripts are running.
5. Stop the test.
6. Ask Claude Code to fix any errors shown in Output.

Example prompt to Claude Code:

```text
I ran the game in Roblox Studio and got this Output error: \[paste error]. Please fix the code and explain what changed.
```

\---

## 15\. Best First Game Ideas for This Workflow

Start small. These are good first Roblox games for vibe coding:

### 1\. QB1-Roblox

A football throwing accuracy game.

Core loop:

```text
Player spawns
Round starts
Targets appear
Player throws footballs
Hits add score
Timer ends
Leaderboard updates
Player earns coins
```

### 2\. Penalty Kick Roblox

A soccer penalty shootout game.

Core loop:

```text
Aim shot
Kick ball
Goalkeeper moves
Score or miss
Advance rounds
Unlock ball skins
```

### 3\. Ark Rush Roblox

A simple obstacle/resource game inspired by your Ark Rush idea.

Core loop:

```text
Collect animals/resources
Avoid hazards
Bring items to ark
Timer pressure
Upgrade speed/capacity
```

### 4\. Zombie Chase Arena

A simple wave survival game.

Core loop:

```text
Players spawn
Zombies chase
Players survive timer
Earn coins
Buy weapons or speed boosts
```

\---

## 16\. Recommended First Milestone

Do not start with a huge open-world Roblox game.

First milestone should be:

```text
One small map
One core mechanic
One round timer
One scoring system
One simple UI
One reward loop
```

For QB1-Roblox, the first milestone should be:

```text
A player can click/tap to throw a ball at targets.
Targets give points.
A round lasts 60 seconds.
The player sees score and time.
The server controls scoring.
```

\---

## 17\. Roblox Development Concepts to Learn

Claude Code should help explain these as they come up:

```text
Workspace
ReplicatedStorage
ServerScriptService
StarterPlayer
StarterPlayerScripts
StarterGui
ModuleScript
Script
LocalScript
RemoteEvent
RemoteFunction
DataStoreService
MarketplaceService
Humanoid
Character
Tool
Part
Model
TweenService
RunService
Players service
```

Most beginner bugs happen because code is placed in the wrong Roblox service or because client/server responsibilities are mixed up.

\---

## 18\. Client vs Server Rules

Very important:

### Server should control:

```text
Scores
Coins
Purchases
Data saving
Round state
Anti-cheat validation
Damage
Rewards
```

### Client should control:

```text
UI
Camera feel
Local effects
Button clicks
Input detection
Sound effects
Animations
```

The client can request things, but the server should verify them.

Example:

```text
Client says: I clicked to throw.
Server checks: Is the player allowed to throw? Is the round active? Is the target valid?
Server decides: Score or no score.
```

\---

## 19\. How to Prompt Claude Code Well

Use specific prompts.

Good prompt:

```text
Create a server-authoritative scoring system for QB1-Roblox. Use a ScoreService ModuleScript in ServerScriptService. Add one RemoteEvent for score updates. Include testing instructions for Roblox Studio.
```

Bad prompt:

```text
Make the game better.
```

Good prompt:

```text
Add a 60-second round timer. The server should start the round, count down, and tell clients the remaining time. Add beginner-friendly comments.
```

Bad prompt:

```text
Add a timer and stuff.
```

\---

## 20\. Suggested Build Order for QB1-Roblox

Build in this order:

1. Project folder and Rojo sync
2. Client/server startup scripts
3. Shared game config
4. Round timer
5. Score system
6. Basic UI
7. Throw input
8. Football projectile
9. Target hit detection
10. Moving targets
11. End-of-round screen
12. Coins
13. Data saving
14. Cosmetic shop
15. Mobile controls
16. Sound effects
17. Polish
18. Private test
19. Publish test version
20. Improve based on feedback

\---

## 21\. Common Commands

Start Claude Code:

```powershell
claude
```

Start Rojo:

```powershell
rojo serve
```

Initialize Git:

```powershell
git init
```

Check changed files:

```powershell
git status
```

Save a version:

```powershell
git add .
git commit -m "Initial Roblox Rojo prototype"
```

\---

## 22\. Troubleshooting

### Claude Code command not found

Restart terminal or computer. Confirm Claude Code installed correctly.

### Rojo command not found

Restart terminal. Confirm Rojo or Rokit installation is complete and available in PATH.

### Roblox Studio does not show synced files

Make sure:

```text
rojo serve is running
Rojo Studio plugin is installed
Studio is connected to the local Rojo server
The project has a valid default.project.json
```

### Scripts do not run

Check whether the script type and location are correct.

```text
Server scripts go in ServerScriptService.
Client LocalScripts go in StarterPlayerScripts or StarterGui.
Shared modules go in ReplicatedStorage.
```

### RemoteEvent errors

Make sure the RemoteEvent exists in ReplicatedStorage and both client/server reference the same path.

\---

## 23\. Important Roblox Monetization Notes

Roblox monetization usually uses:

```text
Game passes
Developer products
Premium payouts
Private servers
Cosmetic purchases
```

Do not build monetization first.

Build fun first, then retention, then monetization.

Recommended order:

```text
Fun mechanic
Rounds
Progression
Coins
Cosmetics
Game passes
Developer products
```

\---

## 24\. ## MCP/API Rule

## 

## Do not require MCPs or Roblox Open Cloud for the first prototype.

## 

## Use:

## \- Claude Code for editing local files

## \- Rojo for syncing files into Roblox Studio

## \- Roblox Studio for testing and publishing

## 

## Optional MCPs:

## \- Filesystem MCP, limited only to this project folder

## \- GitHub MCP, for repo management

## 

## Do not use Roblox Open Cloud API keys until the project specifically needs publishing, asset upload, or external Roblox automation.

## Never store Roblox API keys directly in source code.

## 

## 25\. Final Starting Prompt for Claude Code

When everything is installed and this file is in the project folder, open the folder in terminal and run:

```powershell
claude
```

Then paste this:

```text
You are helping me start Roblox vibe coding using Claude Code in Terminal. Read ROBLOX\_CLAUDE\_CODE\_VIBE\_CODING\_STARTER.md and CLAUDE.md. Set up the first working Rojo-based Roblox project. Start with a small QB1-Roblox prototype. Create the folder structure, Rojo config, startup scripts, GameConfig module, RoundService, and ScoreService. Keep everything beginner-friendly and explain how I test it in Roblox Studio.
```

\---

## 26\. Summary

Yes, Claude Code can be used for Roblox vibe coding.

The key is understanding that Claude Code edits local files, Rojo syncs those files into Roblox Studio, and Roblox Studio runs/tests/publishes the game.

Start small. Get one mechanic working. Then build from there.

