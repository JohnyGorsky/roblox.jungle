# Jungle *(working title — name TBD)* — game description

> **v1.0 — concept LOCKED** (Job 001, 2026-07-18). Core concept, market position, and core mechanics
> agreed. Remaining detail is tracked in "Open questions" + "Not yet covered" below and resolved as
> each build phase comes up. High-level vision lives here; the production roadmap + object inventory
> live in [Jobs/001/implementation-plan.md](Jobs/001/implementation-plan.md); queued phases are in
> [Planned/](Planned/).

## One-line pitch

A co-op survival game (~1–6 players): your plane crashes in the jungle, so you take a boat down a
dangerous river — crocodile- and predator-infested — each player working a role, scavenging fuel and
ammo at docks, pushing through escalating zones to reach the end.

## Genre & feel

Co-op **river-run survival / action**. Tense but fun; escalating difficulty; short-to-medium sessions
built around "ride → reach a dock → scavenge → ride further." Stylized **low-poly** art direction.

## Platform & input — **mobile-first** (hard requirement)

The game **must be mobile-ready.** Every control and every GUI is designed for touch first, then
scales up to PC/console:
- **GUI uses scale, not fixed pixels** — `UDim2` scale + `UIAspectRatioConstraint`/`UIScale`, safe-area
  aware; readable and tappable on a phone. No pixel-perfect layouts that break on small screens.
- **Touch controls** — on-screen buttons/joystick for driving, shooting, catching, interacting; tap
  targets sized for thumbs; no keyboard-only actions. PC keys/mouse map onto the same actions.
- **Performance** budget suits mobile (low-poly, sensible draw distance, streaming) — see P8.
- This is a standing constraint on **every** GUI/role/interaction phase, not a one-time task.

## Design reference — Dead Rails (north star)

Our closest comparable is the hit Roblox co-op game **Dead Rails**: a team rides a **train** through
an undead frontier, fuels/defends it, stops at towns to scavenge & buy, earns money, and races to
reach the end. It's a **proven, popular template** — we're deliberately building the same
shared-vehicle co-op survival loop, reskinned and differentiated:

| Dead Rails | Jungle (ours) |
|---|---|
| Train on **rails** (linear track) | **Boat on a river** (river = the "track"; steer within it) |
| Wild-West / **undead** | **Jungle** / crocodiles & predators |
| Coal/fuel to move | **Gasoline** at docks |
| Defend the train | Defend the **boat** (+ players, revive) |
| Stop at **towns** to loot/buy | Stop at **docks** to scavenge/refuel |

**Decision — the river winds; the driver actively steers.** The current funnels you downstream
(semi-on-rails *direction*, so it stays authorable and easy to balance), but the river is **curved,
never a straight lane** — the driver must steer around bends, rocks, and rapids, so the role takes
real skill. Not a straight corridor, not full open-water free-roam.

**Boat handling — physics, not teleport.** The boat moves via **real Roblox physics forces** (thrust +
turning applied as constraints/forces), so it has **momentum, acceleration, and drift** — it feels like
a real engine-driven boat, not "hold W and slide." Turning through the bends should feel weighty and
satisfying. This is a core feel pillar (prototyped in P1).

## Market & competition (why this can win)

Landscape scan (Jul 2026):
- **Land "Dead Rails-likes" are saturated** — Dead Roads (~40M visits), DEADFRONT (~15M), plus
  anime/magic/pets reskins; Dead Rails still leads but is well off its 2025 peak.
- **The water/river cell is wide open.** The closest analog, **Dead Sails** ("Dead Rails but a boat,"
  sea/pirate, 4-player) peaked ~22K concurrent but **cratered to ~50 and looks abandoned** — no healthy
  incumbent to beat.
- **No jungle-themed river-boat game exists.** That exact cell is unoccupied — our clearest opening.

