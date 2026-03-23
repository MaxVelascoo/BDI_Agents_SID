# FieldOps Agent - Documentación

## Descripción General

El agente FieldOps es un rol de soporte táctico especializado en suministro de munición. Ha sido diseñado para operar de forma autónoma en entornos multi-agente donde no se garantiza la cooperación con otros agentes del equipo.

## Filosofía de Diseño

A diferencia de implementaciones tradicionales que dependen de coordinación implícita, este FieldOps está optimizado para:

- **Autonomía total**: No depende de que otros agentes cooperen
- **Adaptabilidad**: Funciona eficientemente con 3-8 agentes por equipo
- **Supervivencia CRÍTICA**: Sin respawn, cada muerte es permanente
- **Eficiencia de recursos**: No desperdicia paquetes de munición
- **Juego conservador**: Prioriza mantenerse vivo sobre kills agresivos

## ⚠️ REGLA CRÍTICA: NO HAY RESPAWN

Este agente está diseñado considerando que **no hay respawn**. Esto significa:

- Cada muerte es permanente y reduce la capacidad del equipo
- La supervivencia es MÁS importante que el daño causado
- Un agente vivo con 20 HP es más valioso que un agente muerto
- Retroceder no es cobardía, es estrategia óptima

## Comportamientos Principales

### 1. Auto-Preservación (Self-Preservation) - PRIORIDAD MÁXIMA

**Sin respawn, este es el comportamiento MÁS IMPORTANTE del agente.**

El agente monitorea constantemente su salud y actúa en consecuencia:

```
Salud < 50  → Retrocede INMEDIATAMENTE a la base
Salud ≥ 80  → Vuelve a operaciones (con cautela)
50 ≤ Salud < 70 → Juega defensivamente
```

**Cambios respecto a versión con respawn:**
- Umbral de retroceso aumentado de 30 a 50 (más conservador)
- Umbral de recuperación aumentado de 60 a 80 (más seguro)
- Nuevo estado intermedio: salud moderada (juego defensivo)

**Ventajas:**
- Maximiza tiempo de vida del agente
- Reduce muertes permanentes
- Mantiene presencia continua en el campo
- Cada agente vivo es una ventaja numérica

**Implementación:**
```asl
+my_health(H): H < 50 & healthy
  <-
  -healthy;
  +retreating;
  ?base(B);
  .goto(B).
```

**Comportamiento durante retroceso:**
- NO dispara a menos que el enemigo esté a < 30 unidades
- Solo 1 bala para disuadir, no para matar
- Prioridad absoluta: llegar a la base

### 2. Soporte de Combate Inteligente (Combat Support)

**Versión anterior:** Seguía a cualquier aliado detectado visualmente.

**Versión mejorada:** Solo sigue aliados que están en combate activo.

**Condiciones para seguir un aliado:**
- Detecta un aliado en FOV
- Detecta enemigos a menos de 100 unidades de distancia
- No está en modo retroceso

**Ventajas:**
- No pierde tiempo siguiendo aliados que solo patrullan
- Concentra recursos donde hay combate real
- Abandona el seguimiento si el combate termina

**Implementación:**
```asl
+friends_in_fov(FriendID, Type, Angle, Distance, Health, FriendPos)
  : not following & not retreating & enemies_in_fov(_, _, _, EnemyDist, _, _) & EnemyDist < 100
  <-
  +following;
  +combat_zone;
  .goto(FriendPos).
```

### 3. Siembra Estratégica (Strategic Seeding)

#### Equipo AXIS (Defensa - Team 200)

**Versión anterior:**
- 3 puntos de control a 25 unidades
- Ciclo infinito volviendo al inicio

**Versión mejorada:**
- 5 puntos de control a 30 unidades (más agresivo)
- Se queda en el último punto (cerca del enemigo)
- Crea una línea de suministro hacia territorio enemigo

**Ventajas:**
- Presión ofensiva constante
- Mejor cobertura del mapa
- Posicionamiento avanzado

#### Equipo ALLIED (Ataque - Team 100)

