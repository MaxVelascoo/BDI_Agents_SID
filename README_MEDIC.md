# MEDIC AGENT DOCUMENTATION - SID 2026

## General Overview

The Medic agent is a tactical support role specialized in **health sustain, triage, and survival preservation**. It is designed to operate autonomously in mixed multi-agent teams, where allies may belong to other groups and cannot be assumed to cooperate explicitly.

## Design Philosophy

Unlike simpler medic implementations that only drop medpacks while advancing, this Medic is optimized for:

- **Full autonomy**: does not require explicit communication with allies
- **Battlefield triage**: prioritizes nearby wounded allies over blind path-following
- **Survival-first play**: with no respawn, the medic must stay alive as long as possible
- **Stable behavior**: avoids getting trapped in incoherent state transitions
- **Useful healing**: drops medpacks at meaningful moments instead of wasting stamina

## CRITICAL RULE: NO RESPAWN

This agent is designed under the assumption that **there is no respawn**. Therefore:

- Every death is permanent and weakens the team
- A dead medic means losing future healing capacity for the whole team
- Preserving support roles is strategically valuable in long matches
- Retreating early is rational, not passive

## Main Behaviors

### 1. Self-Preservation - MAXIMUM PRIORITY

**The Medic must stay alive to keep generating value for the team.**

The agent constantly monitors its own health and reacts as follows:

```
Health < 45  → Retreat immediately to base
Health ≥ 80  → Resume operations
45 ≤ Health < 70 → Play defensively
```

**Why this matters:**
- The practice is evaluated in random matches with no respawn, random maps, and random teammates, so survival and consistency are more valuable than risky aggression.
- The rubric explicitly rewards agents that function correctly, behave coherently, and follow a rational design. The retreat logic directly supports that goal. fileciteturn1file7 fileciteturn1file8

**Implementation idea:**
```asl
+health(H): H < 45 & healthy
  <-
  -healthy;
  +retreating;
  ?base(B);
  .goto(B).
```

**Behavior during retreat:**
- Do not commit to combat
- Only shoot 1 bullet if an enemy is extremely close
- Prioritize reaching base and recovering

### 2. Triage Support

**Previous weak approach:** moving forward and dropping medpacks on a fixed route regardless of nearby allies.

**Improved version:** the Medic dynamically prioritizes allies based on urgency.

**Triage priorities:**
- **Urgent ally:** health < 45 and close enough → immediate support
- **Combat ally:** health < 60 and enemies nearby → follow and assist
- **Recovered ally:** if the ally reaches a safe HP threshold, return to patrol

**Advantages:**
- Healing is directed to allies who actually need it
- The medic behaves more like a support specialist and less like a passive waypoint bot
- It improves team sustain in skirmishes without depending on explicit coordination

**Implementation idea:**
```asl
+friends_in_fov(FriendID, Type, Angle, Distance, FriendHealth, FriendPos)
  : seeding & not retreating & healthy & FriendHealth < 60
    & enemies_in_fov(_, _, _, EnemyDist, _, _) & EnemyDist < 100
  <-
  -seeding;
  +following;
  +combat_zone;
  +ally_position(FriendPos);
  +ally_health(FriendHealth);
  .goto(FriendPos).
```

### 3. Structured Seeding

The original code advanced differently for each team and, on Allied, could end up repeatedly going to the same objective position. The improved design uses **control points for both teams**, giving the medic a predictable and stable route.

#### Team AXIS (Defense - Team 200)

- Creates 5 control points toward the contested area
- Advances along them one by one
- Once it reaches the last point, it holds that advanced position instead of restarting from base

**Advantages:**
- Maintains a forward defensive presence
- Leaves healing resources along the lane
- Avoids erratic movement loops

#### Team ALLIED (Attack - Team 100)

- Creates 4 intermediate control points toward the objective
- Progresses along the attack route in an ordered way
- Once it reaches the last point, it stays near the objective corridor instead of re-issuing pointless `.goto(flag)` orders

