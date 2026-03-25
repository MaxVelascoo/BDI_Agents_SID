// ============================================================
// BDI FIELDOPS AGENT — Incremental Step 6: Flag Events
// ============================================================
// Implemented:
//   Behavior 1: Self-Preservation (health monitoring + retreat)
//   Behavior 2: Intelligent Combat Support (ally following in active combat)
//   Behavior 3: Strategic Seeding (team-based ammo distribution)
//   Behavior 4: Resource Management (drop gatekeeper + cooldown)
//   Behavior 5: Combat Response Matrix (state-based firing logic)
//   Behavior 6: Flag Events (escorting + defending)
//
// All 6 behaviors implemented.
// ============================================================

// ----------------------------------------------------------
// INITIALIZATION
// ----------------------------------------------------------

// TEAM_AXIS (200) — set up control points and begin patrolling
+flag(F): team(200)
  <-
  .print("LOG: [FIELDOPS] INIT - Starting as AXIS team, objective=", F);
  +objective(F);
  .create_control_points(F, 30, 5, C);
  +control_points(C);
  .length(C, L);
  +total_control_points(L);
  +seed_step(0);
  +seeding;
  +patroll_point(0);
  +healthy;
  ?control_points(CP);
  .nth(0, CP, FirstPoint);
  .goto(FirstPoint).

// TEAM_ALLIED (100) — push toward enemy flag
+flag(F): team(100)
  <-
  .print("LOG: [FIELDOPS] INIT - Starting as ALLIED team, objective=", F);
  +objective(F);
  +seed_step(0);
  +seeding;
  +healthy;
  .goto(F).

// ----------------------------------------------------------
// BEHAVIOR 1: SELF-PRESERVATION
// ----------------------------------------------------------
// NO RESPAWN — survival is the agent's highest priority.
// Beliefs: healthy / retreating (mutually exclusive)
// Thresholds: retreat at < 50 HP, recover at >= 80 HP
// Fallback: if no healing at base, resume ops at current HP
// ----------------------------------------------------------

// Plan 1 — Trigger retreat when health drops below 50
+health(H): H < 50 & healthy
  <-
  .print("LOG: [FIELDOPS] CRITICAL_HEALTH - Health=", H, ", RETREATING to base");
  -healthy;
  +retreating;
  -seeding;
  -following;
  -combat_zone;
  -ally_position(_);
  -escorting;
  -defending;
  -drop_cooldown;
  ?base(B);
  .goto(B).

// Plan 2 — Mid-route recovery (e.g. picked up a medpack while retreating)
+health(H): H >= 80 & retreating
  <-
  .print("LOG: [FIELDOPS] HEALTH_RESTORED - Health=", H, ", resuming operations");
  -retreating;
  +healthy;
  +seeding;
  ?objective(F);
  .goto(F).

// Plan 3 — Reached base and fully recovered
+target_reached(T): retreating & health(H) & H >= 80
  <-
  .print("LOG: [FIELDOPS] RECOVERED_AT_BASE - Health=", H, ", resuming operations");
  -target_reached(T);
  -retreating;
  +healthy;
  +seeding;
  ?objective(F);
  .goto(F).

// Plan 4 — Reached base but NOT healed (FALLBACK)
// No passive healing in pyGOMAS; waiting forever would waste a team slot.
// Resume operations at current HP rather than staying idle.
+target_reached(T): retreating & health(H) & H < 80
  <-
  .print("LOG: [FIELDOPS] BASE_NO_HEALING - Health=", H, ", no healing available. Resuming ops at current HP");
  -target_reached(T);
  -retreating;
  +healthy;
  +seeding;
  ?objective(F);
  .goto(F).

// Plan 5 — Moderate health warning (50-69 HP, not critical but weakened)
+health(H): H < 70 & H >= 50 & healthy
  <-
  .print("LOG: [FIELDOPS] MODERATE_HEALTH - Health=", H, ", playing cautiously").

// ----------------------------------------------------------
// BEHAVIOR 2: INTELLIGENT COMBAT SUPPORT
// ----------------------------------------------------------
// Only follow allies who are in ACTIVE combat (enemies < 100 units).
// Guards: must be healthy and not retreating.
// Beliefs: following / combat_zone / ally_position(Pos)
// ----------------------------------------------------------

