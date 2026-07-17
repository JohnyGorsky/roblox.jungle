# Implementation Plan — Job #003: P1 boat + winding-river vertical slice

**Project**: `roblox.jungle`
**Created**: 2026-07-18
**Status**: In progress (greybox)

## Goal

Prove the core feel: **driving a boat down a winding river feels good.** Greybox only — placeholder
art, no combat/roles/fuel. Built and iterated **live in the "Jungle run" place via the Studio MCP**.

## Approach

**Terrain — HYBRID (revised 2026-07-18 after the scripted-terrain struggle; see workspace Job 003):**
1. **Winding river + island** — **hand-sculpted by the user** in Studio's Terrain Editor (Sculpt/Draw
   + Sea Level for water), which is faster and looks better than scripting it. Claude does NOT script
   the hero river. If a deterministic greybox water surface is wanted, Claude can drop a flat
   translucent water **Part** at the waterline (see `roblox-terrain` skill recipe).
2. **Placeholder boat** — built by Claude's code at the river start.

**On disk (sync/ → auto-syncs; the real deliverable):**
3. **Boat controller — physics, not teleport.** The boat is an unanchored low-density hull that
   **floats on terrain water**, driven by **real forces**:
   - `VectorForce` **Thrust** (world-space, at center of mass) = hull look-vector × throttle → momentum
     + water drag give an engine feel.
   - `AngularVelocity` **Steer** (yaw) → the boat turns while linear momentum carries it = **drift**.
   - Input via a **`VehicleSeat`** (WASD + default mobile controls; auto network-ownership to driver).
   - Tunable constants (THRUST, TURN, DENSITY). Anti-tip/buoyancy assist added only if Play shows it.
   - Location: `sync/ServerScriptService/Boat/BoatServer.server.luau` (server builds + drives the boat).
4. **Chase camera** — follows the boat; framed for a phone.
5. **Mobile-first controls** — on-screen steer/throttle (touch) + keyboard (WASD) mapping the same
   actions. `UDim2` scale UI.

## Iteration loop (via MCP)

Sculpt/adjust → `screen_capture` → review → tune. Repeat until steering the bends feels good. The
**human playtests** for actual feel (Claude can't feel it); Claude verifies mechanics + screenshots.

## Success test

- [ ] A winding (non-straight) river cut into sculpted terrain, water flowing bank to bank.
- [ ] Boat steers/throttles and follows the river's curves responsively.
- [ ] Works on a phone-sized viewport with touch controls.

## Notes

- Terrain + boat Part live in Workspace/Terrain (not auto-synced) — **user saves the place** to persist.
- Controller scripts on disk auto-sync. Run `bash tools/luau-analyze.sh` after each script edit.
