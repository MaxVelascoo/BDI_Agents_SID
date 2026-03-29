/* =========================================================
   SOLDADO SIMPLE Y AGRESIVO
   - Shoot siempre de 5
   - Si tiene poca vida, el medpack es prioridad absoluta
   - No vuelve a base salvo si lleva la bandera
   - No persigue enemigos normales
   - Si roban la bandera AXIS, persigue al carrier
   ========================================================= */

/* ---------------- INICIALIZACION ---------------- */

+flag(F): team(100)
<-
    .print("[SOLDIER] INIT ALLIED");
    +engage_count(0);
    .create_control_points(F, 18, 2, C);
    +move_points(C);
    +move_idx(0);
    !resume_move.

+flag(F): team(200)
<-
    .print("[SOLDIER] INIT AXIS");
    +engage_count(0);
    .create_control_points(F, 10, 3, C);
    +move_points(C);
    +move_idx(0);
    !resume_move.

/* ---------------- VIDA / MEDPACK ---------------- */

/* Entrar en modo crítico */
+health(H): H < 45 & not low_health
<-
    .print("[SOLDIER] LOW HEALTH");
    +low_health;
    +seeking_medpack;
    -target_enemy(_,_,_);
    -chasing_carrier;
    .stop;
    !seek_medpack.

/* Recuperado */
+health(H): H >= 75 & low_health
<-
    .print("[SOLDIER] RECOVERED");
    -low_health;
    -seeking_medpack;
    !resume_move.

/* Si recoge medpack, sale del modo crítico */
+pack_taken(1001,_): low_health
<-
    .print("[SOLDIER] MEDPACK TAKEN");
    -low_health;
    -seeking_medpack;
    !resume_move.

/* Si está tocado pero no crítico y ve un medpack muy cercano, lo aprovecha */
+health(H): H < 70 & H >= 45 & not low_health & packs_in_fov(_,1001,_,Dist,_,PackPos) & Dist < 15
<-
    .print("[SOLDIER] MID HEALTH -> MEDPACK");
    .stop;
    .goto(PackPos).

/* Buscar medpack: prioridad absoluta */
+!seek_medpack: low_health & packs_in_fov(_,1001,_,Dist,_,PackPos) & Dist < 35
<-
    .print("[SOLDIER] GO MEDPACK");
    .stop;
    .goto(PackPos).

/* Si aparece un medpack mientras está crítico, ir inmediatamente */
+packs_in_fov(_,1001,_,Dist,_,PackPos): low_health & seeking_medpack & Dist < 35
<-
    .print("[SOLDIER] MEDPACK SEEN");
    .stop;
    .goto(PackPos).

/* Si está crítico y no ve medpack, se recoloca en modo defensivo */
+!seek_medpack: low_health
<-
    .print("[SOLDIER] LOW HEALTH HOLD");
    ?flag(F);
    .stop;
    .look_at(F).

/* ---------------- BANDERA ---------------- */

+flag_taken: team(100) & not low_health
<-
    .print("[SOLDIER] FLAG TAKEN -> RETURN");
    +returning;
    -target_enemy(_,_,_);
    -chasing_carrier;
    -seeking_medpack;
    .stop;
    ?base(B);
    .goto(B).

+flag_taken: team(200) & not low_health
<-
    .print("[SOLDIER] FLAG STOLEN -> CHASE CARRIER");
    +defending;
    +chasing_carrier;
    -target_enemy(_,_,_);
    .stop;
    ?flag(F);
    .goto(F);
    .look_at(F).

/* ---------------- COMBATE EN LOW HEALTH ---------------- */

/* Si está crítico y hay medpack cerca, SIEMPRE manda el medpack */
+enemies_in_fov(ID,Type,Angle,Dist,HP,Pos): low_health & seeking_medpack & packs_in_fov(_,1001,_,PDist,_,PackPos) & PDist < 35
<-
    .print("[SOLDIER] LOW HEALTH -> IGNORE COMBAT, GO MEDPACK");
    -target_enemy(_,_,_);
    .stop;
    .goto(PackPos).

/* Si está crítico y no hay medpack, solo dispara si el enemigo está muy cerca */
+enemies_in_fov(ID,Type,Angle,Dist,HP,Pos): low_health & seeking_medpack & Dist <= 4
<-
    .print("[SOLDIER] LOW HEALTH EMERGENCY FIRE");
    .stop;
    .look_at(Pos);
    .shoot(5,Pos).

/* Si está crítico y el enemigo no está pegado, no combate: sigue buscando medpack */
+enemies_in_fov(ID,Type,Angle,Dist,HP,Pos): low_health & seeking_medpack & Dist > 4
<-
    .print("[SOLDIER] LOW HEALTH IGNORE ENEMY");
    !seek_medpack.

/* ---------------- PERSECUCION DEL CARRIER ---------------- */

+enemies_in_fov(ID,Type,Angle,Dist,HP,Pos): chasing_carrier & not low_health & not target_enemy(_,_,_)
<-
    .print("[SOLDIER] CARRIER TARGET ACQUIRED");
    .stop;
    +target_enemy(ID,Pos,HP);
    .look_at(Pos);
    .goto(Pos);
    .shoot(5,Pos).

+enemies_in_fov(ID,Type,Angle,Dist,HP,Pos): chasing_carrier & not low_health & target_enemy(ID,_,_)
<-
    -target_enemy(ID,_,_);
    +target_enemy(ID,Pos,HP);
    .print("[SOLDIER] CHASE CARRIER FIRE");
    .look_at(Pos);
    .goto(Pos);
    .shoot(5,Pos).

