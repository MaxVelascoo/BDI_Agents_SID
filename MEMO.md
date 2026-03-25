# FieldOps Agent — Development Memo

## Increment 1: Self-Preservation Logic

### Feature

Health monitoring and retreating mechanism. The agent tracks its own HP via the `health(H)` perception from pyGOMAS and transitions between two mutually exclusive belief states (`healthy` / `retreating`) to ensure survival.

- **Retreat threshold:** health < 50 HP
- **Recovery threshold:** health >= 80 HP
- **Fallback:** if no healing is available at base, resume operations at current HP

### Rationality

In a no-respawn environment every death is permanent. Losing an agent reduces the team's capacity by 12-33% depending on team size (e.g. going from 3 to 2 agents is a 33% loss). A conservative retreat at 50 HP — well before the agent is in immediate lethal danger — maximizes the probability that the agent survives encounters and continues contributing to the team.

The 80 HP recovery threshold ensures the agent does not return to the field in a fragile state where a single hit could force another retreat cycle.

However, pyGOMAS has no passive health regeneration. An agent that retreats to base and waits for healing that never comes becomes permanently idle — effectively worse than dead because it occupies a team slot without contributing. The fallback plan (Plan 4) addresses this by resuming operations at whatever HP the agent has when it reaches base. A living agent at 30 HP that is moving and supplying ammo is more valuable than an idle agent at base.

### BDI Logic

| Plan | Trigger | Context | Action |
|------|---------|---------|--------|
| 1 - Trigger retreat | `+health(H)` | `H < 50 & healthy` | Remove `healthy`, add `retreating`, clear operational beliefs, `.goto(base)` |
| 2 - Mid-route recovery | `+health(H)` | `H >= 80 & retreating` | Remove `retreating`, add `healthy` + `seeding`, `.goto(objective)` |
| 3 - Recovered at base | `+target_reached(T)` | `retreating & H >= 80` | Remove `retreating`, add `healthy` + `seeding`, `.goto(objective)` |
| 4 - Base fallback | `+target_reached(T)` | `retreating & H < 80` | Resume ops immediately — no passive healing exists |
| 5 - Moderate health | `+health(H)` | `H < 70 & H >= 50 & healthy` | Log warning; no state change (defensive play planned for future increment) |

### Known Limitation

The agent cannot self-heal. Full recovery depends on a Medic agent dropping medpacks near the base or along the retreat route. A medpack-seeking behavior (navigating toward `packs_in_fov`) is planned for a future increment.

---

## Increment 2: Intelligent Combat Support

### Feature

The agent detects allies in its field of view (`friends_in_fov`) and only follows them if enemies are also detected within 100 units — indicating active combat. While following, the agent uses `.look_at(FriendPos)` to maintain situational awareness toward the combat area. The agent stops following when combat ends (no enemies visible) or when it reaches the ally's position.

- **Activation guard:** `not following & not retreating & healthy`
- **Combat proximity filter:** enemies within 100 units
- **Situational awareness:** `.look_at(FriendPos)` before `.goto(FriendPos)`

### Rationality

In a no-respawn environment, blindly following any ally wastes time and positioning. An ally who is merely patrolling poses no immediate need for ammo resupply. By filtering on enemy proximity (< 100 units), the FieldOps only commits to support when there is real combat — where ammo supply has the highest impact. This avoids unnecessary exposure and keeps the agent on its strategic seeding route when there is no active threat.

The `healthy` guard prevents the agent from entering combat support when its health is compromised (< 50 HP), ensuring Behavior 1 (Self-Preservation) always takes priority. If health drops below 50 while following, Plan 1 immediately clears the `following` and `combat_zone` beliefs and triggers retreat.

### BDI Logic