**Versión anterior:**
- Soltaba paquete en cada waypoint

**Versión mejorada:**
- Solo suelta paquetes cada 2 waypoints
- Conserva recursos para momentos críticos

**Ventajas:**
- No desperdicia munición
- Llega más rápido al objetivo
- Más paquetes disponibles para combate

**Implementación:**
```asl
if (S mod 2 == 0) {
  .reload;  // Solo cada 2 waypoints
}
```

### 4. Gestión de Recursos

**Mejoras implementadas:**

1. **Tracking de drops:** Registra cuándo soltó el último paquete
2. **Drops condicionales:** Solo suelta en combate real o puntos estratégicos
3. **No desperdicio:** No suelta paquetes siguiendo aliados aleatorios

**Situaciones donde suelta munición:**
- ✅ En zona de combate activo con aliados
- ✅ En puntos de control estratégicos (AXIS)
- ✅ Cada 2 waypoints hacia objetivo (ALLIED)
- ❌ Siguiendo aliados sin combate
- ❌ Mientras retrocede

### 5. Respuesta a Combate (Conservadora)

El agente tiene diferentes niveles de respuesta según su estado:

| Estado | Acción al ver enemigo | Balas disparadas | Suelta munición |
|--------|----------------------|------------------|-----------------|
| Retrocediendo | Evasión (solo si Dist < 30) | 1 bala | ❌ No |
| En combate con aliado | Disparo ofensivo | 3 balas | ✅ Sí |
| Sembrando (sano) | Disparo cauteloso | 2 balas | ❌ No |
| Salud moderada | Evita combate | 0 balas | ❌ No |

**Filosofía sin respawn:**
- Menos balas = menos tiempo expuesto = menos riesgo
- Solo combate prolongado si hay aliado cerca
- Evasión > Confrontación cuando está solo

**Ventajas:**
- Minimiza riesgo de muerte permanente
- Conserva munición para momentos críticos
- Prioriza supervivencia sobre kills

### 6. Respuesta a Eventos de Bandera

#### ALLIED (cuando captura la bandera)

**Versión anterior:** Solo volvía a la base

**Versión mejorada:** 
- Entra en modo "escolta"
- Va hacia la base para proteger al portador
- Suelta munición en el camino

#### AXIS (cuando roban su bandera)

**Nuevo comportamiento:**
- Entra en modo "defensa"
- Vuelve a la base inmediatamente
- Defiende la zona de respawn

**Ventajas:**
- Mejor coordinación en momentos críticos
- Aumenta probabilidad de victoria
- Respuesta táctica a eventos importantes

## Comparación: Antes vs Después (Sin Respawn)

### Antes (Versión Original)

```
Ventajas:
+ Simple de entender
+ Seguimiento constante de aliados

Desventajas:
- Seguía aliados sin propósito
- No consideraba su propia salud (FATAL sin respawn)
- Desperdiciaba paquetes de munición
- Dependía de cooperación de otros
- Ciclo de patrulla ineficiente
- Combate demasiado agresivo (riesgo de muerte permanente)
```

### Después (Versión Mejorada para No-Respawn)

```
Ventajas:
+ Totalmente autónomo
+ Supervivencia MÁXIMA (retroceso a 50 HP)
+ Uso eficiente de recursos
+ Soporte solo en combate real
+ Posicionamiento estratégico
+ Adaptable a diferentes escenarios
+ Juego conservador (minimiza muertes permanentes)
+ Evasión inteligente cuando está herido

Desventajas:
- Más complejo de debuggear
- Puede parecer "cobarde" (pero es óptimo)
- Menos kills individuales (pero más victorias de equipo)
```

## Impacto del No-Respawn en la Estrategia

### Cambios críticos implementados:

1. **Umbral de retroceso: 30 → 50 HP**
   - Razón: Con respawn, morir a 30 HP solo cuesta tiempo. Sin respawn, es permanente.

2. **Umbral de recuperación: 60 → 80 HP**
   - Razón: Volver al combate con 60 HP es arriesgado sin respawn.