**How we win (attacking the incumbents' weak spots):**
1. **Own the jungle river** — canopy ambushes, rapids, caiman/piranha, fog, hostile tribes, temple
   ruins: things a desert-train or open-ocean game structurally can't do.
2. **River-specific mechanics** — current, branching tributaries (risk/reward), waterfalls/portage,
   rising water, log/dam blockages. Fresh vs "drive straight across flat terrain."
3. **Crisp interdependent roles** — Dead Sails' thin loop failed to retain; make coordination the fun.
4. **Mobile-first** — the genre spreads via mobile/short-form; boat steering suits touch (our pillar).
5. **Live-service + progression** — clones die from *abandonment*; a steady cadence of new stretches,
   events, boats & upgrades is the moat.

> _Cautionary tale:_ Dead Sails proves theme alone isn't enough — a thin loop + no updates kills
> retention. Depth of roles + live ops is where we must not cut corners.

## Structure (two places)

1. **Lobby place** — players gather and **team up (~1–6)**. When ready, the team is **teleported to a
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

> **Core tension (borrowed from Dead Rails):** the boat is **safest while moving** — attacks intensify
> when you're **stopped** (at a dock, or stranded out of fuel). Since **fuel forces stops**, fuel
> management becomes the central risk/reward decision of every run. Every stop is a deliberate gamble.

## Day / night cycle (flips where it's safe — the run's heartbeat)

- **Day** — the **river is the safe lane**; travel and make progress. Going ashore to scavenge is the
  daytime risk (core tension: stopping = exposure).
- **Night** — the **water turns deadly** (nocturnal predators, low visibility). Race to reach a **dock
  before dark and hold out / fortify on land until dawn**, or gamble on **pushing through** with a
  **searchlight** upgrade. Night is the "hold out and defend" set-piece.

Rhythm: **travel + scavenge by day, survive the night.** Makes the **searchlight** a meaningful upgrade
and turns "reach the next dock before nightfall" into constant fuel/time pressure.

## Player roles (swappable stations)

Players move freely between **stations** on the boat during the run (flexible for 1–4 players):
- **Driver** — steers and controls speed; avoids hazards; docks the boat.
- **Gunner** — fires at attacking animals (ammo-limited).
- **Catcher / scavenger** — grabs floating/nearby items; manages supplies.
- **4th station** _(OPEN — e.g. repair/mechanic to fix boat damage, or a second gunner)_.

**Player count / scaling _(OPEN)_.** Baseline 1–4, but we may support **more players**. Options if we do:
- **Limited stations + unlimited deck defenders** — only a few control-stations (driver, special guns),
  but *any* extra player rides the deck and fights with a **personal weapon** + helps scavenge. Simple,
  everyone's useful. _(leaning)_
- **Bigger boat, more stations** — scale stations with team size (2 gunners, spotter, etc.).
- **Convoy** — multiple boats for large groups (more systems).

**Target (from market data):** the genre sweet spot is **~4–8 co-op** (Dead Rails 16-server cap but
small squads; Dead Sails 4/expedition). Plan for a **~4–6 core crew** using the *limited-stations +
deck-defenders* model so extras always contribute; larger lobbies/convoy are a later mode.

## World & environment

- **Built with terrain.** Islands, riverbanks, and landmasses are **sculpted Roblox terrain** (not flat
  parts) — hills, cliffs, beaches, jungle floor — for a natural, organic look.
- **The river winds.** A **curved, meandering** river (never straight) with bends, narrows, rapids, and
  possible forks — the corridor the run travels along. Steering it is core to the driver role.
- **Currents.** The river pushes the boat **downstream along the channel**, and current **strength
  varies by section** — calm stretches vs fast **rapids** that fling you along (harder to steer, less
  fuel burn) and slow eddies. A river-specific mechanic land/ocean games can't do.
- **Waterfalls / drops.** Vertical drops as **set-piece moments** — brace, drop, keep control. (Bigger
  feature — targeted at P5, needs multi-level river.)
- **Placeholder first:** early phases greybox the terrain + river to test feel; final flora, water
  detailing, and set-pieces come in the art pass (P9).

## Threats, stake & fail/win

- **Both the boat and the players are at stake.** Animals/hazards damage the **boat** (boat HP →
  destroyed = run over) *and* can **down players** (teammates can **revive** the downed).
- Threats: **crocodiles** + other predators (river & bank), river hazards (rapids/rocks — _OPEN_), and
  **night** raising danger.
- **Win:** reach the end of the campaign. **Fail:** boat destroyed, whole crew downed, or stranded
  out of fuel. (Exact thresholds TBD.)

## Resources

- **Gasoline** — the boat's fuel. Players **scavenge fuel at docks and physically haul it back to the
  boat** to keep it running (like feeding coal to the Dead Rails train). The tank **drains as you ride**,
  so the crew must keep topping it up between/at stops — run dry and you're **stranded = swarmed**.
  This "keep feeding the boat" chore is a constant, shared crew job.
- **Ammo** — gates the gunner; scavenged/bought and carried back too.
- Likely also **repair kits / health**, and collectibles for score. _(OPEN)_

## Progression & replay

- **Score & leaderboards** — distance / zones reached + performance (animals fought, items caught, crew
  survival). Global + friends boards.
- **Run objectives** — optional in-run goals (survive a night, N kills, reach the next dock fast) that
  pay bonus cash + meta currency. Cheap to author, big replay boost (Dead Rails leans on these).
- **Persistent unlocks** — meta currency (below) buys permanent **boat upgrades** and **skills/classes**
  in the lobby; individual runs otherwise start fresh.

## Economy & monetization (must sell — but *fair, not pay-to-win*)

Three-tier model mirroring Dead Rails' proven, well-liked economy:
- **In-run cash** — scavenged/earned during a run, spent at **dock shops** (fuel, ammo, weapons,
  healing, repairs). **Resets each run.**
- **Persistent meta currency** _(name TBD)_ — rare; from **run objectives** + completing runs. Spent in
  the **lobby** on permanent **boat upgrades**, **skills/classes**, and starting gear. **Earnable free.**
- **Robux** — **convenience & cosmetics only**: **paid self-revive**, **extra inventory slots**,
  cosmetics/skins, maybe a starter boat / game pass. Core power stays earnable.

**Revive model** (matches Dead Rails, and your brief): a downed player is revived by a **teammate
holding interact with a bandage** — bandages are **scarce**, so it's a real resource cost. On death,
the paid **self-revive** (Robux, short window) is the monetized safety net. A skill/class may grant a
free revive ability.

> **Design principle:** Dead Rails' monetization works *because it "feels fair."* Paid = convenience +
> cosmetics, never raw power. We hold to that — it's why the model sells long-term.

## Inventory

- Players have an **inventory** of carried items — bandages, fuel cans, ammo, collectibles, scavenged
  loot.
- It's **capacity-limited** (you can't hoard everything), which creates real choices at docks about
  what to grab/keep.