**Advantages:**
- Avoids the “stand on the flag and keep retriggering” issue
- Builds a support lane for attackers
- Makes Allied behavior easier to interpret and debug

### 4. Conservative Medpack Placement

The Medic can create medpacks, so the critical question is **when** to do it.

**The improved agent drops medpacks mainly in three situations:**
- At strategic patrol points
- When it reaches a wounded ally
- During escort/defense situations around the base

**It avoids dropping medpacks:**
- On every enemy sighting
- While retreating
- In low-value movement states with no ally nearby

**Advantages:**
- Better stamina usage
- Less wasted support
- Healing appears where allies are more likely to benefit

**Implementation idea:**
```asl
if (S mod 2 == 0) {
  .cure;
}
```

### 5. Combat Response Matrix

The Medic is **not** a frontline duelist. Its combat response depends on context:

| State | Action | Bullets | Drops Medpack |
|--------|--------|---------|---------------|
| Retreating | Evasion | 1 if enemy is very close | No |
| Following wounded ally | Support fire | 2 | Yes, if needed |
| Seeding and healthy | Defensive fire | 2 | Only at control points |
| Moderate health | Avoid prolonged combat | 0-1 | No |

**Rationale:**
- The medic’s role in pyGOMAS is to create health packs, not to maximize kills. fileciteturn1file0
- Short engagements reduce exposure and keep the medic alive longer
- A living medic can recover team HP repeatedly; a dead medic contributes nothing

### 6. Stable State Transitions

One of the biggest practical risks in AgentSpeak agents is getting stuck in inconsistent beliefs such as following + retreating, or escorting + seeding at the same time.

The improved logic explicitly clears incompatible states when switching mode:

- Retreat cancels seeding, following, escorting, and defending
- Escort/defense events clear triage beliefs
- Reaching a followed ally always resolves the follow state cleanly

**Advantages:**
- More predictable execution
- Easier debugging
- Better compliance with the rubric requirement that the agent should not behave erratically. fileciteturn1file8

### 7. Response to Flag Events

#### ALLIED (when the flag is taken)

**Improved behavior:**
- Stops normal seeding
- Enters escort mode
- Returns toward base to support the carrier’s return path
- Drops a medpack on arrival to reinforce the area

#### AXIS (when the flag is taken)

**Improved behavior:**
- Stops lane patrol
- Enters defense mode
- Returns to base
- Drops a medpack in the defensive area

**Advantages:**
- The medic becomes useful in the most critical moments of the match
- It supports both chase-defense and capture-return scenarios
- Behavior is aligned with the team objective: Allied must capture, Axis must prevent capture. fileciteturn1file0

## Comparison: Before vs After

### Before (Original Version)

```
Advantages:
+ Included retreat logic
+ Tried to support wounded allies
+ Had team-dependent behavior

Disadvantages:
- Allied route could collapse into repeated direct goto to the flag
- Several target_reached plans overlapped and made behavior fragile
- Healing could trigger too often in combat
- State cleanup was incomplete
- last_pack_drop_time was tracked but not really used
- Following logic could become inconsistent
```

### After (Improved Version)

```
Advantages:
+ More stable finite-state behavior
+ Better triage priorities
+ Cleaner retreat and recovery transitions
+ Structured patrol for both teams
+ More efficient medpack placement
+ Better response to random teammates and maps
+ Easier to justify in the report as a rational role policy

Disadvantages:
- More logic branches to test
- Slightly more conservative than an aggressive medic
- Still limited by visibility and lack of explicit ally communication
```

## Impact of No-Respawn on Strategy

### Key changes introduced

1. **Retreat threshold tightened to 45 HP**
   - The medic should not gamble its survival once damaged.

2. **Recovery threshold set to 80 HP**
   - Re-entering combat too early would make the support role disappear quickly.

