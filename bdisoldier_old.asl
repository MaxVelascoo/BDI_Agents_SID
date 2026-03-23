// ============================================================
// BDI SOLDIER AGENT — Self-reliant autonomous combatant
// ============================================================
// Behaviors:
//   1. Self-Reliant Memory: track flag position from own perception
//   2. Systematic Search:   search pattern when flag location unknown
//   3. Combat Override:     always prioritize shooting (double damage)
// ============================================================

// ----------------------------------------------------------
// INITIALIZATION
// ----------------------------------------------------------

// TEAM_AXIS (200) — defend around own base, patrol control points
+flag(F): team(200)
  <-
  .print("LOG: [SOLDIER] - INIT - Starting as AXIS team, flag=", F);
  +my_last_known_flag(F, 0);
  .create_control_points(F, 25, 3, C);
  +control_points(C);
  .length(C, L);
  +total_control_points(L);
  +searching;
  +patroll_point(0).

// TEAM_ALLIED (100) — remember flag position and go capture it
+flag(F): team(100)
  <-
  .print("LOG: [SOLDIER] - INIT - Starting as ALLIED team, flag=", F);
  +my_last_known_flag(F, 0);
  +searching;
  .goto(F).

// ----------------------------------------------------------
// 1. SELF-RELIANT MEMORY — update flag belief from own senses
// ----------------------------------------------------------

// If we see a friendly carrying the flag, update our memory
// (the carrier's position IS the flag's effective position)
+friends_in_fov(ID, Type, Angle, Distance, Health, Position)
  : Type == 0  // type 0 = flag carrier (soldier with flag)
  <-
  .print("LOG: [SOLDIER] - MEMORY_UPDATE - Spotted flag carrier ID=", ID, " at Pos=", Position, ". Updating flag memory.");
  -my_last_known_flag(_, _);
  +my_last_known_flag(Position, 1).

// If the flag is taken event fires, we know someone grabbed it
+flag_taken: team(100)
  <-
  .print("LOG: [SOLDIER] - FLAG_TAKEN - Transitioning to RETURNING state");
  -searching;
  +returning;
  ?base(B);
  .goto(B).

// ----------------------------------------------------------
// 2. SYSTEMATIC SEARCH — find the flag independently
// ----------------------------------------------------------

// AXIS patrol: cycle through control points around own base
+patroll_point(P): total_control_points(T) & P < T & searching & team(200)
  <-
  .print("LOG: [SOLDIER] - SYSTEMATIC_SEARCH - AXIS patrol point ", P, "/", T, " (defending base perimeter)");
  ?control_points(C);
  .nth(P, C, A);
  .goto(A).

+patroll_point(P): total_control_points(T) & P >= T & searching & team(200)
  <-
  .print("LOG: [SOLDIER] - SYSTEMATIC_SEARCH - AXIS patrol cycle complete, restarting search loop");
  -patroll_point(P);
  +patroll_point(0).

// AXIS: when reaching a patrol waypoint, advance to the next
+target_reached(T): searching & team(200)
  <-
  ?patroll_point(P);
  .print("LOG: [SOLDIER] - SYSTEMATIC_SEARCH - AXIS waypoint reached, advancing to patrol point ", P + 1);
  -+patroll_point(P + 1);
  -target_reached(T).

// ALLIED search: move toward the enemy flag location from memory
+target_reached(T): searching & team(100) & my_last_known_flag(Pos, _)
  <-
  .print("LOG: [SOLDIER] - SYSTEMATIC_SEARCH - ALLIED pushing toward last known flag at Pos=", Pos);
  -target_reached(T);
  +exploring;
  .goto(Pos).

// ALLIED fallback: if we reach a target while exploring, keep scanning
+target_reached(T): exploring & team(100)
  <-
  .print("LOG: [SOLDIER] - EXPLORE - Reached exploration point, scanning area for flag/enemies");
  -target_reached(T);
  .turn(0.375).

// ALLIED: when returning to base and reaching it
+target_reached(T): returning & team(100)
  <-
  .print("LOG: [SOLDIER] - RETURN_COMPLETE - Reached base successfully");
  -returning;
  -target_reached(T).

// ALLIED heading while exploring — keep scanning
+heading(H): exploring & team(100)
  <-
  .print("LOG: [SOLDIER] - EXPLORE_IDLE - Scanning surroundings while exploring");
  .wait(2000);
  .turn(0.375).

// ----------------------------------------------------------
// 3. COMBAT OVERRIDE — always shoot enemies (soldiers = 2x damage)
// ----------------------------------------------------------

// Enemies spotted: ALWAYS shoot regardless of current state.
// Use burst of 5 shots (soldiers are primary combatants).
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  <-
  .print("LOG: [SOLDIER] - COMBAT_OVERRIDE - >>> ENEMY CONTACT <<< ID=", ID, " HP=", Health, " Dist=", Distance, " | Firing 5-shot burst!");
  .shoot(5, Position).