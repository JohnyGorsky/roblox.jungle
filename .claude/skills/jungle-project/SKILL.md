---
name: jungle-project
description: Roblox Jungle project context — architecture, on-disk sync/ layout & Studio Sync rules, the Rojo project + luau-lsp analyzer command, code standards, and non-negotiable rules (server-authoritative, mobile-first). Consult this before doing ANY work in roblox.jungle. This is the source of truth for the game; its CLAUDE.md just points here.
---

# Roblox Jungle — project context

Source of truth for the **Roblox Jungle** game. Read it before touching Jungle code. Use the shared
`roblox-dev` skill for engine APIs and the shared `roblox` agent for the job workflow; follow the
workspace `GROUND-RULES.md` above all.

## What the game is

A 1–6 player co-op **jungle river-run survival** game (working title — name TBD): crash-land, take a
boat down an escalating, animal-infested river, work swappable roles, scavenge fuel/ammo at docks, and
reach the end. **Mobile-first.** Full vision + design in [GAME.md](../../../GAME.md); production roadmap
in [Jobs/001/](../../../Jobs/001/implementation-plan.md); queued phases in [Planned/](../../../Planned/).

## Architecture

- **Two places:** a **lobby** (team up 1–6 → reserved-server teleport) and the **gameplay** place
  (the river run). Server is **authoritative** — validate all client input; especially critical for
  currency, inventory, revives, and scoring (real money involved).
- **On-disk layout:**
  - `sync/<Service>/` — all scripts that auto-sync with Studio (see sync table below).
  - `assets/` — models/images/audio kept in-repo (non-script).
  - `manual/` — content that does **not** auto-sync (StarterGui/Workspace etc.) and needs a manual
    Studio copy.
  - `Jobs/`, `Planned/` — job workflow.

## Sync behavior (critical when editing)

**All scripts live under a top-level `sync/` folder** (differs from Defender's repo-root layout).
Verified live against the Studio Explorer ⇄ icons (2026-07-18); `.jobconfig.json` + `default.project.json`
mirror this.

- **Auto-syncs** (⇄): `sync/ReplicatedFirst/`, `sync/ReplicatedStorage/`, `sync/ServerScriptService/`,
  `sync/ServerStorage/`, and **both** `sync/StarterPlayer/StarterCharacterScripts/` **and**
  `sync/StarterPlayer/StarterPlayerScripts/` (Jungle syncs StarterCharacterScripts too, unlike Defender).
- **Manual copy** (no ⇄): `StarterGui/`, `StarterPack/`, `Workspace/` — keep these under `manual/`.

## Rojo file-type suffix convention

Under `sync/`, the filename suffix sets the instance class:
- `*.server.luau` → **Script** (server logic; put in `ServerScriptService`).
- `*.local.luau` → **LocalScript** (client; `StarterPlayerScripts`, `StarterCharacterScripts`, `ReplicatedFirst`).
- `*.luau` → **ModuleScript** (shared code; `ReplicatedStorage`).
- ⚠️ A LocalScript (`*.local.luau`) **won't run** in `ServerScriptService`/`ServerStorage`/`ReplicatedStorage`.

## Rojo — analyzer only, NOT a sync tool

Disk↔Studio syncing is handled by **Studio's built-in Sync** (not Rojo). **Rojo is used only to
generate `sourcemap.json`** (`rojo sourcemap`, one command — never `rojo serve`) so the luau-lsp
analyzer can resolve `require()`/`WaitForChild`/Instance types. `default.project.json` is just a
description of the DataModel tree the analyzer reads; it syncs nothing.

## Diagnostics — luau-lsp analyzer (run after every script edit)

```bash
bash tools/luau-analyze.sh <sync/path/File.luau>   # check the file(s) you just edited
bash tools/luau-analyze.sh                          # whole-project sweep (sync/ roots)
```

It regenerates `sourcemap.json` from `default.project.json` (via Rojo 7.6.1) and runs `luau-lsp analyze`
with the `roblox` platform. **After editing any `.luau`, run it and fix findings before moving on.**
Without the sourcemap, every `require()`/`WaitForChild(...)` is a false positive. Requires the
`JohnnyMorganz.luau-lsp` VS Code extension (settings in `.vscode/settings.json`).

## Non-negotiable rules

- **Server-authoritative** (see shared `roblox-dev`): validate client input; `:GetAttributeChangedSignal`
  for stat replication; `pcall` DataStore/HttpService/MarketplaceService; `task.*` scheduler.
- **Mobile-first (hard requirement):** every control + GUI is touch-first and **scale-based** (`UDim2`
  scale, `UIAspectRatioConstraint`/`UIScale`, safe-area aware); no keyboard-only actions; no fixed-pixel
  layouts. See GAME.md "Platform & input".
- `.luau` extension; PascalCase; `*Helper/*Definition/*Constants` suffixes; type annotations; `--!strict`
  in new ModuleScripts where practical.

## Jobs

`python ../roblox.workspace/tools/job.py new --project jungle "Title" "Requirements"` (then `plan`,
`summary`, `release`). `summary` uses `.jobconfig.json` for the sync table. Every job ends with a
short player-facing `changelog.md` (GROUND-RULES §5).

## Assets

Meshy.ai for models + rigged animated characters (via `roblox-chars`); Creator Store search/insert
(Claude proposes → you approve); Pixabay (sound), Flaticon (icons), ChatGPT (art). See GROUND-RULES §4.

## Content skills

_None yet — add game-specific playbook skills (a GUI design system, add-enemy/animal, etc.) as the
game grows through the P1–P10 roadmap._