+enemies_in_fov(ID,Type,Angle,Dist,HP,Pos): chasing_carrier & not low_health & target_enemy(TID,_,TH) & ID \== TID & HP < TH
<-
    .print("[SOLDIER] SWITCH CHASE TARGET");
    -target_enemy(_,_,_);
    +target_enemy(ID,Pos,HP);
    .look_at(Pos);
    .goto(Pos);
    .shoot(5,Pos).

/* ---------------- COMBATE NORMAL ---------------- */

/* Override si hay enemigo pegado */
+enemies_in_fov(ID,Type,Angle,Dist,HP,Pos): not low_health & Dist <= 6
<-
    .print("[SOLDIER] CLOSE TARGET OVERRIDE");
    -target_enemy(_,_,_);
    .stop;
    +target_enemy(ID,Pos,HP);
    .look_at(Pos);
    .shoot(5,Pos).

/* Defensa normal */
+enemies_in_fov(ID,Type,Angle,Dist,HP,Pos): defending & not chasing_carrier & not low_health & not target_enemy(_,_,_)
<-
    .print("[SOLDIER] DEFEND TARGET");
    .stop;
    +target_enemy(ID,Pos,HP);
    .look_at(Pos);
    .shoot(5,Pos).

/* Si no tiene target y ve enemigo */
+enemies_in_fov(ID,Type,Angle,Dist,HP,Pos): not low_health & not returning & not chasing_carrier & not seeking_medpack & not target_enemy(_,_,_)
<-
    .print("[SOLDIER] TARGET ACQUIRED");
    .stop;
    +target_enemy(ID,Pos,HP);
    ?engage_count(N);
    N2 = N + 1;
    -engage_count(N);
    +engage_count(N2);
    if (N2 >= 2) { +cleared_enough; };
    .look_at(Pos);
    .shoot(5,Pos).

/* Mantener target */
+enemies_in_fov(ID,Type,Angle,Dist,HP,Pos): not low_health & not chasing_carrier & target_enemy(ID,_,_)
<-
    -target_enemy(ID,_,_);
    +target_enemy(ID,Pos,HP);
    .print("[SOLDIER] FIRE");
    .stop;
    .look_at(Pos);
    .shoot(5,Pos).

/* Si vuelve con bandera */
+enemies_in_fov(ID,Type,Angle,Dist,HP,Pos): returning & not low_health
<-
    .print("[SOLDIER] RETURNING FIRE");
    .look_at(Pos);
    .shoot(5,Pos).

/* ---------------- LIMPIEZA DE TARGET ---------------- */

+target_reached(T): chasing_carrier & target_enemy(_,_,_) & not low_health
<-
    .print("[SOLDIER] LOST CARRIER -> SEARCH FLAG");
    -target_enemy(_,_,_);
    ?flag(F);
    .goto(F);
    .look_at(F).

+target_reached(T): defending & target_enemy(_,_,_) & not chasing_carrier
<-
    .print("[SOLDIER] DEFENSE CLEAR TARGET");
    -target_enemy(_,_,_);
    ?flag(F);
    .stop;
    .look_at(F).

+target_reached(T): target_enemy(_,_,_) & not returning & not chasing_carrier
<-
    .print("[SOLDIER] CLEAR TARGET");
    -target_enemy(_,_,_);
    !resume_move.

/* Si ha llegado a donde cree que está el medpack, sigue comprobando si puede coger más/esperar */
+target_reached(T): low_health & seeking_medpack
<-
    .print("[SOLDIER] MEDPACK POSITION REACHED");
    !seek_medpack.

/* ---------------- MOVIMIENTO NORMAL ---------------- */

+!resume_move: low_health
<-
    !seek_medpack.

+!resume_move: returning
<-
    ?base(B);
    .goto(B).

+!resume_move: team(200) & chasing_carrier & not target_enemy(_,_,_) & not low_health
<-
    .print("[SOLDIER] SEARCH CARRIER");
    ?flag(F);
    .goto(F);
    .look_at(F).

+!resume_move: team(200) & defending & not chasing_carrier & not target_enemy(_,_,_) & not low_health
<-
    ?flag(F);
    .goto(F);
    .look_at(F).

+!resume_move: team(100) & cleared_enough & not returning & not target_enemy(_,_,_) & not low_health
<-
    .print("[SOLDIER] GO FLAG");
    ?flag(F);
    .goto(F).

+!resume_move: team(100) & not cleared_enough & move_points(C) & move_idx(I) & not returning & not target_enemy(_,_,_) & not low_health
<-
    .nth(I,C,P);
    .print("[SOLDIER] ADVANCE");
    .goto(P).

+!resume_move: team(200) & move_points(C) & move_idx(I) & not defending & not chasing_carrier & not target_enemy(_,_,_) & not low_health
<-
    .nth(I,C,P);
    .print("[SOLDIER] PATROL");
    .goto(P).

+target_reached(T): move_points(C) & move_idx(I) & not target_enemy(_,_,_) & not returning & not low_health & not chasing_carrier
<-
    .length(C,L);
    I1 = I + 1;
    if (I1 < L) {
        I2 = I1;
    } else {
        I2 = 0;
    };
    -move_idx(I);
    +move_idx(I2);
    ?flag(F);
    .look_at(F);
    !resume_move.

+target_reached(T): defending & not chasing_carrier & not target_enemy(_,_,_) & not low_health
<-
    ?flag(F);
    .stop;
    .look_at(F).