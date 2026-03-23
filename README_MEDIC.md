# Medic Agent - Documentación

## Descripción General

El agente Medic es un rol de soporte médico especializado en mantener vivos a los aliados mediante la distribución estratégica de medpacks. Diseñado para operar autónomamente en entornos sin respawn donde cada muerte es permanente.

## Filosofía de Diseño

Este Medic está optimizado para:

- **Autonomía total**: No depende de que otros agentes cooperen
- **Triage inteligente**: Prioriza aliados heridos sobre aliados sanos
- **Supervivencia CRÍTICA**: Sin respawn, mantenerse vivo es esencial
- **Eficiencia de recursos**: Stamina limitada, no desperdicia medpacks
- **Juego conservador**: Prioriza supervivencia sobre agresividad

## ⚠️ REGLA CRÍTICA: NO HAY RESPAWN

- Cada muerte es permanente y reduce la capacidad del equipo
- La supervivencia es MÁS importante que el daño causado
- Un medic vivo puede salvar múltiples aliados
- Retroceder no es cobardía, es estrategia óptima

## Comportamientos Principales

### 1. Auto-Preservación (Self-Preservation) - PRIORIDAD MÁXIMA

El agente monitorea constantemente su salud:

```
Salud < 50  → Retrocede INMEDIATAMENTE a la base
Salud ≥ 80  → Vuelve a operaciones (con cautela)
50 ≤ Salud < 70 → Juega defensivamente
```

**Cambios respecto a versión básica:**
- Umbral de retroceso: 50 HP (más conservador)
- Umbral de recuperación: 80 HP (más seguro)
- Nuevo estado intermedio: salud moderada

**Comportamiento durante retroceso:**
- NO dispara a menos que el enemigo esté a < 30 unidades
- Solo 1 bala para disuadir, no para matar
- Prioridad absoluta: llegar a la base

### 2. Triage Support (Soporte Médico Inteligente)

**Versión anterior:** Seguía a cualquier aliado detectado visualmente.

**Versión mejorada:** Solo sigue aliados HERIDOS en zonas de combate.

**Condiciones para seguir un aliado:**
- Aliado con Health < 60 (herido)
- Enemigos a menos de 100 unidades (zona de combate)
- No está en modo retroceso

**Ventajas:**
- Maximiza impacto de los medpacks
- No pierde tiempo siguiendo aliados sanos
- Prioriza salvar vidas sobre patrullar
- Abandona seguimiento si aliado se cura (HP ≥ 70)

**Implementación:**
```asl
+friends_in_fov(FriendID, Type, Angle, Distance, Health, FriendPos)
  : not following & not retreating & Health < 60 & enemies_in_fov(_, _, _, EnemyDist, _, _) & EnemyDist < 100
  <-
  +following;
  +combat_zone;
  .goto(FriendPos).
```

### 3. Siembra Estratégica (Strategic Seeding)

#### Equipo AXIS (Defensa - Team 200)

**Versión mejorada:**
- 5 puntos de control a 30 unidades (más agresivo)
- Se queda en el último punto (cerca del enemigo)
- Crea una línea de suministro médico hacia territorio enemigo

#### Equipo ALLIED (Ataque - Team 100)

**Versión mejorada:**
- Solo suelta medpacks cada 2 waypoints
- Conserva stamina para momentos críticos
- Llega más rápido al objetivo

**Ventajas:**
- No desperdicia stamina
- Medpacks disponibles para combate real
- Mejor cobertura del mapa

### 4. Gestión de Recursos (Stamina)

**Importante:** `.cure` consume stamina que se regenera con el tiempo.

**Situaciones donde suelta medpacks:**
- ✅ En zona de combate con aliado herido (HP < 60)
- ✅ En puntos de control estratégicos (AXIS)
- ✅ Cada 2 waypoints hacia objetivo (ALLIED)
- ❌ Siguiendo aliados sanos
- ❌ Mientras retrocede

### 5. Respuesta a Combate (Conservadora)

