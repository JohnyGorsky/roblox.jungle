# Asset registry — Last River (roblox.jungle)

Our fast, greppable catalog of every asset in the game: **what we created** and **what we used**, so we
**reuse before re-sourcing** (our-assets-first). One file per asset type. See the `roblox-assets` skill
for the full workflow (our-assets-first → present for approval → scan for scripts → store → log here).

## Rule of thumb
- Before sourcing anything new, **grep this registry** — we may already have it.
- Every asset added to the game gets a row here (id, source, license, where stored).
- All inserted third-party assets were **script-scanned** before use (delete any scripts we didn't author).

## Files
- [models.md](models.md) — Models (boat, plane, props, structures)
- [meshes.md](meshes.md) — MeshParts / meshes
- [images.md](images.md) — images, decals, icons, UI art
- [audio.md](audio.md) — sound effects, music, ambience
- [animations.md](animations.md) — character/object animations
- [ui.md](ui.md) — UI templates / prefabs

## Row format
`| Name | rbxassetid / path | Type | Source (ours/created · Meshy · Creator Store · Pixabay · Flaticon) | License | Stored at | Scanned? | Notes |`
