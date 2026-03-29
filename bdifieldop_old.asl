// ============================================================
// BDI FIELDOPS AGENT — Autonomous FOV-based support
// ============================================================
// Behaviors:
//   1. Visual Anchoring: follow allies spotted in FOV
//   2. Proactive Drop:   drop ammopack when ally is near enemies
//   3. Geographic Seeding: patrol toward objective dropping packs
// ============================================================

// ----------------------------------------------------------
// INITIALIZATION — both teams
// ----------------------------------------------------------

// TEAM_AXIS (200) — create patrol control points toward the flag
+flag(F): team(200)
  <-
  .print("LOG: [FIELDOPS] - INIT - Starting as AXIS team, objective=", F);
  +objective(F);
  .create_control_points(F, 25, 3, C);
  +control_points(C);
  .length(C, L);
  +total_control_points(L);
  +seed_step(0);
  +seeding;
  +patroll_point(0).

// TEAM_ALLIED (100) — go for the flag as objective
+flag(F): team(100)
  <-
  .print("LOG: [FIELDOPS] - INIT - Starting as ALLIED team, objective=", F);
  +objective(F);
  +seed_step(0);
  +seeding;
  .goto(F).

// ----------------------------------------------------------
// 1. VISUAL ANCHORING — follow an ally spotted in FOV
// ----------------------------------------------------------

// When we see a friend, switch to following mode.
// Save the ally's position and move toward them.
+friends_in_fov(ID, Type, Angle, Distance, Health, Position)
  : not following
  <-
  .print("LOG: [FIELDOPS] - ANCHOR_START - Anchoring to ally ID=", ID, " Type=", Type, " at Pos=", Position);
  -seeding;
  +following;
  +ally_position(Position);
  .goto(Position).

// If we are already following and see a (possibly updated) friend,
// refresh the tracked position to keep tracking.
+friends_in_fov(ID, Type, Angle, Distance, Health, Position)
  : following
  <-

  -ally_position(_);
  +ally_position(Position);
  .goto(Position).

// ----------------------------------------------------------
// 2. PROACTIVE DROP — drop ammopack when enemies appear
// ----------------------------------------------------------

// While following an ally, if we see an enemy we assume combat.
// Drop an ammopack for the ally and shoot the enemy.
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : following & ally_position(_)
  <-
  .print("LOG: [FIELDOPS] - PROACTIVE_DROP - Enemy ID=", ID, " detected near ally! Dropping AMMOPACK");
  .reload;
  .shoot(3, Position).

// If enemies appear but we are NOT following anyone (seeding),
// just defend ourselves.
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : not following
  <-
  .print("LOG: [FIELDOPS] - SELF_DEFENSE - Enemy ID=", ID, " while seeding, shooting");
  .shoot(3, Position).

// ----------------------------------------------------------
// 3. GEOGRAPHIC SEEDING — idle patrol dropping ammopacks
// ----------------------------------------------------------

// Patrol point navigation (AXIS): move to next control point
+patroll_point(P): total_control_points(T) & P < T & seeding
  <-
  .print("LOG: [FIELDOPS] - SEED_NAVIGATE - Moving to patrol point ", P, "/", T);
  ?control_points(C);
  .nth(P, C, A);
  .goto(A).

// Wrap around patrol points
+patroll_point(P): total_control_points(T) & P >= T & seeding
  <-
  .print("LOG: [FIELDOPS] - SEED_LOOP - Patrol cycle complete, restarting");
  -patroll_point(P);
  +patroll_point(0).

// When we reach a target while seeding, drop an ammopack and advance
+target_reached(T): seeding & team(200)
  <-
  ?seed_step(S);
  .print("LOG: [FIELDOPS] - SEED_DROP - Dropping AMMOPACK #", S, " along AXIS route");
  .reload;
  ?patroll_point(P);
  -+seed_step(S + 1);
  -+patroll_point(P + 1);
  -target_reached(T).

// ALLIED seeding: drop an ammopack when reaching waypoints,
// then continue toward the objective
+target_reached(T): seeding & team(100)
  <-
  ?seed_step(S);
  .print("LOG: [FIELDOPS] - SEED_DROP - Dropping AMMOPACK #", S, " along ALLIED route");
  .reload;
  ?objective(F);
  -+seed_step(S + 1);
  .turn(0.375);
  -target_reached(T).

// When following an ally and reaching their position,
// drop an ammopack preemptively and keep waiting for new FOV updates
+target_reached(T): following
  <-
  .print("LOG: [FIELDOPS] - ANCHOR_LOST - Reached ally pos, ally no longer in FOV. Dropping AMMOPACK, reverting to SEEDING");
  .reload;
  -target_reached(T);
  -following;
  +seeding;
  ?objective(F);
  .goto(F).

// ----------------------------------------------------------
// FLAG TAKEN — return to base (ALLIED only)
// ----------------------------------------------------------
+flag_taken: team(100)
  <-
  .print("LOG: [FIELDOPS] - FLAG_TAKEN - Returning to base");
  -seeding;
  -following;
  ?base(B);
  .goto(B).