// Plan 6 — Enter combat support: ally in FOV + enemies nearby
+friends_in_fov(FriendID, Type, Angle, Distance, Health, FriendPos)
  : not following & not retreating & healthy & not escorting & not defending
  & enemies_in_fov(_, _, _, EnemyDist, _, _) & EnemyDist < 100
  <-
  .print("LOG: [FIELDOPS] COMBAT_SUPPORT - Ally ID=", FriendID, " in active combat, moving to support at Pos=", FriendPos);
  -seeding;
  +following;
  +combat_zone;
  +ally_position(FriendPos);
  .look_at(FriendPos);
  .goto(FriendPos).

// Plan 8 — Combat ended: ally visible but no enemies anymore (checked BEFORE Plan 14/7)
+friends_in_fov(FriendID, Type, Angle, Distance, Health, FriendPos)
  : following & combat_zone & not enemies_in_fov(_, _, _, _, _, _)
  <-
  .print("LOG: [FIELDOPS] COMBAT_ENDED - No enemies detected, resuming seeding");
  -following;
  -combat_zone;
  -ally_position(_);
  -drop_cooldown;
  +seeding;
  ?objective(F);
  .goto(F).

// Plan 14 — Combat proximity drop: ally within 30 units during active combat
// Gatekeeper: ammo > 40, health >= 70, not on cooldown (Behavior 4)
+friends_in_fov(FriendID, Type, Angle, Distance, Health, FriendPos)
  : following & combat_zone & Distance < 30 & not drop_cooldown
  & ammo(A) & A > 40 & health(H) & H >= 70
  <-
  .print("LOG: [FIELDOPS] COMBAT_DROP - Dropping AMMOPACK near ally ID=", FriendID, " at dist=", Distance);
  .reload;
  +drop_cooldown;
  -ally_position(_);
  +ally_position(FriendPos);
  .look_at(FriendPos);
  .goto(FriendPos).

// Plan 7 — Update ally tracking: still in combat, ally moved
+friends_in_fov(FriendID, Type, Angle, Distance, Health, FriendPos)
  : following & combat_zone
  <-
  .print("LOG: [FIELDOPS] COMBAT_TRACK - Updating ally ID=", FriendID, " position to ", FriendPos);
  -ally_position(_);
  +ally_position(FriendPos);
  .look_at(FriendPos);
  .goto(FriendPos).

// ----------------------------------------------------------
// TARGET_REACHED while following (from Behavior 2)
// ----------------------------------------------------------

// Plan 9 — Reached ally position while following: resume seeding
+target_reached(T): following
  <-
  .print("LOG: [FIELDOPS] ALLY_REACHED - Arrived at ally position, resuming seeding");
  -target_reached(T);
  -drop_cooldown;
  -following;
  -combat_zone;
  -ally_position(_);
  +seeding;
  ?objective(F);
  .goto(F).

// ----------------------------------------------------------
// BEHAVIOR 3: STRATEGIC SEEDING (with Behavior 4 gatekeeper)
// ----------------------------------------------------------
// Team-based ammo distribution while patrolling.
// AXIS (200): drop ammo at each control point to create a supply line.
// ALLIED (100): drop ammo every 2 waypoints to conserve stamina.
// Gatekeeper (Behavior 4): .reload requires ALL of:
//   - ammo(A) > 40 (keep 40% self-defense reserve)
//   - health(H) >= 70 (no drops at moderate health — focus on evasion)
//   - not drop_cooldown (one drop per destination cycle)
// Active only in seeding state (not retreating, not following).
// ----------------------------------------------------------

// === AXIS (Team 200) — Supply line through control points ===

// Plan 10 — AXIS seeding: reach control point, conditionally drop ammo, advance
+target_reached(T): seeding & team(200) & not retreating & ammo(A) & A > 40
  <-
  -drop_cooldown;
  ?patroll_point(P);
  ?total_control_points(Total);
  ?seed_step(S);
  if (health(H) & H >= 70) {
    .print("LOG: [FIELDOPS] AXIS_SEED - Dropping AMMOPACK #", S, " at control point ", P, "/", Total);
    .reload;
    +drop_cooldown;
  } else {
    .print("LOG: [FIELDOPS] AXIS_WEAK_SKIP - Health=", H, ", skipping drop at point ", P, "/", Total);
  }
  -+seed_step(S + 1);
  -target_reached(T);
  if (P + 1 < Total) {
    -+patroll_point(P + 1);
    ?control_points(C);
    .nth(P + 1, C, Next);
    .print("LOG: [FIELDOPS] AXIS_ADVANCE - Moving to control point ", P + 1);
    .goto(Next);
  } else {
    .print("LOG: [FIELDOPS] AXIS_HOLD - Reached last point, holding forward position");
  }.

