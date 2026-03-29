// ============================================================
// BDI MEDIC AGENT — Simple and stable support
// ============================================================
// Main idea:
//   - Keep the medic moving most of the time
//   - Only break route for nearby wounded allies
//   - Heal in combat or at controlled seed points
//   - Retreat early because survival matters
// ============================================================

// ----------------------------------------------------------
// INITIALIZATION
// ----------------------------------------------------------

// TEAM_AXIS (200) — patrol toward the flag with control points
+flag(F): team(200)
  <-
  .print("LOG: [MEDIC] - INIT - AXIS team, objective=", F);
  +objective(F);
  .create_control_points(F, 25, 3, C);
  +control_points(C);
  .length(C, L);
  +total_control_points(L);
  +seed_step(0);
  +seeding;
  +healthy;
  +patroll_point(0).

// TEAM_ALLIED (100) — go directly to the flag
+flag(F): team(100)
  <-
  .print("LOG: [MEDIC] - INIT - ALLIED team, objective=", F);
  +objective(F);
  +seed_step(0);
  +seeding;
  +healthy;
  .goto(F).

// ----------------------------------------------------------
// HEALTH / SURVIVAL
// ----------------------------------------------------------

// Cambio importante: retirada a 45 en vez de 40
+health(H): H < 45 & healthy
  <-
  .print("LOG: [MEDIC] - RETREAT - Health=", H);
  -healthy;
  -seeding;
  -following;
  -ally_position(_);
  +retreating;
  ?base(B);
  .goto(B).

+health(H): H >= 80 & retreating & team(100)
  <-
  .print("LOG: [MEDIC] - RECOVERED - Returning to objective");
  -retreating;
  +healthy;
  +seeding;
  ?objective(F);
  .goto(F).

+health(H): H >= 80 & retreating & team(200)
  <-
  .print("LOG: [MEDIC] - RECOVERED - Returning to patrol");
  -retreating;
  +healthy;
  +seeding;
  ?patroll_point(P);
  ?control_points(C);
  .nth(P, C, Next);
  .goto(Next).

+target_reached(T): retreating
  <-
  .print("LOG: [MEDIC] - BASE_REACHED - Holding position");
  -target_reached(T).

// ----------------------------------------------------------
// FOLLOW ONLY NEARBY WOUNDED ALLIES
// ----------------------------------------------------------

// Start following only if the ally is close and actually needs help
+friends_in_fov(ID, Type, Angle, Distance, Health, Position)
  : seeding & not retreating & not following & Distance < 35 & Health < 70
  <-
  .print("LOG: [MEDIC] - FOLLOW_START - Ally=", ID, " HP=", Health, " Dist=", Distance);
  -seeding;
  +following;
  -ally_position(_);
  +ally_position(Position);
  .goto(Position).

// While following, refresh the tracked ally position only if still close and wounded
+friends_in_fov(ID, Type, Angle, Distance, Health, Position)
  : following & Distance < 45 & Health < 80
  <-
  .print("LOG: [MEDIC] - FOLLOW_UPDATE - Ally=", ID, " HP=", Health);
  -ally_position(_);
  +ally_position(Position);
  .goto(Position).

// If the medic reaches the ally, heal once and immediately return to route
+target_reached(T): following & team(100)
  <-
  .print("LOG: [MEDIC] - FOLLOW_REACHED - Healing and resuming push");
  .cure;
  -target_reached(T);
  -following;
  -ally_position(_);
  +seeding;
  ?objective(F);
  .goto(F).

+target_reached(T): following & team(200)
  <-
  .print("LOG: [MEDIC] - FOLLOW_REACHED - Healing and resuming patrol");
  .cure;
  -target_reached(T);
  -following;
  -ally_position(_);
  +seeding;
  ?patroll_point(P);
  ?control_points(C);
  .nth(P, C, Next);
  .goto(Next).

// ----------------------------------------------------------
// COMBAT
// ----------------------------------------------------------

// Retreat mode: only minimal self-defense
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : retreating
  <-
  .print("LOG: [MEDIC] - RETREAT_CONTACT - Enemy=", ID);
  .look_at(Position);
  if (Distance < 20) {
    .shoot(1, Position);
  }.

// If following an ally and combat appears, heal and provide short fire support
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : following & ally_position(_)
  <-
  .print("LOG: [MEDIC] - SUPPORT_CONTACT - Enemy near followed ally");
  .look_at(Position);
  if (Distance < 25) {
    .cure;
  }
  .shoot(2, Position).

// While advancing normally, shoot cautiously
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : seeding & not retreating
  <-
  .print("LOG: [MEDIC] - ADVANCE_CONTACT - Enemy=", ID);
  .look_at(Position);
  if (Distance < 20) {
    .cure;
  }
  .shoot(2, Position).

// ----------------------------------------------------------
// AXIS PATROL / SEEDING
// ----------------------------------------------------------

+patroll_point(P): team(200) & total_control_points(T) & P < T & seeding & not retreating & not following
  <-
  .print("LOG: [MEDIC] - PATROL_MOVE - Point ", P, "/", T);
  ?control_points(C);
  .nth(P, C, A);
  .goto(A).

+patroll_point(P): team(200) & total_control_points(T) & P >= T & seeding
  <-
  .print("LOG: [MEDIC] - PATROL_RESET");
  -patroll_point(P);
  +patroll_point(0).

+target_reached(T): seeding & team(200) & not retreating
  <-
  ?seed_step(S);
  ?patroll_point(P);
  .print("LOG: [MEDIC] - PATROL_REACHED - Step=", S, " Point=", P);
  if (S mod 2 == 0) {
    .cure;
  }
  -+seed_step(S + 1);
  -+patroll_point(P + 1);
  -target_reached(T).

// ----------------------------------------------------------
// ALLIED ADVANCE / SEEDING
// ----------------------------------------------------------

// If the medic reaches the objective area and is not carrying the flag,
// stay active there and keep scanning instead of overcomplicating movement.
+target_reached(T): seeding & team(100) & not retreating
  <-
  ?seed_step(S);
  .print("LOG: [MEDIC] - OBJECTIVE_AREA - Step=", S);
  if (S mod 2 == 0) {
    .cure;
  }
  -+seed_step(S + 1);
  .turn(0.5);
  -target_reached(T).

// If THIS medic picks the flag, return to base
+flag_taken: team(100)
  <-
  .print("LOG: [MEDIC] - FLAG_TAKEN - Returning to base");
  -seeding;
  -following;
  -ally_position(_);
  ?base(B);
  .goto(B).