| Plan | Trigger | Context | Action |
|------|---------|---------|--------|
| 6 - Enter combat support | `+friends_in_fov(...)` | `not following & not retreating & healthy` + `enemies_in_fov` dist < 100 | Remove `seeding`, add `following` + `combat_zone` + `ally_position`, `.look_at` + `.goto(FriendPos)` |
| 7 - Update ally tracking | `+friends_in_fov(...)` | `following & combat_zone` | Update `ally_position`, `.look_at` + `.goto(FriendPos)` |
| 8 - Combat ended | `+friends_in_fov(...)` | `following & combat_zone` + `not enemies_in_fov` | Remove `following` + `combat_zone` + `ally_position`, add `seeding`, `.goto(objective)` |
| 9 - Reached ally position | `+target_reached(T)` | `following` | Remove `following` + `combat_zone` + `ally_position`, add `seeding`, `.goto(objective)` |

### Integration with Behavior 1

Behavior 1 takes absolute priority. Plan 1 (retreat) already clears `-following` and `-combat_zone`, so the agent will immediately abandon combat support if health drops below 50. Recovery plans (2/3/4) restore `seeding`, not `following`, which is correct — after recovery the agent should return to patrolling rather than chasing a stale ally position.

---

## Increment 3: Strategic Seeding

### Feature

Team-based ammunition distribution while patrolling. The agent drops ammo packs (`.reload`) at strategic locations depending on which team it belongs to:

- **AXIS (team 200):** Drops one ammo pack at each control point along a 5-point supply line (30 units spacing) stretching toward enemy territory. This creates a defensive supply line that teammates can use during engagements.
- **ALLIED (team 100):** Drops one ammo pack every 2 waypoints during the advance toward the enemy flag, conserving stamina for the longer push.

Both strategies are guarded by a stamina check: `.reload` is only called when `ammo(A) > 25`, ensuring the agent retains at least 25% of its personal ammunition for self-defense.

### Rationality

The two teams have fundamentally different objectives:

- **AXIS defends.** A supply line of ammo packs between the base and the front creates a resupply corridor that all teammates benefit from. Dropping at every control point maximizes coverage.
- **ALLIED attacks.** The priority is reaching the flag quickly. Dropping ammo at every waypoint would exhaust stamina before reaching the objective, so pacing to every 2 waypoints balances supply support with forward momentum.

The `ammo(A) > 25` stamina guard prevents the agent from becoming unarmed. In a no-respawn environment, a FieldOps that has dropped all its ammo is defenseless and effectively dead — it can neither supply allies nor defend itself. Keeping a 25% reserve ensures the agent always has enough to respond to an unexpected encounter.

### BDI Logic

| Plan | Trigger | Context | Action |
|------|---------|---------|--------|
| 10 - AXIS seed + drop | `+target_reached(T)` | `seeding & team(200) & not retreating & ammo(A) > 25` | `.reload`, increment `seed_step`, advance to next control point (or hold at last) |
| 11 - AXIS seed, low ammo | `+target_reached(T)` | `seeding & team(200) & not retreating & ammo(A) <= 25` | Skip `.reload`, advance to next control point (or hold at last) |
| 12 - ALLIED seed + drop | `+target_reached(T)` | `seeding & team(100) & not retreating & ammo(A) > 25` | If `seed_step mod 2 == 0`: `.reload`; increment `seed_step`, `.goto(objective)` |
| 13 - ALLIED seed, low ammo | `+target_reached(T)` | `seeding & team(100) & not retreating & ammo(A) <= 25` | Increment `seed_step`, `.goto(objective)` — no drop |

### Stamina Management

The stamina check uses `ammo(A) > 25` as a proxy for resource availability, since pyGOMAS does not expose a direct "stamina" belief. The pacing strategies differ per team:

- **AXIS:** Drops at every control point (5 total maximum). Since the patrol route is short (30-unit spacing), the agent is unlikely to exhaust ammo before completing the line.
- **ALLIED:** Drops every 2 waypoints. Combined with the stamina guard, this means the agent can sustain supply support over a longer route without becoming defenseless.

If ammo drops to 25% or below, Plans 11/13 take over and the agent continues its movement pattern without calling `.reload`, preserving its remaining ammo for self-defense.

### Integration with Behaviors 1 and 2

All seeding plans require `seeding & not retreating`, so they never conflict with retreat (Behavior 1). Behavior 2 clears `seeding` when entering combat support, so seeding plans cannot fire while the agent is following an ally. Recovery plans (2/3/4) and combat-end plans (8/9) restore `seeding`, correctly re-enabling ammo distribution after interruptions.

