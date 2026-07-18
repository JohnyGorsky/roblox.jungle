# Final Summary — Job #015: Weapons loadout (sword default + guns earned at camps) + 4-slot inventory

**Project**: `roblox.jungle`
**Completed**: 2026-07-18
**Status**: ✅ Built, analyzer-clean, core paths verified live via Studio MCP. **Functional greybox** —
polish (anim/art/HUD layout/balance) deferred per user ("just functional, we will polish it later").

## What was implemented

A real loadout on top of a new **4-slot inventory** (one item active at a time), all
**server-authoritative** with state on the **Player** so it survives death/revive within a run.

- **Inventory core**
  - `ItemDefs` (ReplicatedStorage) — the item catalog (Sword / Pistol / Shotgun) with per-gun stats +
    each gun's own ammo attribute. `SLOT_COUNT = 4`.
  - `InventoryService` (ServerStorage, shared server module) — authoritative state on Player attributes
    (`Slot1..4`, `ActiveSlot`, `ActiveItem`, `AmmoPistol`, `AmmoShotgun`). `seed` (once per run, sword in
    slot 1), `equip`, `drop` (can't drop the sword), `grant` (looted gun → first free slot, or refills
    ammo if already owned; refuses when full), `addAmmo`, plus a greybox **held-item visual** welded to
    the right hand, re-applied on respawn.
  - `InventoryServer` — seeds players, handles the `InventoryCmd` remote (equip/drop).
- **Sword (default fallback)** — `MeleeServer` + `MeleeClient`. Tap-to-swing when the sword is active;
  server validates (holding sword, not busy/downed, cooldown 0.6s) and hits the **nearest enemy in front
  within 9 studs** (same `Enemy`/`CampGuard` tag + `HP`-attribute convention as the guns), 15 damage.
- **Pistol = the looted #006 handheld** — `WeaponServer`/`WeaponClient` now fire **only when a gun is the
  active slot item**, drawing from **per-player ammo** (not the boat pool). Crosshair shows only with a gun
  equipped; a red flash cues empty.
- **Shotgun (new gun)** — same server path with a per-weapon config: 6-pellet spread, own ammo, short range.
- **Per-weapon-type ammo** — `AmmoPistol` / `AmmoShotgun` per player. The **mounted turret (#014) keeps
  the shared boat pool** — untouched.
- **Camp loot (ExcursionServer)** — loot crates now carry a `Kind`: `"Weapon"` grants a gun to a slot
  (no carry), `"Ammo"` tops up that gun's ammo, `"Resource"` = the existing carry→trailer path. The deep
  camp of each landing gets a **scarce weapon crate** (pistol/shotgun alternating by landing) + a matching
  ammo crate.
- **Dead-Rails carry** — reused the existing `Busy` attribute (already blocks all weapons); canister/metal
  hauling → trailer deposit is unchanged.
- **Hotbar UI** — `InventoryHud`, mobile-first 4-slot bar (bottom-left), tap to equip, active-slot
  highlight, per-gun ammo, a "hands full" banner while carrying (+ keyboard 1–4 / Q for Studio testing).

## Verification (live via Studio MCP)

- [x] `bash tools/luau-analyze.sh` clean (whole-project sweep).
- [x] All new scripts synced into the DataModel.
- [x] Services boot clean (`[Inventory] loadout service online`, no errors).
- [x] **Seed** → slot 1 = Sword, active = Sword, ammo 0.
- [x] **Grant Pistol** → slot 2, `AmmoPistol` 24; **equip** switches `ActiveItem` + welds the held visual.
- [x] **Hotbar UI** renders (screenshot): Sword / Pistol(24, highlighted) / empty / empty.
- [x] **Sword targeting** — selects the front enemy at 5 studs (range 9), applies 15 dmg (100→85).
- [x] **Pistol fire** (real client→server) decrements per-player ammo 10→7.
- [x] **Driver gate** — a seated driver can't fire the handheld.
- [x] **Sword-active gate** — firing the gun remote while holding the sword is rejected (ammo unchanged).
- [x] **Shotgun grant** → slot 3, `AmmoShotgun` 8.
- [~] **Camp weapon/ammo crates** — built by construction (exact working `LootCrate` pattern + verified
      `grant`/`addAmmo`), but the in-world spawn needs a **driving playtest** to a landing dock (camps only
      build as the boat approaches). Same limitation as #014's seated flow.

## Files

- **New:** `sync/ReplicatedStorage/Inventory/ItemDefs.luau`,
  `sync/ServerStorage/Inventory/InventoryService.luau`,
  `sync/ServerScriptService/Inventory/InventoryServer.server.luau`,
  `sync/ServerScriptService/Combat/MeleeServer.server.luau`,
  `sync/StarterPlayer/StarterPlayerScripts/Combat/MeleeClient.local.luau`,
  `sync/StarterPlayer/StarterPlayerScripts/UI/InventoryHud.local.luau`.
- **Edited:** `sync/ServerScriptService/Combat/WeaponServer.server.luau`,
  `sync/StarterPlayer/StarterPlayerScripts/Combat/WeaponClient.local.luau`,
  `sync/ServerScriptService/Excursion/ExcursionServer.server.luau`.
- **Untouched:** `Combat/GunServer`+`GunClient` (#014), `Cargo/CargoServer` core (boat ammo pool stays
  for the turret).
- New: `Jobs/015/*`.

## Notes / follow-ups

- **Not committed.**
- **Playtest to tune:** sword damage/range/cooldown, per-gun ammo capacities, shotgun spread, and the
  **weapon-crate spawn rate / which camps drop pistol vs shotgun** (currently every deep camp, alternating).
- **Deferred (as agreed):** swing/gun animations (P9), gun tiers beyond pistol/shotgun, gamepass slot
  expansion, real sword/gun art, a proper HUD layout, carry WalkSpeed penalty, cross-run DataStore
  persistence (this is within-run only).
- Ties open the door for **P2 role-stations** (helpers = sword/gun fighters) and the rest of the weapon
  vision.