// Plan 11 — AXIS seeding: low ammo, skip drop but keep patrolling
+target_reached(T): seeding & team(200) & not retreating & ammo(A) & A <= 40
  <-
  -drop_cooldown;
  ?patroll_point(P);
  ?total_control_points(Total);
  .print("LOG: [FIELDOPS] AXIS_LOW_AMMO - Ammo=", A, ", skipping drop at point ", P, "/", Total);
  -target_reached(T);
  if (P + 1 < Total) {
    -+patroll_point(P + 1);
    ?control_points(C);
    .nth(P + 1, C, Next);
    .goto(Next);
  } else {
    .print("LOG: [FIELDOPS] AXIS_HOLD - Reached last point, holding forward position");
  }.

// === ALLIED (Team 100) — Efficient advance with paced drops ===

// Plan 12 — ALLIED seeding: reach waypoint, drop ammo every 2 steps if gatekeeper passes
+target_reached(T): seeding & team(100) & not retreating & ammo(A) & A > 40
  <-
  -drop_cooldown;
  ?seed_step(S);
  ?objective(F);
  if (S mod 2 == 0 & health(H) & H >= 70) {
    .print("LOG: [FIELDOPS] ALLIED_SEED - Dropping AMMOPACK #", S, " on advance route");
    .reload;
    +drop_cooldown;
  }
  -+seed_step(S + 1);
  .print("LOG: [FIELDOPS] ALLIED_ADVANCE - Step ", S + 1, ", continuing to objective");
  -target_reached(T);
  .goto(F).

// Plan 13 — ALLIED seeding: low ammo, advance without dropping
+target_reached(T): seeding & team(100) & not retreating & ammo(A) & A <= 40
  <-
  -drop_cooldown;
  ?seed_step(S);
  ?objective(F);
  .print("LOG: [FIELDOPS] ALLIED_LOW_AMMO - Ammo=", A, ", skipping drop at step ", S);
  -+seed_step(S + 1);
  -target_reached(T);
  .goto(F).

// ----------------------------------------------------------
// BEHAVIOR 5: COMBAT RESPONSE MATRIX
// ----------------------------------------------------------
// State-based firing logic triggered by enemies_in_fov.
// Plan order = priority (Jason tries top-to-bottom, first match fires).
// Ammo safety: normal plans require ammo > 5; Plan 20 is last-resort.
//
// | State             | Bullets | Condition              |
// |-------------------|---------|------------------------|
// | Retreating        | 1       | Dist < 30, ammo > 5   |
// | Last resort       | 1       | ammo <= 5, Dist < 15   |
// | Retreating (far)  | 0       | ignore, keep fleeing   |
// | Moderate health   | 0       | H 50-69, avoid combat  |
// | Combat with ally  | 3       | following, ammo > 5    |
// | Seeding (healthy) | 2       | seeding, ammo > 5      |
// ----------------------------------------------------------

// Plan 15 — Retreating evasion: deterrent shot at close threat
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : retreating & Dist < 30 & ammo(A) & A > 5
  <-
  .print("LOG: [FIELDOPS] RETREAT_FIRE - Enemy ID=", EID, " at dist=", Dist, ", firing 1 deterrent bullet");
  .look_at(EnemyPos);
  .shoot(1, EnemyPos).

// Plan 20 — Last resort: life-or-death with critical ammo
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : ammo(A) & A <= 5 & Dist < 15
  <-
  .print("LOG: [FIELDOPS] LAST_RESORT - Enemy ID=", EID, " at dist=", Dist, ", ammo=", A, ", emergency shot");
  .look_at(EnemyPos);
  .shoot(1, EnemyPos).

// Plan 16 — Retreating ignore: enemy too far to bother with
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : retreating
  <-
  .print("LOG: [FIELDOPS] RETREAT_IGNORE - Enemy ID=", EID, " at dist=", Dist, ", ignoring (fleeing to base)").

// Plan 17 — Moderate health avoidance: no shooting at 50-69 HP
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : healthy & health(H) & H < 70 & H >= 50
  <-
  .print("LOG: [FIELDOPS] MODERATE_AVOID - Enemy ID=", EID, " at dist=", Dist, ", Health=", H, ", avoiding combat").

// Plan 18 — Combat with ally: full offensive fire
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : following & combat_zone & ammo(A) & A > 5
  <-
  .print("LOG: [FIELDOPS] COMBAT_FIRE - Enemy ID=", EID, " at dist=", Dist, ", firing 3 offensive bullets");
  .look_at(EnemyPos);
  .shoot(3, EnemyPos).