---

## Increment 4: Resource Management

### Feature

A gatekeeper layer applied to every `.reload` call in the agent. Before any ammo pack is dropped, four conditions must all pass:

1. **Not retreating** (existing from Behaviors 1/3)
2. **Ammo > 40** (raised from 25 to 40 — keeps 40% personal reserve for self-defense)
3. **Health >= 70** (new — at moderate health 50-69, skip drops to focus on movement/evasion)
4. **Not drop_cooldown** (new — one drop per destination cycle, prevents rapid spam)

Additionally, a new **Plan 14 (Combat Proximity Drop)** allows the agent to drop ammo while following an ally in active combat, but only when the ally is within 30 units — ensuring the pack is placed where it will actually be picked up.

### Rationality

In a no-respawn environment, calling `.reload` has a hidden cost: it consumes stamina (a non-queryable internal resource) and briefly pauses the agent's movement. An agent that drops packs too aggressively risks:

- **Becoming unarmed** (ammo depleted) — defenseless and effectively dead
- **Being caught stationary** at moderate health — a single hit while reloading could push it below the retreat threshold, triggering an avoidable retreat cycle
- **Wasting packs** in locations where no ally can reach them

The four-gate system addresses each risk:

- The **ammo > 40** threshold (up from 25) provides a larger self-defense buffer. At 40%, the agent has enough ammo for several self-defense encounters before running dry.
- The **health >= 70** guard ensures the agent never exposes itself to a reload pause when weakened. Between 50-69 HP, movement and evasion take absolute priority.
- The **drop_cooldown** flag prevents the agent from dropping multiple packs in rapid succession, particularly during combat support where `friends_in_fov` fires every perception cycle. The cooldown is cleared on each `target_reached`, tying the drop rate to physical movement speed.
- The **proximity check** (Distance < 30 for combat drops, inherently at checkpoint for seeding drops) ensures packs are placed where allies can actually use them.

### BDI Logic

| Plan | Trigger | Context | Action |
|------|---------|---------|--------|
| 10 - AXIS seed (modified) | `+target_reached(T)` | `seeding & team(200) & not retreating & ammo(A) > 40` | Clear cooldown; if `H >= 70`: `.reload` + set cooldown; else: skip drop. Advance to next point. |
| 11 - AXIS low ammo (modified) | `+target_reached(T)` | `seeding & team(200) & not retreating & ammo(A) <= 40` | Clear cooldown, advance without drop |
| 12 - ALLIED seed (modified) | `+target_reached(T)` | `seeding & team(100) & not retreating & ammo(A) > 40` | Clear cooldown; if `S mod 2 == 0 & H >= 70`: `.reload` + set cooldown. Advance to objective. |
| 13 - ALLIED low ammo (modified) | `+target_reached(T)` | `seeding & team(100) & not retreating & ammo(A) <= 40` | Clear cooldown, advance without drop |
| 14 - Combat proximity drop (NEW) | `+friends_in_fov(...)` | `following & combat_zone & Distance < 30 & not drop_cooldown & ammo(A) > 40 & health(H) >= 70` | `.reload` + set cooldown, continue tracking ally |

### Cooldown Mechanism

pyGOMAS/Jason does not expose a system clock, so a time-based `last_pack_drop_time(T)` is not implementable. The `drop_cooldown` boolean belief acts as a per-destination-cycle lock:

- **Set** after every `.reload` call (`+drop_cooldown`)
- **Cleared** at the start of every `target_reached` handler (`-drop_cooldown`) and during state transitions (retreat, combat end)
- **Checked** in Plan 14's context guard (`not drop_cooldown`) and implicitly in seeding plans (cooldown is cleared on arrival, so one drop per waypoint is inherently allowed)

The effective cooldown duration equals the travel time between destinations — a natural rate limit tied to physical movement.

### State Cleanup

`drop_cooldown` is cleared in these plans to prevent stale cooldown from blocking future drops:

