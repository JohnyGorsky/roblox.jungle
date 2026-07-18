# Weapon loadout — sword default + guns earned at camps

**Source:** GAME.md "Weapons & combat" (2026-07-18). **Depends:** #006/#014 (handheld + mounted gun exist).

Turn the current always-on handheld gun into a proper **loadout**:

## Scope
- **Sword = the default.** Every player without a gun carries a **melee sword**: hit enemies at **very
  short range** only, always available. Needs a melee hit system (swing → short-range hitbox/raycast →
  damage, server-authoritative), a greybox sword tool, a swing anim later (P9).
- **Guns are earned at camps.** A player only free-aims a **gun** once they've **looted one at a camp**
  (a weapon crate → grants a pistol to that player). Track a per-player "has gun" state; the handheld
  weapon (already built) is gated behind it. Different guns/tiers later.
- **Reconcile with existing weapons:** the handheld free-aim (#006) becomes the pistol; the mounted gun
  (#014) is the gunner's; the sword is the fallback. One clean "what am I holding?" model.

## Open questions
- Per-player weapon inventory vs a single equipped slot? Do guns persist through a run or drop on death?
- Sword damage/range/cooldown vs guns; is the sword viable vs a swarm or purely a fallback?
- Do helpers spawn with a sword only, and pistols are a scarce camp reward?

## Why it matters
Gives combat **progression** (sword → gun) and makes camp raids meaningful (guns are a top reward),
and fits the role model (helpers = fighters with sword/gun).

→ Promote to a job.
