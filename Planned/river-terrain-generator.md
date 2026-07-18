# Seeded river + terrain generator (reusable module)

**Source:** Spike #004 "Next" + Job #003 (P1) follow-up. **Depends:** #004 (voxel direction locked).

The winding river the boat drives on is currently a **one-off baked into the live place** — the boat
even hardcodes a centerline/waterline **measured** from that sculpt. It does not regenerate, and if the
terrain is re-sculpted the boat constants silently desync.

## Scope
- A reusable module: **input a seed → river centerline + carved channel + terrain water + flanking
  noise hills** (altitude-painted grass → rock → snow), built with the `roblox-terrain` verify
  discipline (compute geometry → carve-then-fill → read-back verify).
- **Stream/cull** ahead of / behind the boat for a long river (mobile perf).
- Expose the centerline as **shared data** so both the terrain and the boat (`BoatServer`) read the
  same source instead of duplicating hardcoded constants.
- Same seed → same river (random per run, or a shared **daily seed** for fair leaderboards).

## Why it matters
Turns the greybox river into real, regenerable content; removes the boat↔terrain constant desync;
foundation for endless mode (P10) and fair seeded runs.

→ Promote to a job (likely alongside P5 zones).
