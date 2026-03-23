// ============================================================
// BDI SOLDIER AGENT — Enhanced Autonomous Combatant
// ============================================================
// Behaviors:
//   1. Aggressive Objective Push: capture flag with smart pathfinding
//   2. Combat Superiority: engage enemies with 2x damage advantage
//   3. Self-Preservation: retreat when critically wounded
//   4. Pack Awareness: pick up health/ammo packs opportunistically
// ============================================================

// ----------------------------------------------------------
// INITIALIZATION
// ----------------------------------------------------------

// TEAM_AXIS (200) — defend aggressively, intercept enemies
+flag(F): team(200)
  <-
  .print("LOG: [SOLDIER] - INIT - Starting as AXIS team, defending flag at ", F);
  +objective(F);
  +my_last_known_flag(F, 0);
  .create_control_points(F, 35, 4, C);  // Defensive perimeter
  +control_points(C);
  .length(C, L);
  +total_control_points(L);
  +defending;
  +patroll_point(0);
  +healthy.

// TEAM_ALLIED (100) — aggressive flag capture
+flag(F): team(100)
  <-
  .print("LOG: [SOLDIER] - INIT - Starting as ALLIED team, objective flag at ", F);
  +objective(F);
  +my_last_known_flag(F, 0);
  +attacking;
  +healthy;
  .goto(F).

// ----------------------------------------------------------
// SELF-PRESERVATION — retreat when health is critical
// ----------------------------------------------------------

// Monitor health and retreat if critical (NO RESPAWN!)
+health(H): H < 40 & healthy & not carrying_flag
  <-
  .print("LOG: [SOLDIER] - CRITICAL_HEALTH - Health=", H, ", RETREATING! (No respawn)");
  -healthy;
  +retreating;
  -attacking;
  -defending;
  ?base(B);
  .goto(B).

// If carrying flag, be more conservative (retreat earlier)
+health(H): H < 60 & healthy & carrying_flag
  <-
  .print("LOG: [SOLDIER] - FLAG_CARRIER_RETREAT - Health=", H, ", carrying flag, RETREATING!");
  -healthy;
  +retreating;
  ?base(B);
  .goto(B).

// Recover when health is restored
+health(H): H >= 70 & retreating & not carrying_flag
  <-
  .print("LOG: [SOLDIER] - HEALTH_RESTORED - Health=", H, ", resuming operations");
  -retreating;
  +healthy;
  ?objective(F);
  if (team(100)) {
    +attacking;
    .goto(F);
  } else {
    +defending;
    +patroll_point(0);
  }.

// If carrying flag and recovered, continue to base
+health(H): H >= 70 & retreating & carrying_flag
  <-
  .print("LOG: [SOLDIER] - FLAG_CARRIER_RECOVERED - Health=", H, ", continuing to base with flag");
  -retreating;
  +healthy;
  ?base(B);
  .goto(B).

// Monitor ammo
+ammo(A): A < 15 & not retreating
  <-
  .print("LOG: [SOLDIER] - LOW_AMMO - Ammo=", A, ", need to find ammo pack!").

// ----------------------------------------------------------
// PACK AWARENESS — opportunistically pick up packs
// ----------------------------------------------------------

// Prioritize health packs if wounded and not carrying flag
+packs_in_fov(ID, Type, Angle, Distance, Health, Position)
  : Type == 1001 & health(H) & H < 50 & not carrying_flag & not seeking_pack
  <-
  .print("LOG: [SOLDIER] - HEALTH_PACK - Going for health pack at ", Position);
  +seeking_pack;
  .goto(Position).

// Prioritize ammo packs if very low on ammo and not carrying flag
+packs_in_fov(ID, Type, Angle, Distance, Health, Position)
  : Type == 1002 & ammo(A) & A < 15 & not carrying_flag & not seeking_pack
  <-
  .print("LOG: [SOLDIER] - AMMO_PACK - Going for ammo pack at ", Position);
  +seeking_pack;
  .goto(Position).

// Resume objective after picking up pack
+pack_taken(Type, N)
  : seeking_pack
  <-
  .print("LOG: [SOLDIER] - PACK_ACQUIRED - Picked up pack type ", Type, ", resuming objective");
  -seeking_pack;
  ?objective(F);
  if (team(100) & attacking) {
    .goto(F);
  }.

