// ============================================================
// AGENT BDI FIELDOPS — Pas Incremental 6: Esdeveniments de Bandera
// ============================================================
//   Comportament 1: Autopreservació (monitoratge de salut + retirada)
//   Comportament 2: Suport de Combat Intel·ligent (seguiment d'aliats en combat actiu)
//   Comportament 3: Sembra Estratègica (distribució de munició per equip)
//   Comportament 4: Gestió de Recursos (filtre de llançament + cooldown)
//   Comportament 5: Matriu de Resposta de Combat (lògica de tir per estat)
//   Comportament 6: Esdeveniments de Bandera (escorta + defensa)
//
// ============================================================

// ----------------------------------------------------------
// INICIALITZACIÓ
// ----------------------------------------------------------

// EQUIP_AXIS (200) — configurar punts de control i començar la patrulla
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

// EQUIP_ALLIED (100) — avançar cap a la bandera enemiga
+flag(F): team(100)
  <-
  .print("LOG: [FIELDOPS] INIT - Starting as ALLIED team, objective=", F);
  +objective(F);
  +seed_step(0);
  +seeding;
  +healthy;
  .goto(F).

// ----------------------------------------------------------
// COMPORTAMENT 1: AUTOPRESERVACIÓ
// ----------------------------------------------------------
// Creences: healthy / retreating / seeking_medpack
// Llindars: retirada a < 50 HP, recuperació a >= 80 HP
// Estratègia: buscar medpack proper en lloc d'anar a base
// ----------------------------------------------------------

// Pla 1 — Activar retirada quan la salut baixa de 50
+health(H): H < 50 & healthy
  <-
  .print("LOG: [FIELDOPS] CRITICAL_HEALTH - Health=", H, ", SEEKING MEDPACK");
  -healthy;
  +retreating;
  +seeking_medpack;
  -seeding;
  -following;
  -combat_zone;
  -ally_position(_);
  -escorting;
  -defending;
  -drop_cooldown.

// Pla 1b — Detectar medpack proper quan està retreating
+packs_in_fov(ID, Type, Angle, Distance, Health, Position)
  : Type == 1001 & seeking_medpack & retreating
  <-
  .print("LOG: [FIELDOPS] MEDPACK_FOUND - Health pack at dist=", Distance, ", going for it!");
  -seeking_medpack;
  +going_to_medpack;
  .goto(Position).

// Pla 1c — Si no troba medpack després d'un temps, anar a base com a fallback
+health(H): H < 50 & retreating & seeking_medpack & not going_to_medpack
  <-
  .print("LOG: [FIELDOPS] NO_MEDPACK - No medpack visible, retreating to base as fallback");
  -seeking_medpack;
  ?base(B);
  .goto(B).

// Pla 2 — Recuperació en ruta (p.ex. ha recollit un medpack mentre es retirava)
+health(H): H >= 80 & retreating
  <-
  .print("LOG: [FIELDOPS] HEALTH_RESTORED - Health=", H, ", resuming operations");
  -retreating;
  -seeking_medpack;
  -going_to_medpack;
  +healthy;
  +seeding;
  ?objective(F);
  .goto(F).

// Pla 3 — Ha arribat al medpack i el recull
+target_reached(T): going_to_medpack & retreating
  <-
  .print("LOG: [FIELDOPS] MEDPACK_REACHED - Arrived at medpack location");
  -target_reached(T);
  -going_to_medpack.

// Pla 4 — Ha arribat a la base (fallback si no hi havia medpack)
+target_reached(T): retreating & not going_to_medpack & health(H) & H < 80
  <-
  .print("LOG: [FIELDOPS] BASE_NO_HEALING - Health=", H, ", no healing available. Resuming ops at current HP");
  -target_reached(T);
  -retreating;
  -seeking_medpack;
  +healthy;
  +seeding;
  ?objective(F);
  .goto(F).

