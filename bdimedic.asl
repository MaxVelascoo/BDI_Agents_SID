// ============================================================
// BDI MEDIC AGENT — Enhanced Autonomous Medical Support
// ============================================================
// Behaviors:
//   1. Strategic Seeding: aggressive path to objective with medic drops
//   2. Triage Support: prioritize wounded allies in combat
//   3. Self-Preservation: retreat when health is critical
//   4. Resource Management: smart medpack placement
// ============================================================

// ----------------------------------------------------------
// INITIALIZATION — both teams
// ----------------------------------------------------------

// TEAM_AXIS (200) — create aggressive control points toward enemy flag
+flag(F): team(200)
  <-
  .print("LOG: [MEDIC] - INIT - Starting as AXIS team, objective=", F);
  +objective(F);
  .create_control_points(F, 30, 5, C);  // More points, closer spacing
  +control_points(C);
  .length(C, L);
  +total_control_points(L);
  +seed_step(0);
  +seeding;
  +patroll_point(0);
  +last_pack_drop_time(0);
  +healthy.

// TEAM_ALLIED (100) — aggressive push to enemy flag
+flag(F): team(100)
  <-
  .print("LOG: [MEDIC] - INIT - Starting as ALLIED team, objective=", F);
  +objective(F);
  +seed_step(0);
  +seeding;
  +last_pack_drop_time(0);
  +healthy;
  .goto(F).

// ----------------------------------------------------------
// SELF-PRESERVATION — retreat when health is critical
// ----------------------------------------------------------

// Monitor health and retreat if critical (NO RESPAWN - survival is critical!)
+health(H): H < 50 & healthy
  <-
  .print("LOG: [MEDIC] - CRITICAL_HEALTH - Health=", H, ", RETREATING! (No respawn - must survive)");
  -healthy;
  +retreating;
  -seeding;
  -following;
  -combat_zone;
  ?base(B);
  .goto(B).

// Recover when health is restored
+health(H): H >= 80 & retreating
  <-
  .print("LOG: [MEDIC] - HEALTH_RESTORED - Health=", H, ", resuming operations cautiously");
  -retreating;
  +healthy;
  +seeding;
  ?objective(F);
  .goto(F).

// If at base and still retreating but health improving, wait
+target_reached(T): retreating & health(H) & H < 80
  <-
  .print("LOG: [MEDIC] - BASE_REACHED - At base, health=", H, ", waiting to recover");
  -target_reached(T).

// If at base and health is good, resume operations
+target_reached(T): retreating & health(H) & H >= 80
  <-
  .print("LOG: [MEDIC] - RECOVERED - Health=", H, ", resuming operations");
  -target_reached(T);
  -retreating;
  +healthy;
  +seeding;
  ?objective(F);
  .goto(F).

// Stay cautious if health is moderate
+health(H): H < 70 & H >= 50 & seeding & not retreating
  <-
  .print("LOG: [MEDIC] - MODERATE_HEALTH - Health=", H, ", playing defensively").

// Monitor ammo and be conservative
+ammo(A): A < 20 & not retreating
  <-
  .print("LOG: [MEDIC] - LOW_AMMO - Ammo=", A, ", conserving ammunition").

// ----------------------------------------------------------
// TRIAGE SUPPORT — prioritize wounded allies
// ----------------------------------------------------------

// Follow wounded allies (Health < 60) in combat zones
+friends_in_fov(FriendID, Type, Angle, Distance, Health, FriendPos)
  : not following & not retreating & Health < 60 & enemies_in_fov(_, _, _, EnemyDist, _, _) & EnemyDist < 100
  <-
  .print("LOG: [MEDIC] - TRIAGE_PRIORITY - Wounded ally ID=", FriendID, " HP=", Health, " in combat! Providing medical support");
  -seeding;
  +following;
  +ally_position(FriendPos);
  +ally_health(Health);
  +combat_zone;
  .goto(FriendPos).

// Update wounded ally position
+friends_in_fov(FriendID, Type, Angle, Distance, Health, FriendPos)
  : following & combat_zone & Health < 70
  <-
  .print("LOG: [MEDIC] - TRIAGE_UPDATE - Tracking wounded ally ID=", FriendID, " HP=", Health, " at Pos=", FriendPos);
  -ally_position(_);
  -ally_health(_);
  +ally_position(FriendPos);
  +ally_health(Health);
  .goto(FriendPos).

// If ally is healed or no enemies, stop following
+friends_in_fov(FriendID, Type, Angle, Distance, Health, FriendPos)
  : following & (Health >= 70 | not enemies_in_fov(_, _, _, _, _, _))
  <-
  .print("LOG: [MEDIC] - TRIAGE_COMPLETE - Ally healed or combat ended, resuming seeding");
  -following;
  -combat_zone;
  -ally_position(_);
  -ally_health(_);
  +seeding;
  ?objective(F);
  .goto(F).

