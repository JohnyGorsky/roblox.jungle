# Final Summary — Job #016: Crash-site staging area + rope Start gate

**Project**: `roblox.jungle`
**Completed**: 2026-07-18
**Status**: ✅ Built, analyzer-clean, verified live via Studio MCP. **Functional greybox POC** — the
crash-site hub is a throwaway placeholder for the human's hand-built version.

## What was implemented

A **staging phase** in front of the river run (same place, phased), gated by a new run-state flag.

- **`RunStarted` (new game-state flag)** — `Workspace:SetAttribute("RunStarted", …)`. None existed before;
  this is the first real game-state gate (replicates to clients for spawn + HUD).
- **`StagingServer`** (`sync/ServerScriptService/Staging/`) —
  - **Moors the boat** at spawn: `hull.Anchored = true` + `Tied = true` (safe from the constant current;
    `claimServerOwnership` early-returns on a grounded assembly so ownership isn't fought — same as
    DockServer's tie). The boat spawns **off the pier** (~26 studs) with a visible brown rope to the winch.
  - **Pull-to-reel:** a **"Pull rope"** ProximityPrompt on a placeholder **Winch** cube reels the boat in
    toward the pier (`PULL_STEP` per pull, smooth lerp, rope shortens). Once within `DOCK_DIST` it **docks**
    alongside the pier (boardable — verified: boat edge overlaps the gangway, floats at the waterline).
  - **Then untie = START:** once docked the same prompt becomes **"Untie rope — START"**. Untie requires
    **someone aboard** (`OnBoatCount ≥ 1`, so the boat can't sail off without the crew) → `RunStarted=true`,
    unanchor, `Tied=false`, remove the rope + prompt. **The hub is left standing** (crew has sailed off) —
    it is NOT torn down (fixed the "everything disappears" issue).
  - **Greybox hub** (a `StagingArea` folder — clearly marked PLACEHOLDER, for the hand-built hub): a bank
    platform, a "plane wreck" block, a gangway, and the **Winch cube** (placeholder for a future winch
    asset). Publishes `HubSpawn` (Vector3) for the spawn logic.
  - **Occupancy counter:** while staging, publishes `Boat.OnBoatCount` / `Boat.CrewCount` (players whose
    HRP is inside the hull's oriented box, expanded for the back deck) for the HUD.
- **Spawn branch** (`PlayerCombat.server.luau`) — before start, spawn at the **hub** (`HubSpawn`); after
  start, on the **boat** (mid-run respawns land on the boat, as before).
- **Threat gate** (`EnemyServer.server.luau`) — the sea + land spawn directors now also require
  `RunStarted`; no enemies during staging.
- **Staging HUD** (`StagingHint.local.luau`) — a pre-run banner "Board the boat & untie the rope to START"
  + **"N/M on boat"** (turns green when the whole crew is aboard). Hides once `RunStarted`.
- **Handoff marker** — a documented `HANDOFF_Z` constant marks where the hand-built startup section will
  end. **Not enforced yet** (procedural river still builds from `Z_START` this POC); a follow-up job will
  point `RiverBootstrap` at `HANDOFF_Z` once the hub + startup river are hand-built.

## Verification (live via Studio MCP)

- [x] `bash tools/luau-analyze.sh` clean (whole-project sweep).
- [x] **Staging state:** `RunStarted=false`; boat **anchored + tied**; `StagingArea` built
      (HubPlatform/PlaneWreck/Gangway/MooringPost); rope on hull; untie prompt present; `HubSpawn` set.
- [x] **Spawn at hub:** player spawned 0.5 studs from `HubSpawn` (141 studs from the boat).
- [x] **No threats during staging:** 0 `Enemy`-tagged models.
- [x] **HUD (screenshot):** banner + "0/1 on boat" render.
- [x] **Start opens the gate** (performed StagingServer's exact `startRun` state change): `RunStarted=true`
      → boat **unanchored** (drivable) + `Tied=false`, `StagingArea` removed, **3 enemies** spawned within 3s.
- [x] **Post-start respawn** lands on the **boat** (3.9 studs from hull), not the hub.
- [~] **The physical untie prompt-hold** couldn't be driven by the MCP harness (same limitation as #014's
      seated input; `fireproximityprompt`/`InputHoldBegin` aren't processed headless). The
      `prompt.Triggered → startRun` wiring is a one-line connect identical to DockServer's proven tie/untie,
      and the resulting started-state was verified by applying the same state change. **Needs a human
      click-the-prompt playtest** to close.

## Files

- **New:** `sync/ServerScriptService/Staging/StagingServer.server.luau`,
  `sync/StarterPlayer/StarterPlayerScripts/UI/StagingHint.local.luau`.
- **Edited:** `sync/ServerScriptService/Combat/PlayerCombat.server.luau` (spawn branch),
  `sync/ServerScriptService/Enemies/EnemyServer.server.luau` (RunStarted gate ×2).
- **Untouched:** BoatServer, DockServer, CargoServer, GunServer, ExcursionServer, RiverBootstrap.
- New: `Jobs/016/*`.

## Notes / follow-ups

- **Not committed.**
- **Human hand-builds** the real crash-site hub + startup river section (deletes the greybox `StagingArea`).
- **Follow-up job:** switch procedural generation to begin at `HANDOFF_Z` (hand-built → procedural handoff).
- **Generalize pull-to-reel to EVERY pier (user request):** the reel-in-with-the-rope mechanic should also
  work at the river docks (`DockServer`). Best done by extracting a shared "moor + winch reel" module used
  by both StagingServer and DockServer (avoid duplicating the reel/rope code). → **follow-up job.**
- **Winch asset:** the pull action currently lives on a placeholder cube — swap for a winch model later.
- **Hangs off this hub next:** role assignment (P2), pre-run Robux shop (P8), lobby place + party teleport
  (P6) — the two-place front end.
- The greybox hub camera clips the bank terrain (cosmetic); irrelevant once hand-built.
- Tune: hub position/side, untie hold time, occupancy box bounds.