// Pla 5 — Ha arribat a la base i s'ha recuperat completament
+target_reached(T): retreating & health(H) & H >= 80
  <-
  .print("LOG: [FIELDOPS] RECOVERED_AT_BASE - Health=", H, ", resuming operations");
  -target_reached(T);
  -retreating;
  -seeking_medpack;
  -going_to_medpack;
  +healthy;
  +seeding;
  ?objective(F);
  .goto(F).

// Pla 6 — Avís de salut moderada (50-69 HP, no crític però debilitat)
+health(H): H < 70 & H >= 50 & healthy
  <-
  .print("LOG: [FIELDOPS] MODERATE_HEALTH - Health=", H, ", playing cautiously").

// ----------------------------------------------------------
// COMPORTAMENT 2: SUPORT DE COMBAT INTEL·LIGENT
// ----------------------------------------------------------
// Només seguir aliats que estiguin en combat ACTIU (enemics < 100 unitats).
// Guards: ha d'estar sa i no en retirada.
// Creences: following / combat_zone / ally_position(Pos)
// ----------------------------------------------------------

// Pla 6 — Entrar en suport de combat: aliat al FOV + enemics a prop
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

// Pla 8 — Combat acabat: aliat visible però ja no hi ha enemics (es comprova ABANS del Pla 14/7)
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

// Pla 14 — Llançament per proximitat en combat: aliat a menys de 30 unitats durant combat actiu
// Filtre: munició > 40, salut >= 70, sense cooldown (Comportament 4)
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

// Pla 7 — Actualitzar seguiment d'aliat: encara en combat, l'aliat s'ha mogut
+friends_in_fov(FriendID, Type, Angle, Distance, Health, FriendPos)
  : following & combat_zone
  <-
  .print("LOG: [FIELDOPS] COMBAT_TRACK - Updating ally ID=", FriendID, " position to ", FriendPos);
  -ally_position(_);
  +ally_position(FriendPos);
  .look_at(FriendPos);
  .goto(FriendPos).

// ----------------------------------------------------------
// TARGET_REACHED mentre segueix un aliat (del Comportament 2)
// ----------------------------------------------------------

// Pla 9 — Ha arribat a la posició de l'aliat mentre el seguia: reprèn sembra
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
// COMPORTAMENT 3: SEEDING ESTRATÈGIC 
// ----------------------------------------------------------
// Distribució de munició per equip durant la patrulla.
// AXIS (200): llançar munició a cada punt de control per crear una línia de subministrament.
// ALLIED (100): llançar munició cada 2 waypoints per conservar energia.
// Filtre: .reload requereix tots els següents:
//   - ammo(A) > 40 (mantenir 40% de reserva d'autodefensa)
//   - health(H) >= 70 (sense llançaments amb salut moderada — prioritzar evasió)
//   - not drop_cooldown (un llançament per cicle de destinació)
// Actiu només en estat de seeding (no en retirada, no seguint aliat).
// ----------------------------------------------------------

// === AXIS (Equip 200) — Línia de subministrament per punts de control ===

// Pla 10 — Sembra AXIS: arriba al punt de control, llança munició condicionalment, avança
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

// Pla 11 — Seeding AXIS: poca munició, no llança però continua patrullant
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

// === ALLIED (Equip 100) — Avanç eficient amb llançaments ===

// Pla 12 — Seeding ALLIED: arriba al waypoint, llança munició cada 2 passos si el filtre ho permet
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

// Pla 13 — Seeding ALLIED: poca munició, avança sense llançar
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
// COMPORTAMENT 5: MATRIU DE RESPOSTA DE COMBAT
// ----------------------------------------------------------
// Lògica de tir basada en l'estat, activada per enemies_in_fov.
// Ordre dels plans = prioritat.
// ----------------------------------------------------------

// Pla 15 — Retirada: tir contra enemic proper
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : retreating & Dist < 30 & ammo(A) & A > 5
  <-
  .print("LOG: [FIELDOPS] RETREAT_FIRE - Enemy ID=", EID, " at dist=", Dist, ", firing 1 deterrent bullet");
  .look_at(EnemyPos);
  .shoot(5, EnemyPos).