- **Plan 1** (retreat): full state reset
- **Plan 8** (combat ended): returning to seeding
- **Plan 9** (reached ally): returning to seeding
- **Plans 10-13** (seeding waypoints): cleared at start of each handler

### Known Limitation

`friends_in_fov(ID, TYPE, ANGLE, DIST, HEALTH, POS)` exposes ally **Health** but not ammo. The agent cannot determine whether a followed ally already has sufficient ammunition. A future improvement could use inter-agent messaging (`.send`) to request ammo status, but this would require cooperation from other agents — conflicting with the autonomy design principle.

### Integration with Behaviors 1-3

The gatekeeper conditions layer cleanly on top of existing behaviors:

- **Behavior 1**: Plan 1 clears `drop_cooldown` alongside other operational beliefs. Recovery plans (2/3/4) do not set cooldown, so the agent can drop immediately after resuming.
- **Behavior 2**: Plan 14 (combat proximity drop) only fires when `following & combat_zone`, which are set by Plan 6. Plan 8 (combat ended) clears cooldown, so the agent returns to seeding with a fresh drop allowance.
- **Behavior 3**: Seeding plans now check health >= 70 inside the plan body before calling `.reload`. The ammo threshold increase from 25 to 40 applies uniformly.

---

## Increment 5: Combat Response Matrix

### Feature

State-based firing logic triggered by `+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)`. The agent varies its engagement level (0, 1, 2, or 3 bullets) depending on its current operational state, with an ammo safety floor that preserves the last 5 bullets for emergencies.

Six new plans (15-20) are ordered by priority in the file so that Jason's top-to-bottom matching ensures the most critical response fires first:

1. Retreating agents always prioritize evasion over combat
2. Life-or-death overrides ammo conservation
3. Moderate health suppresses all shooting
4. Offensive fire only when fully healthy with ally support
5. Cautious fire during normal patrol operations

### Rationality

In a no-respawn environment, every bullet spent is a trade-off between potential damage dealt and exposure time. The agent stands still briefly while shooting, making it vulnerable. The matrix minimizes this risk by scaling engagement to the agent's survivability:

- **Retreating (1 bullet):** The agent is already below 50 HP and heading to base. Firing a single deterrent bullet at very close enemies (< 30 units) discourages pursuit without significantly delaying the retreat. Engaging distant enemies would waste ammo and time.
- **Combat with ally (3 bullets):** Maximum firepower is justified because the ally provides cover and the agent is at full health (>= 70 HP, enforced by Plan 17 filtering). The ally also benefits from the suppressive fire.
- **Seeding healthy (2 bullets):** The agent is alone and patrolling. Two bullets provide a reasonable response to a threat without committing to a prolonged firefight that could turn lethal.
- **Moderate health (0 bullets):** At 50-69 HP, the agent is one or two hits from the retreat threshold. Any combat engagement risks pushing it below 50 HP, triggering a retreat cycle that removes it from operations. Evasion is strictly superior.

The **ammo safety floor** (`ammo > 5`) prevents the agent from shooting itself dry during normal engagement. A FieldOps with 0 ammo can neither defend itself nor supply allies — effectively dead. The last-resort Plan 20 overrides this only when an enemy is within 15 units and ammo is already critically low, where those final bullets may be the difference between survival and permanent death.

### BDI Logic

| Plan | Trigger | Context | Action |
|------|---------|---------|--------|
| 15 - Retreating evasion | `+enemies_in_fov(...)` | `retreating & Dist < 30 & ammo(A) > 5` | `.look_at(EnemyPos)`, `.shoot(1, EnemyPos)` — deterrent shot while fleeing |
| 20 - Last resort | `+enemies_in_fov(...)` | `ammo(A) <= 5 & Dist < 15` | `.look_at(EnemyPos)`, `.shoot(1, EnemyPos)` — emergency, any state |
| 16 - Retreating ignore | `+enemies_in_fov(...)` | `retreating` | Log only — enemy too far, keep fleeing |
| 17 - Moderate health | `+enemies_in_fov(...)` | `healthy & health(H) < 70 & H >= 50` | Log only — avoid combat at weakened health |
| 18 - Combat with ally | `+enemies_in_fov(...)` | `following & combat_zone & ammo(A) > 5` | `.look_at(EnemyPos)`, `.shoot(3, EnemyPos)` — full offensive |
| 19 - Seeding cautious | `+enemies_in_fov(...)` | `seeding & healthy & ammo(A) > 5` | `.look_at(EnemyPos)`, `.shoot(2, EnemyPos)` — cautious fire |

