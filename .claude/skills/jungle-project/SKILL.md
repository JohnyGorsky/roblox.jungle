---
name: jungle-project
description: Roblox Jungle project context — architecture, Studio Sync rules (auto-sync vs manual-copy), file/system map, code standards, the luau-lsp analyzer command, and non-negotiable rules. Consult this before doing ANY work in roblox.jungle. This is the source of truth for the game; its CLAUDE.md just points here. STUB — fill in as the game is built.
---

# Roblox Jungle — project context

> **STUB.** This is the source of truth for the Roblox Jungle game, mirroring the shape of Defender's
> `defender-project` skill. Fill each section in as the game takes shape. Use the shared `roblox-dev`
> skill for engine APIs and the shared `roblox` agent for the job workflow. Follow the workspace
> `GROUND-RULES.md` above all.

## Overview

_TODO: what Jungle is (see [GAME.md](../../../GAME.md))._ Roblox game in **Luau**, synced with Roblox
Studio via Roblox Studio Sync.

## Architecture (client–server, FilteringEnabled)

Server is authoritative. _TODO: list the synced top-level folders and core systems once they exist._

## Sync behavior (critical when editing)

**All scripts live under a top-level `sync/` folder on disk** (differs from Defender, which mirrors
services at the repo root). Confirmed against the live Studio Explorer ⇄ icons (2026-07-17);
`.jobconfig.json` mirrors this list.

- **Auto-syncs** (⇄ icon): `sync/ReplicatedFirst/`, `sync/ReplicatedStorage/`,
  `sync/ServerScriptService/`, `sync/ServerStorage/`, and **both** `sync/StarterPlayer/StarterCharacterScripts/`
  **and** `sync/StarterPlayer/StarterPlayerScripts/` (note: Jungle syncs StarterCharacterScripts too,
  unlike Defender).
- **Manual copy** (no ⇄): `sync/StarterGui/`, `sync/StarterPack/`, `sync/Workspace/`.

_TODO: confirm the Rojo `default.project.json` mapping and whether any manual-copy services exist on
disk at all; keep `.jobconfig.json` aligned._

## Diagnostics — luau-lsp analyzer

_TODO: add the analyzer command once the project has one (e.g. `bash tools/luau-analyze.sh <file>` +
`default.project.json` + generated `sourcemap.json`). After editing any `.luau`, run it and fix
findings before moving on._

## Non-negotiable rules

Same engine baseline as the shared `roblox-dev` skill (server-authoritative, attribute signals,
`pcall` around DataStore/HttpService/MarketplaceService, `task.*`, `.luau` + PascalCase). _TODO: add
Jungle-specific rules as they emerge._

## Jungle content skills

_TODO: add game-specific playbook skills (add-*/design system/balance) as the game grows._

## Jobs

`python ../roblox.workspace/tools/job.py new --project jungle "Title" "Requirements"` (then `plan`,
`summary`, `release`). Keep `.jobconfig.json` accurate so `summary` categorizes files correctly.

## Asset sources

Meshy.ai (via `roblox-chars`) for models, Flaticon for icons, Pixabay for sounds — see
`GROUND-RULES.md` §4.