// Pla 20 — Últim recurs
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : ammo(A) & A <= 5 & Dist < 15
  <-
  .print("LOG: [FIELDOPS] LAST_RESORT - Enemy ID=", EID, " at dist=", Dist, ", ammo=", A, ", emergency shot");
  .look_at(EnemyPos);
  .shoot(5, EnemyPos).

// Pla 16 — Ignorar en retirada: enemic massa lluny per preocupar-se
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : retreating
  <-
  .print("LOG: [FIELDOPS] RETREAT_IGNORE - Enemy ID=", EID, " at dist=", Dist, ", ignoring (fleeing to base)").

// Pla 17 — No disparar entre 50-69 HP
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : healthy & health(H) & H < 70 & H >= 50
  <-
  .print("LOG: [FIELDOPS] MODERATE_AVOID - Enemy ID=", EID, " at dist=", Dist, ", Health=", H, ", avoiding combat").

// Pla 18 — Combat amb aliat: foc ofensiu.
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : following & combat_zone & ammo(A) & A > 5
  <-
  .print("LOG: [FIELDOPS] COMBAT_FIRE - Enemy ID=", EID, " at dist=", Dist, ", firing 3 offensive bullets");
  .look_at(EnemyPos);
  .shoot(5, EnemyPos).

// Pla 19 — Disparar i continuar movent-se
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : seeding & healthy & ammo(A) & A > 5
  <-
  .print("LOG: [FIELDOPS] CAUTIOUS_FIRE - Enemy ID=", EID, " at dist=", Dist, ", firing 2 cautious bullets");
  .look_at(EnemyPos);
  .shoot(5, EnemyPos).

// ----------------------------------------------------------
// COMPORTAMENT 6: ESDEVENIMENTS DE BANDERA
// ----------------------------------------------------------
// Escorta (ALLIED) i Defensa (AXIS) activades per captura de bandera.
// +flag_taken s'activa quan es captura la bandera; -flag_taken quan es retorna.
// ALLIED: escortar el portador de la bandera cap a casa (anar a la base, llançar munició).
// AXIS: defensar la base contra el lladre de la bandera (anar a la base, interceptar).
// ----------------------------------------------------------

// === ALLIED (Equip 100) — Mode Escorta ===

// Pla 21 — Bandera capturada ALLIED: entrar en mode escorta
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

// Pla 22 — Bandera retornada/perduda ALLIED: sortir d'escorta, reprendre seeding
-flag_taken: escorting
  <-
  .print("LOG: [FIELDOPS] FLAG_RETURNED - Flag dropped/returned, resuming seeding operations");
  -escorting;
  +seeding;
  ?objective(F);
  .goto(F).

// Pla 23 — Escorta ALLIED: ha arribat a la base, llançar munició pel portador, mantenir posició
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

// === AXIS (Equip 200) — Mode Defensa ===

// Pla 24 — Bandera robada AXIS: entrar en mode defensa
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

// Pla 25 — Bandera recuperada AXIS: sortir de defensa, reprendre seeding
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

// Pla 26 — Defensa AXIS: ha arribat a la base, llançar munició pels defensors, mantenir posició
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

// === Resposta de Combat durant Esdeveniments de Bandera ===

// Pla 27 — Combat en escorta: foc mentre protegeix la ruta del portador
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : escorting & healthy & ammo(A) & A > 5
  <-
  .print("LOG: [FIELDOPS] ESCORT_FIRE - Enemy ID=", EID, " at dist=", Dist, ", firing 2 protective bullets");
  .look_at(EnemyPos);
  .shoot(5, EnemyPos).

// Pla 28 — Combat en defensa: foc per interceptar el lladre de la bandera
+enemies_in_fov(EID, Type, Angle, Dist, Health, EnemyPos)
  : defending & healthy & ammo(A) & A > 5
  <-
  .print("LOG: [FIELDOPS] DEFEND_FIRE - Enemy ID=", EID, " at dist=", Dist, ", firing 3 interception bullets");
  .look_at(EnemyPos);
  .shoot(5, EnemyPos).