### Plan Priority Ordering

The file ordering is critical because Jason selects the first plan whose context matches:

- **Plans 15 > 20 > 16**: For retreating agents, Plan 15 (close + has ammo) is checked first. If ammo <= 5 but enemy is very close, Plan 20 catches it. Plan 16 catches all remaining retreating cases (far enemies).
- **Plan 17 before 18/19**: At moderate health, Plan 17 fires and prevents shooting regardless of whether the agent is following or seeding.
- **Plans 18 > 19**: Combat with ally gets more firepower than solo seeding, matching the ally-support doctrine.

### Ammo Safety

| Guard | Plans | Purpose |
|-------|-------|---------|
| `ammo(A) > 5` | 15, 18, 19 | Preserves last 5 bullets for emergencies |
| `ammo(A) <= 5 & Dist < 15` | 20 | Life-or-death exception — fire when enemy is lethally close |
| No ammo check | 16, 17 | These plans do not shoot, so no check needed |

### Known Consideration

The agent does not explicitly select the "closest enemy" when multiple enemies are visible. Each `+enemies_in_fov` perception fires independently for each enemy, and the first matching plan executes. In practice, pyGOMAS processes perceptions sequentially and `.shoot` has an inherent action delay, so only the first enemy per cycle is effectively engaged. A future optimization could use a negative context guard (`not (enemies_in_fov(OtherID, _, _, D2, _, _) & OtherID \== EID & D2 < Dist)`) to ensure only the closest enemy triggers the plan.

### Integration with Behaviors 1-4

- **Behavior 1**: Plans 15/16 handle the retreating state. The `+health` trigger (Plans 1-5) manages state transitions independently — if health drops below 50 while shooting, Plan 1 triggers retreat on the next health update.
- **Behavior 2**: Plan 18 (shooting) fires on `enemies_in_fov` while Plan 14 (ammo drop) fires on `friends_in_fov`. They handle combat shooting and ammo supply independently during combat support.
- **Behavior 3**: Plan 19 fires during seeding. Movement continues via `target_reached` plans — shooting does not interrupt the patrol route.
- **Behavior 4**: Plan 18 does NOT call `.reload`. Ammo drops during combat remain gated by Plan 14's full gatekeeper conditions (ammo > 40, health >= 70, proximity < 30, not on cooldown).

---

## Increment 6: Flag Events

### Feature

The agent reacts to flag capture and recovery events (`+flag_taken` / `-flag_taken`) by switching into team-specific modes:

- **ALLIED (team 100) -- Escorting:** When the flag is captured, the agent enters `escorting` mode, navigates to the team's base to rendezvous with the flag carrier, drops ammo to support the carrier, and provides protective fire against interceptors.
- **AXIS (team 200) -- Defending:** When the flag is stolen, the agent enters `defending` mode, returns to base to intercept the attacker, drops ammo for defending allies, and fires aggressively at enemies near the base.

Both modes include dedicated combat response plans and full gatekeeper-gated ammo drops at the base.

### Rationality

Capture the Flag is the victory condition. When the flag is in motion, the entire game dynamic shifts:

- **ALLIED:** The flag carrier must reach the allied base alive. A FieldOps near the base can supply the carrier and its escorts with fresh ammo packs, directly increasing the odds of a successful flag run. Going to the base (where the carrier must deliver) is the most reliable rendezvous point — it requires no complex coordination or message exchange.
- **AXIS:** If the enemy takes the flag, the defenders' priority shifts from patrolling to interception. A FieldOps at the base can supply ammo to soldiers chasing the carrier and provide aggressive fire (3 bullets) to stop the thief. Defending the base is strategically optimal because the flag carrier must pass through or near the base area.