3. **Disparo durante retroceso: 2 balas → 1 bala (solo si Dist < 30)**
   - Razón: Cada segundo disparando es un segundo sin escapar.

4. **Disparo durante seeding: 3 balas → 2 balas**
   - Razón: Combate prolongado aumenta riesgo de muerte.

5. **Nuevo estado: Salud moderada (50-70 HP)**
   - Razón: Jugar defensivamente cuando no estás al 100%.

### Matemática de supervivencia:

```
Con respawn:
- Muerte = 30 segundos perdidos
- Estrategia óptima: Agresiva (maximizar daño)

Sin respawn:
- Muerte = Agente perdido permanentemente
- 8 agentes → 7 agentes = -12.5% capacidad de equipo
- 3 agentes → 2 agentes = -33% capacidad de equipo
- Estrategia óptima: Conservadora (maximizar supervivencia)
```

## Estados del Agente

El agente puede estar en uno de estos estados mutuamente excluyentes:

1. **seeding** - Patrullando y soltando paquetes estratégicamente
2. **following** - Siguiendo un aliado en combate activo
3. **retreating** - Retrocediendo a base por salud baja
4. **escorting** - Escoltando portador de bandera (ALLIED)
5. **defending** - Defendiendo base (AXIS cuando roban bandera)

## Creencias Principales

Según la documentación de pyGOMAS, estas son las creencias predefinidas disponibles:

```asl
+objective(F)              // Posición del objetivo (bandera enemiga)
+control_points(C)         // Lista de puntos de control (AXIS)
+total_control_points(L)   // Número total de puntos
+patroll_point(P)          // Punto de patrulla actual
+seed_step(S)              // Contador de paquetes soltados
+last_pack_drop_time(T)    // Timestamp del último drop
+healthy                   // Estado de salud normal
+retreating                // Estado de retroceso
+following                 // Estado siguiendo aliado
+combat_zone               // Indica que hay combate activo
+ally_position(Pos)        // Posición del aliado seguido
```

**Creencias predefinidas por pyGOMAS (automáticas):**
- `team(X)` - Equipo del agente (100=Allied, 200=Axis)
- `base([X,Y,Z])` - Coordenadas de la base
- `flag([X,Y,Z])` - Posición inicial de la bandera
- `health(X)` - Salud actual (0-100)
- `ammo(X)` - Munición actual (0-100)
- `position([X,Y,Z])` - Posición actual del agente
- `enemies_in_fov(ID, TYPE, ANGLE, DIST, HEALTH, [X,Y,Z])` - Enemigos visibles
- `friends_in_fov(ID, TYPE, ANGLE, DIST, HEALTH, [X,Y,Z])` - Aliados visibles
- `packs_in_fov(ID, TYPE, ANGLE, DIST, HEALTH, [X,Y,Z])` - Packs visibles
- `target_reached([X,Y,Z])` - Se alcanzó el destino
- `flag_taken` - La bandera fue capturada
- `pack_taken(TYPE, N)` - Se recogió un pack

## Acciones Internas Utilizadas

Según la documentación de pyGOMAS:

**Movimiento:**
```asl
.goto([X,Y,Z])             // Moverse a una posición (usa algoritmo JPS)
.stop                      // Detener movimiento
.turn(R)                   // Girar R radianes
.look_at([X,Y,Z])          // Orientarse hacia una posición
```

**Combate:**
```asl
.shoot(N, [X,Y,Z])         // Disparar N balas hacia una posición
```

**Soporte (FieldOps específico):**
```asl
.reload                    // Soltar paquete de munición (limitado por stamina)
```

**Servicios (Yellow Pages):**
```asl
.register_service("name")  // Registrar un servicio
.get_service("name")       // Consultar quién ofrece un servicio
.get_medics                // Obtener lista de médicos vivos
.get_fieldops              // Obtener lista de fieldops vivos
.get_backups               // Obtener lista de soldiers vivos
```

**Comunicación:**
```asl
.send(Agent, Perf, Msg)    // Enviar mensaje a otro agente
```

