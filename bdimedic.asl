// Medic BDI - Soporte médico
// Movilidad constante, curación táctica, supervivencia prioritaria

// Init AXIS
+flag(F): team(200)
  <-
  .print("LOG: [MEDIC] INIT AXIS");
  +objective(F);
  .create_control_points(F, 25, 3, C);
  +control_points(C);
  .length(C, L);
  +total_control_points(L);
  +seed_step(0);
  +seeding;
  +healthy;
  +patroll_point(0).

// Init ALLIED
+flag(F): team(100)
  <-
  .print("LOG: [MEDIC] INIT ALLIED");
  +objective(F);
  +seed_step(0);
  +seeding;
  +healthy;
  .goto(F).

// Salud crítica
+health(H): H < 45 & healthy
  <-
  .print("LOG: [MEDIC] RETREAT HP=", H);
  -healthy;
  -seeding;
  -following;
  -ally_position(_);
  +retreating;
  ?base(B);
  .goto(B).

+health(H): H >= 80 & retreating & team(100)
  <-
  .print("LOG: [MEDIC] RECOVERED");
  -retreating;
  +healthy;
  +seeding;
  ?objective(F);
  .goto(F).

+health(H): H >= 80 & retreating & team(200)
  <-
  .print("LOG: [MEDIC] RECOVERED");
  -retreating;
  +healthy;
  +seeding;
  ?patroll_point(P);
  ?control_points(C);
  .nth(P, C, Next);
  .goto(Next).

+target_reached(T): retreating
  <-
  .print("LOG: [MEDIC] BASE_REACHED");
  -target_reached(T).

// Seguir aliados heridos
+friends_in_fov(ID, Type, Angle, Distance, Health, Position)
  : seeding & not retreating & not following & Distance < 35 & Health < 70
  <-
  .print("LOG: [MEDIC] FOLLOW_START HP=", Health);
  -seeding;
  +following;
  -ally_position(_);
  +ally_position(Position);
  .goto(Position).

+friends_in_fov(ID, Type, Angle, Distance, Health, Position)
  : following & Distance < 45 & Health < 80
  <-
  .print("LOG: [MEDIC] FOLLOW_UPDATE HP=", Health);
  -ally_position(_);
  +ally_position(Position);
  .goto(Position).

+target_reached(T): following & team(100)
  <-
  .print("LOG: [MEDIC] HEAL_ALLY");
  .cure;
  -target_reached(T);
  -following;
  -ally_position(_);
  +seeding;
  ?objective(F);
  .goto(F).

+target_reached(T): following & team(200)
  <-
  .print("LOG: [MEDIC] HEAL_ALLY");
  .cure;
  -target_reached(T);
  -following;
  -ally_position(_);
  +seeding;
  ?patroll_point(P);
  ?control_points(C);
  .nth(P, C, Next);
  .goto(Next).

// Combate
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : not retreating & Distance <= 6
  <-
  .print("LOG: [MEDIC] CLOSE_TARGET");
  .stop;
  .look_at(Position);
  .shoot(5, Position).

+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : retreating
  <-
  .print("LOG: [MEDIC] RETREAT_FIRE");
  .stop;
  .look_at(Position);
  if (Distance < 20) {
    .shoot(5, Position);
  }.

+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : following & ally_position(_)
  <-
  .print("LOG: [MEDIC] SUPPORT_FIRE");
  .stop;
  .look_at(Position);
  if (Distance < 25) {
    .cure;
  }
  .shoot(5, Position).

+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : seeding & not retreating
  <-
  .print("LOG: [MEDIC] ADVANCE_FIRE");
  .stop;
  .look_at(Position);
  if (Distance < 20) {
    .cure;
  }
  .shoot(5, Position).

// Patrulla AXIS
+patroll_point(P): team(200) & total_control_points(T) & P < T & seeding & not retreating & not following
  <-
  .print("LOG: [MEDIC] PATROL ", P, "/", T);
  ?control_points(C);
  .nth(P, C, A);
  .goto(A).

+patroll_point(P): team(200) & total_control_points(T) & P >= T & seeding
  <-
  .print("LOG: [MEDIC] PATROL_RESET");
  -patroll_point(P);
  +patroll_point(0).

+target_reached(T): seeding & team(200) & not retreating
  <-
  ?seed_step(S);
  ?patroll_point(P);
  .print("LOG: [MEDIC] PATROL_POINT ", P);
  if (S mod 2 == 0) {
    .cure;
  }
  -+seed_step(S + 1);
  -+patroll_point(P + 1);
  -target_reached(T).

// Avance ALLIED
+target_reached(T): seeding & team(100) & not retreating
  <-
  ?seed_step(S);
  .print("LOG: [MEDIC] OBJECTIVE_AREA");
  if (S mod 2 == 0) {
    .cure;
  }
  -+seed_step(S + 1);
  .turn(0.5);
  -target_reached(T).

// Bandera capturada
+flag_taken: team(100)
  <-
  .print("LOG: [MEDIC] FLAG_TAKEN");
  -seeding;
  -following;
  -ally_position(_);
  ?base(B);
  .goto(B).