3. **Reduced combat commitment**
   - The medic only uses short defensive bursts instead of prolonged exchanges.

4. **Healing tied to tactical contexts**
   - Patrol points, ally support, escort, and defense are prioritized over random drops.

5. **Control-point route for both teams**
   - Prevents unstable behavior and makes actions easier to interpret.

## Agent States (ASL)

The agent is organized around these mutually exclusive or carefully managed modes:

1. **seeding** - progressing through strategic control points
2. **following** - supporting a wounded ally
3. **retreating** - returning to base to survive
4. **escorting** - supporting the flag-return phase on Allied
5. **defending** - reinforcing the base when Axis is under pressure
6. **combat_zone** - auxiliary belief indicating that the current support is linked to combat

## pyGOMAS Technical Reference

The practice states that the Medic role can create health packs, while the FieldOps provides ammunition. The global objective is still to help the team win under random maps, random team sizes, and mixed-group matches. fileciteturn1file0 fileciteturn1file7

### Beliefs used by the Medic

```asl
+objective(F)
+control_points(C)
+total_control_points(L)
+patroll_point(P)
+seed_step(S)
+healthy
+retreating
+following
+escorting
+defending
+combat_zone
+ally_position(Pos)
+ally_health(H)
```

### Relevant built-in perceptions

- `team(X)`
- `base([X,Y,Z])`
- `flag([X,Y,Z])`
- `health(X)`
- `ammo(X)`
- `friends_in_fov(...)`
- `enemies_in_fov(...)`
- `target_reached([X,Y,Z])`
- `flag_taken`

### Actions used

```asl
.goto([X,Y,Z])
.shoot(N, [X,Y,Z])
.cure
.create_control_points([X,Y,Z], D, N, C)
.nth(Index, List, Element)
.length(List, L)
```

## Optimizations for Competitive Evaluation

Given the evaluation conditions of the practice:

- random maps
- random number of agents (3 to 8)
- random roles with at least one of each
- mixed teams composed of agents from different groups
- 5-minute time limit

this Medic is optimized for:

1. **Autonomy** - assumes no ally coordination
2. **Consistency** - avoids erratic loops and unstable states
3. **Survival** - keeps the healer alive longer
4. **Support value** - heals where it matters most
5. **Robustness** - behaves reasonably across many map/team combinations

These conditions come directly from the practice statement and are central to the design rationale. fileciteturn1file0 fileciteturn1file7

## Expected Performance Impact

Compared to the original version, the improved agent should provide:

- **Higher survivability** because retreat and re-entry are clearer
- **Better support quality** because triage is priority-based
- **Lower behavioral instability** because state transitions are cleaned up
- **More interpretable movement** thanks to patrol control points on both teams
- **Less wasted healing** because medpacks are dropped in tactical contexts

**Most important metric:** keeping the medic alive while still sustaining nearby allies.

## Evaluation Goal

The goal is not to maximize kills, but to maximize **team survival and match-winning support**. This is aligned with the practice statement: agents should behave rationally for their role and help their team win. fileciteturn1file9

## Possible Future Improvements

1. Prioritize the lowest-health ally among multiple visible allies
2. Distinguish between safe healing and healing under enemy pressure
3. Predict when to abandon an ally if support would be suicidal
4. Use communication to coordinate with soldiers or FieldOps from the same group
5. Detect friendly medpacks already on the ground before creating a new one
6. Adjust retreat thresholds dynamically depending on remaining time or team size

## Conclusion

This Medic is designed for a **no-respawn**, **mixed-team**, **randomized** pyGOMAS environment. The strategy emphasizes:

1. survival before risky aggression,
2. triage instead of blind healing,
3. stable state transitions,
4. useful medpack placement, and
5. interpretable behavior that can be justified as rational in the final documentation.

It is therefore better aligned with the practical requirements of the assignment and easier to defend in the report.
