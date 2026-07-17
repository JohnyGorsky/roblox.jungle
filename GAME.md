# Jungle *(working title — name TBD)* — game description

> **v0.2 working draft** (Job 001). Core concept + core mechanics agreed; finer details marked _OPEN_.
> High-level vision lives here; the production roadmap + object inventory live in
> [Jobs/001/implementation-plan.md](Jobs/001/implementation-plan.md); queued work goes in
> [Planned/](Planned/).

## One-line pitch

A 1–4 player co-op survival game: your plane crashes in the jungle, so you take a boat down a
dangerous river — crocodile- and predator-infested — each player working a role, scavenging fuel and
ammo at docks, pushing through escalating zones to reach the end.

## Genre & feel

Co-op **river-run survival / action**. Tense but fun; escalating difficulty; short-to-medium sessions
built around "ride → reach a dock → scavenge → ride further." Stylized **low-poly** art direction.

## Structure (two places)

1. **Lobby place** — players gather and **team up (1–4)**. When ready, the team is **teleported to a
   private reserved gameplay server**.
2. **Gameplay place** — the jungle river journey.

## The run (core loop)

1. **Crash-in** — the plane crashes; players start at a small landing area, regroup, grab first
   supplies, and board the boat.
2. **Ride the river** — the boat travels downriver through **crocodile- and predator-packed** water.
   Players work **roles** (below) to survive.
3. **Reach a dock** — you **can't ride endlessly**: fuel drains, so you must reach the next
   **designated dock** before it runs out, disembark, and **scavenge gasoline, ammo, and items** —
   under threat.
4. **Escalate** — each zone downriver is **harder** (more/tougher animals, tighter resources), and a
   **day/night cycle** makes night sections more dangerous.
5. **Reach the end** — the campaign is a **finite sequence of zones** to a fixed END. (An **endless
   mode** comes in a later version.)

## Player roles (swappable stations)

Players move freely between **stations** on the boat during the run (flexible for 1–4 players):
- **Driver** — steers and controls speed; avoids hazards; docks the boat.
- **Gunner** — fires at attacking animals (ammo-limited).
- **Catcher / scavenger** — grabs floating/nearby items; manages supplies.
- **4th station** _(OPEN — e.g. repair/mechanic to fix boat damage, or a second gunner)_.

## Threats, stake & fail/win

- **Both the boat and the players are at stake.** Animals/hazards damage the **boat** (boat HP →
  destroyed = run over) *and* can **down players** (teammates can **revive** the downed).
- Threats: **crocodiles** + other predators (river & bank), river hazards (rapids/rocks — _OPEN_), and
  **night** raising danger.
- **Win:** reach the end of the campaign. **Fail:** boat destroyed, whole crew downed, or stranded
  out of fuel. (Exact thresholds TBD.)

## Resources

- **Gasoline** — gates how far you ride between docks.
- **Ammo** — gates the gunner.
- Likely also **repair kits / health**, and collectibles for score. _(OPEN)_

## Progression & replay

- **Score & leaderboards** — primarily **distance / zones reached** + performance (animals fought,
  items caught, crew survival). Global + friends boards.
- Monetization/unlocks: **decide later** — nail the core loop first.

## Open questions (tracked; resolve as we build)

- [ ] Solo play: is 1 player viable (auto-assist idle stations / difficulty scale), or min 2? _(leaning: playable solo, scaled)_
- [ ] The 4th role.
- [ ] Number/length of campaign zones for v1.
- [ ] Which specific animals beyond crocodiles; do they attack boat, players, or both per-type.
- [ ] Exact fail thresholds and revive rules.

## Assets needed — **Jungle's own** (the existing Meshy library is Defender's, not for Jungle)

See [Jobs/001/implementation-plan.md](Jobs/001/implementation-plan.md) for the full inventory mapped to
production phases. Broad strokes: jungle river terrain + docks, boat, crashed plane, crocodile & other
animals, low-poly flora/props, fuel/ammo pickups; systems for matchmaking/teleport, boat control,
roles, animal AI, resources, day/night, scoring; lobby + in-run HUD; and jungle/boat/animal audio.
