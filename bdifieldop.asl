// ============================================================
// BDI FIELDOPS AGENT — Enhanced Autonomous Support
// ============================================================
// Behaviors:
//   1. Strategic Seeding: aggressive path to objective with ammo drops
//   2. Combat Support: only follow allies actively in combat
//   3. Self-Preservation: retreat when health is critical
//   4. Resource Management: smart ammo pack placement
// ============================================================

// ----------------------------------------------------------
// INITIALIZATION — both teams
// ----------------------------------------------------------

// TEAM_AXIS (200) — create aggressive control points toward enemy flag
+flag(F): team(200)
  <-
  .print("LOG: [FIELDOPS] - INIT - Starting as AXIS team, objective=", F);
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
  .print("LOG: [FIELDOPS] - INIT - Starting as ALLIED team, objective=", F);
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
  .print("LOG: [FIELDOPS] - CRITICAL_HEALTH - Health=", H, ", RETREATING! (No respawn - must survive)");
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
  .print("LOG: [FIELDOPS] - HEALTH_RESTORED - Health=", H, ", resuming operations cautiously");
  -retreating;
  +healthy;
  +seeding;
  ?objective(F);
  .goto(F).

// If at base and still retreating but health improving, wait
+target_reached(T): retreating & health(H) & H < 80
  <-
  .print("LOG: [FIELDOPS] - BASE_REACHED - At base, health=", H, ", waiting to recover");
  -target_reached(T).

// If at base and health is good, resume operations
+target_reached(T): retreating & health(H) & H >= 80
  <-
  .print("LOG: [FIELDOPS] - RECOVERED - Health=", H, ", resuming operations");
  -target_reached(T);
  -retreating;
  +healthy;
  +seeding;
  ?objective(F);
  .goto(F).

// Stay cautious if health is moderate
+health(H): H < 70 & H >= 50 & seeding
  <-
  .print("LOG: [FIELDOPS] - MODERATE_HEALTH - Health=", H, ", playing defensively").

// ----------------------------------------------------------
// COMBAT SUPPORT — only follow allies in active combat
// ----------------------------------------------------------

// Only follow allies if there are enemies nearby (active combat zone)
+friends_in_fov(FriendID, Type, Angle, Distance, Health, FriendPos)
  : not following & not retreating & enemies_in_fov(_, _, _, EnemyDist, _, _) & EnemyDist < 100
  <-
  .print("LOG: [FIELDOPS] - COMBAT_SUPPORT - Ally ID=", FriendID, " in combat! Providing support at Pos=", FriendPos);
  -seeding;
  +following;
  +ally_position(FriendPos);
  +combat_zone;
  .goto(FriendPos).

// Follow soldiers (Type=1) even without enemies visible (they're going to combat)
+friends_in_fov(FriendID, Type, Angle, Distance, Health, FriendPos)
  : not following & not retreating & Type == 1 & Distance < 80 & seeding
  <-
  .print("LOG: [FIELDOPS] - SOLDIER_SUPPORT - Following soldier ID=", FriendID, " to provide ammo support");
  -seeding;
  +following;
  +ally_position(FriendPos);
  .goto(FriendPos).

// Update ally position if still in combat
+friends_in_fov(FriendID, Type, Angle, Distance, Health, FriendPos)
  : following & combat_zone
  <-
  .print("LOG: [FIELDOPS] - COMBAT_UPDATE - Tracking ally ID=", FriendID, " at Pos=", FriendPos);
  -ally_position(_);
  +ally_position(FriendPos);
  .goto(FriendPos).

// Update ally position if following soldier
+friends_in_fov(FriendID, Type, Angle, Distance, Health, FriendPos)
  : following & not combat_zone & Type == 1
  <-
  .print("LOG: [FIELDOPS] - SOLDIER_UPDATE - Tracking soldier ID=", FriendID, " at Pos=", FriendPos);
  -ally_position(_);
  +ally_position(FriendPos);
  .goto(FriendPos).

// If no enemies detected for a while, stop following and resume seeding
+friends_in_fov(FriendID, Type, Angle, Distance, Health, FriendPos)
  : following & not enemies_in_fov(_, _, _, _, _, _) & combat_zone
  <-
  .print("LOG: [FIELDOPS] - COMBAT_ENDED - No enemies detected, resuming strategic seeding");
  -following;
  -combat_zone;
  -ally_position(_);
  +seeding;
  ?objective(F);
  .goto(F).

// ----------------------------------------------------------
// COMBAT RESPONSE — drop ammo and engage enemies
// ----------------------------------------------------------