// Plan 19 — Seeding cautious fire: engage and keep moving
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : seeding & healthy & ammo(A) & A > 5
  <-
  .print("LOG: [FIELDOPS] CAUTIOUS_FIRE - Enemy ID=", EID, " at dist=", Dist, ", firing 2 cautious bullets");
  .look_at(EnemyPos);
  .shoot(2, EnemyPos).

// ----------------------------------------------------------
// BEHAVIOR 6: FLAG EVENTS
// ----------------------------------------------------------
// Escorting (ALLIED) and Defending (AXIS) triggered by flag capture.
// +flag_taken fires when the flag is captured; -flag_taken when returned.
// ALLIED: escort the flag carrier home (go to base, drop ammo en route).
// AXIS: defend base against the flag thief (go to base, intercept).
// Beliefs: escorting / defending (mutually exclusive with seeding/following).
// Self-Preservation (Behavior 1) always overrides flag events.
// ----------------------------------------------------------

// === ALLIED (Team 100) — Escort Mode ===

// Plan 21 — ALLIED flag taken: enter escort mode
+flag_taken: team(100) & not retreating
  <-
  .print("LOG: [FIELDOPS] FLAG_ESCORT - Flag captured! Entering escort mode, heading to base");
  -seeding;
  -following;
  -combat_zone;
  -ally_position(_);
  -drop_cooldown;
  +escorting;
  .register_service("fieldops_escort");
  .get_backups;
  ?base(B);
  .goto(B).

// Plan 22 — ALLIED flag returned/dropped: exit escort, resume seeding
-flag_taken: escorting
  <-
  .print("LOG: [FIELDOPS] FLAG_RETURNED - Flag dropped/returned, resuming seeding operations");
  -escorting;
  +seeding;
  ?objective(F);
  .goto(F).

// Plan 23 — ALLIED escort: reached base, drop ammo for carrier, hold
+target_reached(T): escorting & team(100)
  <-
  -target_reached(T);
  -drop_cooldown;
  if (ammo(A) & A > 40 & health(H) & H >= 70) {
    .print("LOG: [FIELDOPS] ESCORT_DROP - At base, dropping AMMOPACK for flag carrier");
    .reload;
    +drop_cooldown;
  } else {
    .print("LOG: [FIELDOPS] ESCORT_HOLD - At base, holding position to protect carrier");
  }.

// === AXIS (Team 200) — Defend Mode ===

// Plan 24 — AXIS flag taken: enter defend mode
+flag_taken: team(200) & not retreating
  <-
  .print("LOG: [FIELDOPS] FLAG_DEFEND - Flag stolen! Entering defend mode, returning to base");
  -seeding;
  -following;
  -combat_zone;
  -ally_position(_);
  -drop_cooldown;
  +defending;
  ?base(B);
  .goto(B).

// Plan 25 — AXIS flag recovered: exit defend, resume seeding
-flag_taken: defending
  <-
  .print("LOG: [FIELDOPS] FLAG_RECOVERED - Flag recovered, resuming seeding operations");
  -defending;
  +seeding;
  ?patroll_point(P);
  ?control_points(C);
  ?total_control_points(Total);
  if (P < Total) {
    .nth(P, C, NextPoint);
    .print("LOG: [FIELDOPS] DEFEND_RESUME - Resuming patrol at point ", P);
    .goto(NextPoint);
  } else {
    ?objective(F);
    .goto(F);
  }.

// Plan 26 — AXIS defend: reached base, drop ammo for defenders, hold
+target_reached(T): defending & team(200)
  <-
  -target_reached(T);
  -drop_cooldown;
  if (ammo(A) & A > 40 & health(H) & H >= 70) {
    .print("LOG: [FIELDOPS] DEFEND_DROP - At base, dropping AMMOPACK for defending allies");
    .reload;
    +drop_cooldown;
  } else {
    .print("LOG: [FIELDOPS] DEFEND_HOLD - At base, holding defensive position");
  }.

// === Combat Response during Flag Events ===

// Plan 27 — Escort combat: cautious fire while protecting carrier route
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : escorting & healthy & ammo(A) & A > 5
  <-
  .print("LOG: [FIELDOPS] ESCORT_FIRE - Enemy ID=", EID, " at dist=", Dist, ", firing 2 protective bullets");
  .look_at(EnemyPos);
  .shoot(2, EnemyPos).

// Plan 28 — Defend combat: aggressive fire to intercept flag thief
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : defending & healthy & ammo(A) & A > 5
  <-
  .print("LOG: [FIELDOPS] DEFEND_FIRE - Enemy ID=", EID, " at dist=", Dist, ", firing 3 interception bullets");
  .look_at(EnemyPos);
  .shoot(3, EnemyPos).