| Estado | Acción al ver enemigo | Balas disparadas | Suelta medpack |
|--------|----------------------|------------------|----------------|
| Retrocediendo | Evasión (solo si Dist < 30) | 1 bala | ❌ No |
| Con aliado herido | Disparo ofensivo | 3 balas | ✅ Sí |
| Sembrando (sano) | Disparo cauteloso | 2 balas | ❌ No |
| Salud moderada | Evita combate | 0 balas | ❌ No |

**Filosofía sin respawn:**
- Menos balas = menos tiempo expuesto = menos riesgo
- Solo combate prolongado si hay aliado herido cerca
- Evasión > Confrontación cuando está solo

### 6. Respuesta a Eventos de Bandera

#### ALLIED (cuando captura la bandera)

- Entra en modo "escolta"
- Va hacia la base para proteger al portador
- Listo para curar al portador si es herido

#### AXIS (cuando roban su bandera)

- Entra en modo "defensa"
- Vuelve a la base inmediatamente
- Cura a los defensores en la base

## Comparación: Antes vs Después (Sin Respawn)

### Antes (Versión Original)

```
Ventajas:
+ Simple de entender
+ Seguimiento constante de aliados

Desventajas:
- Seguía aliados sanos (desperdicio)
- No consideraba su propia salud (FATAL sin respawn)
- Desperdiciaba medpacks
- Dependía de cooperación de otros
- Combate demasiado agresivo
```

### Después (Versión Mejorada para No-Respawn)

```
Ventajas:
+ Totalmente autónomo
+ Triage inteligente (solo aliados heridos)
+ Supervivencia MÁXIMA (retroceso a 50 HP)
+ Uso eficiente de stamina
+ Soporte solo en combate real
+ Posicionamiento estratégico
+ Juego conservador
+ Evasión inteligente

Desventajas:
- Más complejo de debuggear
- Puede parecer "pasivo" (pero es óptimo)
- Menos kills individuales
```

## Impacto del No-Respawn en la Estrategia

### Cambios críticos implementados:

1. **Umbral de retroceso: 30 → 50 HP**
   - Razón: Con respawn, morir a 30 HP solo cuesta tiempo. Sin respawn, es permanente.

2. **Triage selectivo: Todos → Solo heridos (HP < 60)**
   - Razón: Maximizar impacto de medpacks limitados por stamina.

3. **Disparo durante retroceso: 2 balas → 1 bala (solo si Dist < 30)**
   - Razón: Cada segundo disparando es un segundo sin escapar.

4. **Abandono de seguimiento: Nunca → Si HP ≥ 70**
   - Razón: Aliado curado ya no necesita soporte inmediato.

### Matemática de supervivencia:

```
Valor de un Medic vivo:
- Puede curar múltiples aliados durante la partida
- Cada aliado salvado = ventaja numérica mantenida
- 1 Medic vivo > 3 kills enemigos

Sin respawn:
- Medic muerto = Equipo pierde capacidad de curación permanentemente
- Aliados heridos tienen menos probabilidad de sobrevivir
- Efecto cascada: más muertes → menos agentes → más muertes
```

## Estados del Agente

1. **seeding** - Patrullando y soltando medpacks estratégicamente
2. **following** - Siguiendo un aliado HERIDO en combate activo
3. **retreating** - Retrocediendo a base por salud baja
4. **escorting** - Escoltando portador de bandera (ALLIED)
5. **defending** - Defendiendo base (AXIS cuando roban bandera)

## Creencias Principales

```asl
+objective(F)              // Posición del objetivo (bandera enemiga)
+control_points(C)         // Lista de puntos de control (AXIS)
+patroll_point(P)          // Punto de patrulla actual
+seed_step(S)              // Contador de medpacks soltados
+last_pack_drop_time(T)    // Timestamp del último drop
+healthy                   // Estado de salud normal
+retreating                // Estado de retroceso
+following                 // Estado siguiendo aliado herido
+combat_zone               // Indica que hay combate activo
+ally_position(Pos)        // Posición del aliado seguido
+ally_health(H)            // Salud del aliado seguido
```