// ----------------------------------------------------------
// COMBAT RESPONSE — drop medpacks and engage enemies
// ----------------------------------------------------------

// Priority: If retreating, AVOID combat - survival is everything
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : retreating
  <-
  .print("LOG: [MEDIC] - RETREAT_EVASION - Enemy ID=", ID, " while retreating, EVADING (no respawn!)");
  // Only shoot if enemy is very close (< 30 units)
  if (Distance < 30) {
    .shoot(1, Position);  // Minimal fire to discourage pursuit
  }.

// In triage mode: drop medpack for wounded ally and engage
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : following & combat_zone & ally_position(_) & healthy
  <-
  .print("LOG: [MEDIC] - TRIAGE_DROP - Enemy ID=", ID, " near wounded ally! Dropping MEDPACK and engaging");
  .cure;
  -+last_pack_drop_time(1);
  .shoot(3, Position).

// While seeding: engage enemies cautiously
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : seeding & not retreating & healthy
  <-
  .print("LOG: [MEDIC] - SEEDING_DEFENSE - Enemy ID=", ID, " detected, engaging cautiously");
  .shoot(2, Position).

// ----------------------------------------------------------
// STRATEGIC SEEDING — aggressive path with smart medpack drops
// ----------------------------------------------------------

// Patrol point navigation (AXIS): move aggressively toward enemy
+patroll_point(P): total_control_points(T) & P < T & seeding & not retreating
  <-
  .print("LOG: [MEDIC] - STRATEGIC_ADVANCE - Moving to patrol point ", P, "/", T);
  ?control_points(C);
  .nth(P, C, A);
  .goto(A).

// Wrap around patrol points
+patroll_point(P): total_control_points(T) & P >= T & seeding
  <-
  .print("LOG: [MEDIC] - PATROL_CYCLE - Restarting defensive patrol");
  -patroll_point(P);
  +patroll_point(0).

// When reaching a target while seeding (AXIS): drop medpack strategically
+target_reached(T): seeding & team(200) & not retreating
  <-
  ?seed_step(S);
  .print("LOG: [MEDIC] - STRATEGIC_DROP - Dropping MEDPACK #", S, " on AXIS advance route");
  .cure;
  ?patroll_point(P);
  -+seed_step(S + 1);
  -+patroll_point(P + 1);
  -+last_pack_drop_time(1);
  -target_reached(T).

// ALLIED seeding: aggressive push with medpack drops every few waypoints
+target_reached(T): seeding & team(100) & not retreating
  <-
  ?seed_step(S);
  ?objective(F);
  .print("LOG: [MEDIC] - ALLIED_ADVANCE - Waypoint reached, seed_step=", S);
  if (S mod 2 == 0) {
    .print("LOG: [MEDIC] - ALLIED_DROP - Dropping MEDPACK #", S, " on ALLIED route");
    .cure;
    -+last_pack_drop_time(1);
  }
  -+seed_step(S + 1);
  .goto(F);
  -target_reached(T).

// When following wounded ally and reaching their position
+target_reached(T): following & combat_zone
  <-
  .print("LOG: [MEDIC] - TRIAGE_POSITION - Reached wounded ally, dropping MEDPACK");
  .cure;
  -target_reached(T);
  -following;
  -combat_zone;
  -ally_position(_);
  -ally_health(_);
  +seeding;
  ?objective(F);
  .goto(F).

// If retreating and reached base, hold position to recover
+target_reached(T): retreating
  <-
  .print("LOG: [MEDIC] - BASE_REACHED - At base, recovering");
  -target_reached(T).

// ----------------------------------------------------------
// FLAG EVENTS — adapt to flag status
// ----------------------------------------------------------

// When flag is taken by our team (ALLIED), escort back to base
+flag_taken: team(100) & not retreating
  <-
  .print("LOG: [MEDIC] - FLAG_TAKEN - Escorting flag carrier, ready to heal");
  -seeding;
  -following;
  +escorting;
  ?base(B);
  .goto(B).

// When escorting and reaching base
+target_reached(T): escorting
  <-
  .print("LOG: [MEDIC] - ESCORT_COMPLETE - Base reached, defending");
  -target_reached(T);
  -escorting;
  +seeding;
  ?base(B);
  .goto(B).

// AXIS: if flag is taken, defend base aggressively
+flag_taken: team(200) & not retreating
  <-
  .print("LOG: [MEDIC] - FLAG_DEFENSE - Enemy has flag! Defending base and healing defenders");
  -seeding;
  -following;
  +defending;
  ?base(B);
  .goto(B).

// When defending and reaching base
+target_reached(T): defending
  <-
  .print("LOG: [MEDIC] - DEFENSE_POSITION - At base, holding defensive position");
  -target_reached(T).