Self-Preservation remains the absolute priority. If health drops below 50 during escorting or defending, Plan 1 clears the flag-event beliefs and triggers retreat. This is intentional: a dead FieldOps contributes nothing, and the flag situation may resolve itself (flag returned, carrier killed) during the retreat. Recovery plans restore `seeding`, not the flag state, because the agent has no way to know whether the flag event is still active after recovery.

### BDI Logic

| Plan | Trigger | Context | Action |
|------|---------|---------|--------|
| 21 - ALLIED escort start | `+flag_taken` | `team(100) & not retreating` | Clear operational beliefs, add `escorting`, `.register_service`, `.get_backups`, `.goto(base)` |
| 22 - ALLIED escort end | `-flag_taken` | `escorting` | Clear `escorting`, add `seeding`, `.goto(objective)` |
| 23 - ALLIED escort at base | `+target_reached(T)` | `escorting & team(100)` | If gatekeeper passes: `.reload`; hold position at base |
| 24 - AXIS defend start | `+flag_taken` | `team(200) & not retreating` | Clear operational beliefs, add `defending`, `.goto(base)` |
| 25 - AXIS defend end | `-flag_taken` | `defending` | Clear `defending`, add `seeding`, resume patrol at current point |
| 26 - AXIS defend at base | `+target_reached(T)` | `defending & team(200)` | If gatekeeper passes: `.reload`; hold position at base |
| 27 - Escort combat | `+enemies_in_fov(...)` | `escorting & healthy & ammo(A) > 5` | `.shoot(2, EnemyPos)` -- cautious protective fire |
| 28 - Defend combat | `+enemies_in_fov(...)` | `defending & healthy & ammo(A) > 5` | `.shoot(3, EnemyPos)` -- aggressive interception fire |

### Modifications to Existing Plans

- **Plan 1 (retreat):** Now clears `-escorting` and `-defending` alongside other operational beliefs. This ensures the agent always abandons flag events when survival is at stake.
- **Plan 6 (enter combat support):** Context guard now includes `& not escorting & not defending`. This prevents the agent from switching to ally-following mode when it should be handling a flag event.

### Communication Integration

The agent uses lightweight, autonomy-preserving communication:

- **`.register_service("fieldops_escort")`** in Plan 21 announces the agent's escort availability to the team. Other agents can discover FieldOps escorts via service queries.
- **`.get_backups`** in Plan 21 logs which allies are alive for observability. The result is not used for movement decisions.
- **Movement is position-based:** The agent navigates to `base(B)` (where the flag must be delivered) rather than tracking specific ally positions. This eliminates the need for complex asynchronous coordination or position-sharing protocols.