// If we reach pack position but didn't pick it up, resume objective
+target_reached(T): seeking_pack
  <-
  .print("LOG: [SOLDIER] - PACK_MISSED - Pack not found, resuming objective");
  -target_reached(T);
  -seeking_pack;
  ?objective(F);
  if (team(100) & attacking) {
    .goto(F);
  }.

// ----------------------------------------------------------
// COMBAT SUPERIORITY — soldiers deal 2x damage
// ----------------------------------------------------------

// Priority: If retreating, minimize combat
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : retreating & not carrying_flag
  <-
  .print("LOG: [SOLDIER] - RETREAT_COMBAT - Enemy ID=", ID, " while retreating");
  if (Distance < 40) {
    .shoot(2, Position);  // Quick shots while retreating
  }.

// If carrying flag and retreating, avoid all combat
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : retreating & carrying_flag
  <-
  .print("LOG: [SOLDIER] - FLAG_CARRIER_EVASION - Enemy ID=", ID, ", evading (carrying flag!)").

// Normal combat: aggressive engagement (soldiers = 2x damage)
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : not retreating & healthy
  <-
  .print("LOG: [SOLDIER] - COMBAT - >>> ENGAGING ENEMY <<< ID=", ID, " HP=", Health, " Dist=", Distance);
  .shoot(5, Position).  // 5 shots with 2x damage = devastating

// Wounded but not retreating yet: cautious combat
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : not retreating & not healthy
  <-
  .print("LOG: [SOLDIER] - WOUNDED_COMBAT - Enemy ID=", ID, ", engaging cautiously");
  .shoot(3, Position).

// ----------------------------------------------------------
// OBJECTIVE EXECUTION — capture or defend flag
// ----------------------------------------------------------

// ALLIED: Reached flag position, pick it up
+target_reached(T): attacking & team(100) & objective(F)
  <-
  .print("LOG: [SOLDIER] - FLAG_REACHED - At flag position, capturing!");
  -target_reached(T);
  +at_flag.

// ALLIED: Flag captured, return to base
+flag_taken: team(100)
  <-
  .print("LOG: [SOLDIER] - FLAG_CAPTURED - Flag secured! Returning to base");
  -attacking;
  -at_flag;
  +carrying_flag;
  +returning;
  ?base(B);
  .goto(B).

// ALLIED: Reached base with flag = VICTORY
+target_reached(T): returning & carrying_flag & team(100)
  <-
  .print("LOG: [SOLDIER] - VICTORY - Flag delivered to base! MISSION ACCOMPLISHED!");
  -target_reached(T);
  -carrying_flag;
  -returning.

// AXIS: Patrol defensive perimeter
+patroll_point(P): total_control_points(T) & P < T & defending & team(200)
  <-
  .print("LOG: [SOLDIER] - DEFENSIVE_PATROL - Patrol point ", P, "/", T);
  ?control_points(C);
  .nth(P, C, A);
  .goto(A).

// AXIS: Wrap around patrol
+patroll_point(P): total_control_points(T) & P >= T & defending & team(200)
  <-
  .print("LOG: [SOLDIER] - PATROL_CYCLE - Restarting defensive patrol");
  -patroll_point(P);
  +patroll_point(0).

// AXIS: Reached patrol point, advance
+target_reached(T): defending & team(200)
  <-
  ?patroll_point(P);
  .print("LOG: [SOLDIER] - PATROL_POINT_REACHED - Advancing to point ", P + 1);
  -+patroll_point(P + 1);
  -target_reached(T).

// AXIS: Flag taken by enemy, aggressive intercept
+flag_taken: team(200)
  <-
  .print("LOG: [SOLDIER] - FLAG_STOLEN - Enemy has flag! INTERCEPTING!");
  -defending;
  +intercepting;
  ?base(B);
  .goto(B).

// AXIS: Reached base while intercepting
+target_reached(T): intercepting & team(200)
  <-
  .print("LOG: [SOLDIER] - INTERCEPT_POSITION - At base, hunting flag carrier");
  -target_reached(T).

// Retreating: reached base
+target_reached(T): retreating
  <-
  .print("LOG: [SOLDIER] - BASE_REACHED - At base, recovering");
  -target_reached(T).