// Priority: If retreating, AVOID combat - survival is everything
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : retreating
  <-
  .print("LOG: [FIELDOPS] - RETREAT_EVASION - Enemy ID=", ID, " while retreating, EVADING (no respawn!)");
  // Only shoot if enemy is very close (< 30 units)
  if (Distance < 30) {
    .shoot(1, Position);  // Minimal fire to discourage pursuit
  }.

// In combat support mode: drop ammo for ally and engage (but be careful)
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : following & combat_zone & ally_position(_) & healthy
  <-
  .print("LOG: [FIELDOPS] - COMBAT_DROP - Enemy ID=", ID, " in combat zone! Dropping AMMOPACK and engaging");
  .reload;
  -+last_pack_drop_time(1);  // Mark that we dropped a pack
  .shoot(3, Position).

// While seeding: engage enemies cautiously (no respawn means careful play)
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : seeding & not retreating & healthy
  <-
  .print("LOG: [FIELDOPS] - SEEDING_DEFENSE - Enemy ID=", ID, " detected, engaging cautiously");
  .shoot(2, Position).  // Reduced from 3 to conserve ammo and avoid prolonged combat

// ----------------------------------------------------------
// STRATEGIC SEEDING — aggressive path with smart pack drops
// ----------------------------------------------------------

// Patrol point navigation (AXIS): move aggressively toward enemy
+patroll_point(P): total_control_points(T) & P < T & seeding & not retreating
  <-
  .print("LOG: [FIELDOPS] - STRATEGIC_ADVANCE - Moving to patrol point ", P, "/", T);
  ?control_points(C);
  .nth(P, C, A);
  .goto(A).

// Wrap around patrol points
+patroll_point(P): total_control_points(T) & P >= T & seeding
  <-
  .print("LOG: [FIELDOPS] - PATROL_CYCLE - Restarting defensive patrol");
  -patroll_point(P);
  +patroll_point(0).

// When reaching a target while seeding (AXIS): drop pack strategically
+target_reached(T): seeding & team(200) & not retreating
  <-
  ?seed_step(S);
  .print("LOG: [FIELDOPS] - STRATEGIC_DROP - Dropping AMMOPACK #", S, " on AXIS advance route");
  .reload;
  ?patroll_point(P);
  -+seed_step(S + 1);
  -+patroll_point(P + 1);
  -+last_pack_drop_time(1);
  -target_reached(T).

// ALLIED seeding: aggressive push with pack drops every few waypoints
+target_reached(T): seeding & team(100) & not retreating
  <-
  ?seed_step(S);
  ?objective(F);
  // Drop pack every 2 waypoints to conserve resources
  .print("LOG: [FIELDOPS] - ALLIED_ADVANCE - Waypoint reached, seed_step=", S);
  if (S mod 2 == 0) {
    .print("LOG: [FIELDOPS] - ALLIED_DROP - Dropping AMMOPACK #", S, " on ALLIED route");
    .reload;
    -+last_pack_drop_time(1);
  }
  -+seed_step(S + 1);
  .goto(F);
  -target_reached(T).

// When following an ally and reaching their position
+target_reached(T): following & combat_zone
  <-
  .print("LOG: [FIELDOPS] - COMBAT_POSITION - Reached combat zone, holding position and providing support");
  .reload;
  -target_reached(T);
  -following;
  -combat_zone;
  -ally_position(_);
  +seeding;
  ?objective(F);
  .goto(F).

// If retreating and reached base, hold position to recover
+target_reached(T): retreating
  <-
  .print("LOG: [FIELDOPS] - BASE_REACHED - At base, recovering");
  -target_reached(T).

// ----------------------------------------------------------
// FLAG EVENTS — adapt to flag status
// ----------------------------------------------------------

// When flag is taken by our team (ALLIED), escort back to base
+flag_taken: team(100) & not retreating
  <-
  .print("LOG: [FIELDOPS] - FLAG_TAKEN - Escorting flag carrier back to base");
  -seeding;
  -following;
  +escorting;
  ?base(B);
  .goto(B).

// When escorting and reaching base
+target_reached(T): escorting
  <-
  .print("LOG: [FIELDOPS] - ESCORT_COMPLETE - Base reached, defending");
  -target_reached(T);
  -escorting;
  +seeding;
  ?base(B);
  .goto(B).

// AXIS: if flag is taken, defend base aggressively
+flag_taken: team(200) & not retreating
  <-
  .print("LOG: [FIELDOPS] - FLAG_DEFENSE - Enemy has flag! Defending base");
  -seeding;
  -following;
  +defending;
  ?base(B);
  .goto(B).

// When defending and reaching base
+target_reached(T): defending
  <-
  .print("LOG: [FIELDOPS] - DEFENSE_POSITION - At base, holding defensive position");
  -target_reached(T).