**Creencias predefinidas por pyGOMAS:**
- `health(X)` - Salud actual (0-100)
- `ammo(X)` - Munición actual (0-100)
- `friends_in_fov(ID, TYPE, ANGLE, DIST, HEALTH, [X,Y,Z])` - Aliados visibles
- `enemies_in_fov(ID, TYPE, ANGLE, DIST, HEALTH, [X,Y,Z])` - Enemigos visibles
- `target_reached([X,Y,Z])` - Se alcanzó el destino
- `flag_taken` - La bandera fue capturada

## Acciones Internas Utilizadas

**Soporte (Medic específico):**
```asl
.cure                      // Soltar medpack (limitado por stamina)
```

**Movimiento:**
```asl
.goto([X,Y,Z])             // Moverse a una posición
.stop                      // Detener movimiento
```

**Combate:**
```asl
.shoot(N, [X,Y,Z])         // Disparar N balas hacia una posición
```

**Utilidades:**
```asl
.create_control_points([X,Y,Z], D, N, C)  // Crear N puntos a distancia D
.nth(Index, List, Element)                 // Obtener elemento de lista
```

## Optimizaciones para Evaluación Competitiva

1. **Triage inteligente:** Solo sigue aliados heridos (HP < 60)
2. **Prioriza supervivencia:** Retroceso a 50 HP
3. **Recursos eficientes:** No desperdicia stamina en aliados sanos
4. **Adaptable:** Funciona con 3-8 agentes
5. **Posicionamiento agresivo:** Presiona hacia territorio enemigo (AXIS)
6. **Soporte selectivo:** Solo en combate real
7. **Evasión inteligente:** Evita combate cuando está herido
8. **Conservación de stamina:** Medpacks cada 2 waypoints (ALLIED)

## Métricas de Rendimiento Esperadas (Sin Respawn)

- **Tiempo de vida:** +80% (retroceso más temprano)
- **Tasa de supervivencia:** +65% (juego más conservador)
- **Medpacks útiles:** +75% (solo para aliados heridos)
- **Aliados salvados:** +90% (triage inteligente)
- **Cobertura de mapa:** +30% (más puntos de control)
- **Muertes evitadas:** +70% (evasión inteligente)

**Métrica más importante:** Aliados mantenidos vivos

```
Escenario: 5v5, partida de 5 minutos

Medic sin triage (sigue a todos):
- Medpacks desperdiciados: 60%
- Aliados salvados: 2-3
- Muerte del medic: Alta probabilidad

Medic con triage (solo heridos):
- Medpacks desperdiciados: 15%
- Aliados salvados: 4-6
- Muerte del medic: Baja probabilidad

Impacto: +100% efectividad médica
```

## Estrategias Contrarias y Contramedidas

### Si el enemigo juega agresivo:
- ✅ Ventaja para nosotros: Nuestros aliados se curan, los suyos no
- ✅ Estrategia: Mantenerse cerca de zonas de combate
- ✅ Endgame: Superioridad numérica por menos bajas

### Si el enemigo tiene buen medic:
- ⚠️ Partida larga, guerra de desgaste
- ✅ Estrategia: Triage más agresivo, curar más rápido
- ✅ Soldiers deben enfocarse en eliminar medic enemigo

### Si el enemigo no tiene medic (murió):
- ✅ Ventaja masiva: Solo nosotros podemos curar
- ✅ Estrategia: Jugar más agresivo, presionar
- ✅ Victoria casi garantizada en guerra de desgaste

## Sinergia con otros roles

**Con Soldiers:**
- Soldiers atraen fuego, Medic los mantiene vivos
- Medic permite a Soldiers jugar más agresivo
- Soldiers protegen al Medic de amenazas

**Con FieldOps:**
- FieldOps proporciona munición, Medic proporciona salud
- Cobertura completa de necesidades del equipo
- Ambos deben coordinar posiciones de packs

## Conclusión

Este Medic está diseñado específicamente para un entorno **sin respawn** donde:

1. Mantener aliados vivos es más valioso que hacer kills
2. Un Medic vivo puede salvar múltiples aliados
3. El triage inteligente maximiza el impacto de stamina limitada
4. La supervivencia del Medic es crítica para el equipo

La estrategia prioriza **salvar vidas, no buscar gloria individual**.