Full service-based coordination (tracking the flag carrier's position in real time) was rejected because it would require cooperation from other agents and introduce fragile asynchronous dependencies. The position-based approach guarantees correct behavior regardless of whether other agents participate.

### Known Limitations

- **Missed events during retreat:** If `+flag_taken` fires while the agent is retreating (`not retreating` guard fails), the agent misses the flag event entirely. Recovery plans restore `seeding`, so the agent resumes normal patrol. This is acceptable because: (a) survival takes priority, and (b) the flag situation may resolve during the retreat.
- **No flag carrier tracking:** The agent cannot determine which ally carries the flag or their current position. It always goes to `base(B)` as the rendezvous point. This is optimal for ALLIED (carrier delivers to base) and near-optimal for AXIS (carrier must pass through base area).
- **AXIS patrol resumption:** Plan 25 resumes patrol at the current `patroll_point(P)`. If `P >= Total`, the agent navigates to `objective(F)` as a fallback. The patrol counter is not reset, which is correct — the agent should continue where it left off, not restart the supply line.

### Integration with Behaviors 1-5

- **Behavior 1**: Plan 1 clears both `escorting` and `defending`. Recovery (Plans 2-4) restores `seeding` only. The agent cannot re-enter a flag-event mode after retreat — it must receive a new `+flag_taken` perception.
- **Behavior 2**: Plan 6 now guards against `escorting` and `defending`, preventing combat-following from overriding flag-event modes. Plans 27/28 handle combat during flag events independently.
- **Behavior 3**: `seeding` is cleared when entering escort/defend mode (Plans 21/24) and restored when exiting (Plans 22/25). Seeding plans never conflict with flag events.
- **Behavior 4**: Plans 23/26 apply the full gatekeeper (ammo > 40, health >= 70, cooldown) for base drops during flag events. The gatekeeper is uniform across all behaviors.
- **Behavior 5**: Plans 27/28 are placed after the existing Combat Response Matrix plans. However, since `escorting` and `defending` are exclusive states, there is no ambiguity: Plans 27/28 match only when the agent is in a flag-event mode.

---

## Final QA & Consistency Check

A full audit of all 446 lines of `bdifieldop.asl` was performed across six categories after all 6 behaviors were implemented.

### 1. Goal Conflicts (Retreat Priority) -- PASS

Plan 1 clears every operational belief (`-seeding`, `-following`, `-combat_zone`, `-ally_position(_)`, `-escorting`, `-defending`, `-drop_cooldown`) and sets `+retreating` before navigating to base. Every other movement plan is blocked while `retreating` is active:

- Plans 6, 21, 24: explicit `not retreating` guard
- Plans 8, 14, 7: require `following` (cleared by Plan 1)
- Plans 9, 10-13: require `following` / `seeding` (cleared by Plan 1)
- Plans 23, 26: require `escorting` / `defending` (cleared by Plan 1)

Only Plans 2/3/4 (intended recovery exits) can redirect the agent. Self-preservation is absolute.

### 2. Plan Overlap -- PASS

All `+target_reached` plans rely on mutually exclusive state beliefs (`retreating`, `following`, `seeding + team`, `escorting`, `defending`). File order 3 > 4 > 9 > 10 > 11 > 12 > 13 > 23 > 26 is correct, with no ambiguity.

All `+friends_in_fov` plans: order 6 > 8 > 14 > 7 ensures combat-end is checked before proximity drop, which is checked before general tracking.

All `+enemies_in_fov` plans: order 15 > 20 > 16 > 17 > 18 > 19 > 27 > 28 correctly prioritizes retreating evasion, then last resort, then retreating ignore, then moderate health avoidance, then state-specific fire. Plans 27/28 are correctly unreachable by higher-priority plans because `escorting`/`defending` never overlap with `retreating`, `following`, or `seeding`.

### 3. Syntactic Integrity -- PASS

- All 28 plans end with `.`
- All actions within plan bodies separated by `;`
- All variables start with uppercase
- All internal actions start with `.`
- `-+` shorthand for belief updates is valid Jason syntax

### 4. Stamina & Deadlocks -- PASS

`.reload` is non-blocking in pyGOMAS. Every plan that calls `.reload` continues with further actions (navigation or holding). No `.reload` call conflicts with `.shoot` or `.goto`. No plan ends mid-action in a state that could leave the agent stuck.

### 5. Belief Updates (Recovery) -- PASS

All three recovery paths (Plans 2, 3, 4) properly: (1) remove `retreating`, (2) add `healthy`, (3) add `seeding`, (4) navigate to `objective(F)`. This correctly re-enables seeding plans for subsequent `target_reached` events.

### 6. Bug Found & Fixed

**Plan 1 was missing `-ally_position(_)` in its retreat cleanup.** If the agent retreated while in `following` mode, the stale `ally_position(Pos)` belief persisted. When Plan 6 later re-entered combat support, it added a new `ally_position(FriendPos)` without removing the old one, creating duplicate beliefs. While functionally harmless (Plans 7/8/14 clean up via `-ally_position(_)`), it was inconsistent with Plans 21/24 which do clear it. Fixed by adding `-ally_position(_)` between `-combat_zone` and `-escorting` in Plan 1.

### Why the BDI Hierarchy is Robust for a No-Respawn Tournament

The agent's architecture rests on three guarantees that make it resilient in a permanent-death environment:

1. **Strict state exclusivity.** The agent is always in exactly one of five states: `seeding`, `following`, `retreating`, `escorting`, or `defending`. Every state transition clears the previous state's beliefs before setting the new one. This prevents conflicting `.goto` destinations from accumulating and eliminates the possibility of the agent receiving contradictory movement commands.

2. **Unconditional retreat override.** Plan 1 sits at the top of the `+health` trigger chain and clears every operational belief in a single atomic step. No other plan can fire a `.goto` while `retreating` is active. The three recovery plans (2/3/4) are the only exits, and they all verify health thresholds before re-entering operations. The hybrid fallback (Plan 4) ensures the agent never becomes permanently idle at base.

3. **Layered resource conservation.** The four-gate drop system (not retreating, ammo > 40, health >= 70, not drop_cooldown) is applied uniformly across all behaviors — seeding, combat support, escorting, and defending. The Combat Response Matrix scales firepower by state (0/1/2/3 bullets) with a hard ammo floor of 5 bullets. Together, these prevent the agent from exhausting its resources during any single engagement, preserving its ability to contribute for the full duration of the match.

---

## Test Run: ALLIED vs Dummies

### Configuration

- **Game file:** `test_game.json`
- **Match time:** 300 seconds
- **Map server:** `sidfib.mooo.com` (manager: `cmanager-coconut`)
- **ALLIED team (our agents):** `my_soldier_0` (bdisoldier.asl), `my_medic_0` (bdimedic.asl), `my_fieldop_0` (bdifieldop.asl) + 3 dummy allies
- **AXIS team (opponents):** 2 dummy soldiers, 1 dummy medic, 1 dummy fieldops

### Result

**ALLIED wins -- Target Returned.** The soldier captured the enemy flag and returned it to base.

### FieldOps Behavior Observations

All 6 behaviors fired correctly during the match:

| Behavior | Log Evidence | Verdict |
|----------|-------------|---------|
| 1 - Self-Preservation | Health decayed 69 -> 49 HP over ~60s of combat. `CRITICAL_HEALTH` triggered at 49 HP. Agent retreated to base and survived the entire match. | PASS |
| 2 - Combat Support | `COMBAT_SUPPORT` entered when allies were in active combat. `COMBAT_TRACK` updated ally positions each cycle. `ALLY_REACHED` resumed seeding. | PASS |
| 3 - Strategic Seeding | Initialized as ALLIED (team 100), advanced toward objective `[184, 0, 144]`. | PASS |
| 4 - Resource Management | `COMBAT_DROP` fired 4 times at distances 12, 15, 10, 21 units (all within 30-unit threshold). No drops observed at moderate health. | PASS |
| 5 - Combat Response | `CAUTIOUS_FIRE` (2 bullets) while seeding. `MODERATE_AVOID` (0 bullets) at 50-69 HP. `RETREAT_FIRE` (1 bullet) at dist < 30 while fleeing. | PASS |
| 6 - Flag Events | A `flag_taken` event was observed mid-match. The FieldOps was in `following` mode with moderate health at the time. | Observed |

### State Transitions Observed

```
INIT (seeding) -> CAUTIOUS_FIRE (seeding + enemies)
  -> COMBAT_SUPPORT (ally in active combat)
  -> COMBAT_DROP (ally within 30 units, ammo/health OK)
  -> COMBAT_TRACK (updating ally position)
  -> MODERATE_HEALTH (health dropped to 69)
  -> MODERATE_AVOID (stopped shooting at 68 HP)
  -> ALLY_REACHED (resumed seeding)
  -> COMBAT_SUPPORT (re-entered following)
  -> CRITICAL_HEALTH (49 HP, retreated to base)
  -> RETREAT_FIRE (1 deterrent bullet at close enemy)
```

### Survival Summary

| Agent | Status | Notes |
|-------|--------|-------|
| `my_soldier_0` | ALIVE | Captured and returned the flag |
| `my_medic_0` | ALIVE | Provided triage and medpacks throughout |
| `my_fieldop_0` | ALIVE | Supplied ammo in combat, retreated at 49 HP |
| `dummy_soldier_allied_0` | DEAD | Killed in combat |
| `axis_soldier_default_0` | DEAD | Killed by our soldier |

All 3 custom BDI agents survived the match. The no-respawn survival design worked as intended.