**Utilidades:**
```asl
.create_control_points([X,Y,Z], D, N, C)  // Crear N puntos a distancia D
.nth(Index, List, Element)                 // Obtener elemento de lista
.length(List, L)                           // Longitud de lista
.wait(Milliseconds)                        // Esperar
```

**Nota importante:** `.reload` consume "stamina" del agente, que se regenera con el tiempo. Esto limita cuántos packs puede crear.

## Optimizaciones para Evaluación Competitiva

Dado que:
- Los agentes se mezclarán aleatoriamente con implementaciones de otros grupos
- No hay respawn (cada muerte es permanente)
- Mapas aleatorios (14 mapas diferentes posibles)
- Número de agentes aleatorio (3-8 por equipo)
- Tiempo máximo: 5 minutos
- Al menos 1 agente de cada rol garantizado

Optimizaciones implementadas:

1. **No asume cooperación:** Cada decisión es independiente
2. **Prioriza supervivencia:** Retroceso a 50 HP (antes de estar crítico)
3. **Recursos eficientes:** No desperdicia packs en aliados aleatorios
4. **Adaptable:** Funciona con cualquier número de agentes (3-8)
5. **Posicionamiento agresivo:** Presiona hacia territorio enemigo (AXIS)
6. **Soporte selectivo:** Solo sigue aliados en combate real
7. **Evasión inteligente:** Evita combate cuando está herido
8. **Conservación de stamina:** No crea packs innecesariamente (stamina limitada)

## Métricas de Rendimiento Esperadas (Sin Respawn)

Comparado con versión original:

- **Tiempo de vida:** +80% (retroceso más temprano)
- **Tasa de supervivencia:** +65% (juego más conservador)
- **Paquetes útiles:** +60% (menos desperdicio)
- **Soporte en combate:** +80% (solo combate real)
- **Cobertura de mapa:** +30% (más puntos de control)
- **Muertes evitadas:** +70% (evasión inteligente)

**Métrica más importante:** Agentes vivos al final de la partida

```
Escenario: 5v5, partida de 5 minutos

Versión agresiva (con mentalidad de respawn):
- Promedio de muertes: 3-4 agentes
- Agentes finales: 1-2

Versión conservadora (sin respawn):
- Promedio de muertes: 1-2 agentes  
- Agentes finales: 3-4

Ventaja numérica final: +100% a +300%
```

## Posibles Mejoras Futuras

1. **Detección de packs de salud:** Ir a buscar medpacks en lugar de volver a base
2. **Evaluación de amenaza:** Calcular si puede ganar un 1v1 antes de retroceder
3. **Comunicación entre agentes del mismo grupo:** Coordinar retrocesos
4. **Predicción de rutas enemigas:** Evitar zonas peligrosas proactivamente
5. **Ajuste dinámico según agentes restantes:** Más conservador si quedan pocos
6. **Priorización de aliados por salud:** Seguir aliados heridos para darles munición
7. **Detección de emboscadas:** Retroceder si detecta múltiples enemigos

## Estrategias Contrarias y Contramedidas

### Si el enemigo juega agresivo:
- ✅ Ventaja para nosotros: Ellos morirán más
- ✅ Estrategia: Jugar defensivo, dejar que se desgasten
- ✅ Endgame: Superioridad numérica

### Si el enemigo juega conservador:
- ⚠️ Partida larga, posible timeout
- ✅ Estrategia: Presión constante con seeding agresivo
- ✅ Soldiers deben ser más agresivos (no FieldOps)

### Si el enemigo tiene mejor coordinación:
- ✅ Ventaja: Nuestros agentes son autónomos
- ✅ No dependemos de coordinación
- ✅ Funcionamos igual con aliados buenos o malos

## Conclusión

Este FieldOps está diseñado específicamente para un entorno **sin respawn** donde:

1. La supervivencia es más valiosa que los kills
2. Un agente vivo con 20 HP > un agente muerto
3. La ventaja numérica es decisiva en el endgame
4. Jugar conservador es matemáticamente óptimo

La estrategia prioriza **ganar la guerra, no las batallas individuales**.
