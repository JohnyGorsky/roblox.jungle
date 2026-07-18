# Land excursions — landing sites, camps & villages to raid

**Source:** GAME.md "Landing sites & land excursions" (2026-07-18). **Depends:** #005 (river generator),
docks (P4), land combat (P3).

Turn "reach a dock and scavenge" into a real set-piece: at **designated landing sites** the river widens
onto a **coast / open bank**, the crew **disembarks onto bigger walkable terrain**, treks to a **camp or
village**, **raids it** (guarded loot: fuel/ammo/currency/upgrades), and hauls it back. The boat waits,
exposed.

## Scope (future)
- **Widened, walkable terrain** at landing sites — coastline/clearing/village footprint, sized for
  on-foot play (much wider than the travel channel).
- **Generator = multiple seeded modes/biomes** stitched along the route: main river + POI zones (coast,
  jungle village, ruined temple, hunter camp…). Extends the Job #005 `RiverData`/`RiverGenerator` from
  one river mode to many. Keep those modules **mode-aware** so this drops in cleanly later.
- **Raid gameplay** — defended camps/villages; loot tables; carry-back; boat-defense trade-off (who
  stays vs who raids).
- Placement of landing sites along the run (spacing, escalation, guaranteed vs random).

## Open questions
- Are landing sites **fixed** points in the run or seeded/random? (Leaderboard fairness vs variety.)
- How big is a village footprint on mobile perf? Streaming a wide POI zone vs the narrow channel.
- Overlap with the plain "refuel dock" — are all docks raidable, or are camps/villages special?

## Why it matters
This is the river game's equivalent of Dead Rails' **towns** — the reason to stop, the loot spikes, the
best risk/reward moments, and a major source of variety & replay.

→ Promote to a job (after the main river + docks exist).