- **Extra inventory space is purchasable** (soft currency and/or Robux) — another monetization lever.
- _OPEN: per-player vs shared boat stash; slot-based vs weight; do fuel/ammo count against it or are
  they separate boat tanks._

## Not yet covered (design/production backlog)

Captured so nothing's forgotten; most resolve inside their build phase. ★ = decide early (foundational).

**Design**
- Onboarding / tutorial (esp. first-time **mobile** players)
- ★ Combat depth: weapon types, **mobile aiming** (auto-aim?), reload, melee
- ★ Enemy roster beyond crocs + a spawn/pacing "director"
- Health / downed-timer / healing model (bandages vs medkits)
- ★ Boat feel: steering model, buoyancy/physics, collisions, camera
- ★ Map authoring: handcrafted vs procedural zones, length, checkpoints
- End-game: what happens after the finish; prestige / replay hook
- Boat variety & customization (stats, skins)

**Systems / tech**
- ★ Matchmaking: party, friends-only vs fill, join/leave/rejoin mid-run
- ★ Reserved-server teleport + data hand-off (lobby → game)
- ★ Persistence: DataStore for meta currency / unlocks / stats + data-loss safety
- ★ Anti-cheat / strict **server authority** (critical — real money involved)
- Cross-server leaderboards; performance/streaming budget for mobile; analytics/KPIs

**Content / art**
- ★ Jungle's own **GUI design system** (its own skill, like Defender's `roblox-gui`)
- Art style guide (low-poly consistency); asset pipeline (Meshy + Creator Store + Pixabay/Flaticon/
  ChatGPT — see `GROUND-RULES.md §4`); music & ambient audio; VFX / game-feel juice

**Live-ops / business**
- Daily rewards, quests/missions, seasons/events (battle pass?)
- Exact Robux product list + pricing; engagement-based payouts
- Compliance: age rating, avoid gambling-like mechanics; accessibility; localization

**Go-to-market**
- ★ **The game NAME** (still TBD) + icon/thumbnail — the genre spreads via short-form/mobile discovery
- Trailer / clip-worthy set-pieces

## Open questions (tracked; resolve as we build)

- [ ] Solo play: is 1 player viable (auto-assist idle stations / difficulty scale), or min 2? _(leaning: playable solo, scaled)_
- [ ] The 4th role.
- [ ] Number/length of campaign zones for v1.
- [ ] Which specific animals beyond crocodiles; do they attack boat, players, or both per-type.
- [ ] Exact fail thresholds and revive rules.
- [ ] Economy: one **soft** currency vs **soft + premium (Robux)** split; currency name(s).
- [ ] Revive monetization: fully paid vs limited-free + paid; pricing / cooldown.
- [ ] Which **pre-run upgrades & skills** exist (boat stats, perks).
- [ ] Robux product list (revive packs, cosmetics, unlocks, game pass?).

## Assets needed — **Jungle's own** (the existing Meshy library is Defender's, not for Jungle)

See [Jobs/001/implementation-plan.md](Jobs/001/implementation-plan.md) for the full inventory mapped to
production phases. Broad strokes: jungle river terrain + docks, boat, crashed plane, crocodile & other
animals, low-poly flora/props, fuel/ammo pickups; systems for matchmaking/teleport, boat control,
roles, animal AI, resources, day/night, scoring; lobby + in-run HUD; and jungle/boat/animal audio.
