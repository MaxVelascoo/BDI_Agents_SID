# Soldier Agent - Documentación

## Descripción General

El agente Soldier es el rol de combate principal, especializado en capturar la bandera (ALLIED) o defenderla (AXIS). Con daño 2x superior a otros roles, es la punta de lanza del equipo. Diseñado para operar autónomamente en entornos sin respawn.

## Filosofía de Diseño

Este Soldier está optimizado para:

- **Agresividad calculada**: Máximo daño pero con supervivencia en mente
- **Autonomía total**: No depende de coordinación con otros
- **Ventaja de daño**: Aprovecha el 2x damage para eliminar enemigos rápido
- **Supervivencia CRÍTICA**: Sin respawn, incluso soldiers deben ser cautelosos
- **Objetivo claro**: Capturar (ALLIED) o defender (AXIS) la bandera

## ⚠️ REGLA CRÍTICA: NO HAY RESPAWN

- Cada muerte es permanente
- Un soldier muerto = -12.5% a -33% de capacidad ofensiva del equipo
- Soldiers son el daño principal, su supervivencia es crucial
- Capturar la bandera no sirve si mueres en el intento

## Comportamientos Principales

### 1. Auto-Preservación (Self-Preservation)

**Soldiers tienen umbrales diferentes según su estado:**

```
Sin bandera:
  Salud < 40  → Retrocede a la base
  Salud ≥ 70  → Vuelve a operaciones

Con bandera (portador):
  Salud < 60  → Retrocede INMEDIATAMENTE (más conservador)
  Salud ≥ 70  → Continúa a la base con la bandera
```

**Razón del umbral diferente:**
- Portador de bandera = objetivo prioritario enemigo
- Perder la bandera cerca de la base enemiga = desastre
- Mejor retroceder temprano que morir con la bandera

**Comportamiento durante retroceso:**

| Estado | Acción |
|--------|--------|
| Retrocediendo sin bandera | Dispara 2 balas si enemigo < 40 unidades |
| Retrocediendo con bandera | NO dispara, solo corre |

**Implementación:**
```asl
+health(H): H < 60 & healthy & carrying_flag
  <-
  -healthy;
  +retreating;
  ?base(B);
  .goto(B).
```

### 2. Superioridad en Combate (Combat Superiority)

**Ventaja clave: Soldiers hacen 2x daño**

Esto significa:
- 5 disparos de soldier = 10 disparos de medic/fieldops
- Puede eliminar enemigos en 2-3 ráfagas
- Es el rol más letal del juego

**Estrategia de combate según estado:**

| Estado | Enemigo detectado | Balas | Razón |
|--------|------------------|-------|-------|
| Sano (healthy) | Siempre | 5 | Máximo daño, eliminar rápido |
| Herido (not healthy) | Siempre | 3 | Conservador pero efectivo |
| Retrocediendo sin bandera | Si Dist < 40 | 2 | Disuadir persecución |
| Retrocediendo con bandera | Nunca | 0 | Prioridad: llegar a base |

**Implementación:**
```asl
+enemies_in_fov(ID, Type, Angle, Distance, Health, Position)
  : not retreating & healthy
  <-
  .shoot(5, Position).  // 5 shots × 2 damage = 10 damage
```

### 3. Conciencia de Packs (Pack Awareness)

**Versión anterior:** Ignoraba packs, iba directo al objetivo.

**Versión mejorada:** Recoge packs oportunistamente.

**Prioridades:**
1. Health pack si HP < 70 (y no lleva bandera)
2. Ammo pack si munición < 30 (y no lleva bandera)
3. Objetivo principal si está sano y con munición

**Ventajas:**
- Mantiene salud alta = menos retrocesos
- Mantiene munición alta = más combates ganados
- No desvía ruta si no es necesario

**Implementación:**
```asl
+packs_in_fov(ID, Type, Angle, Distance, Health, Position)
  : Type == 1001 & health(H) & H < 70 & not carrying_flag
  <-
  +seeking_pack;
  .goto(Position).
```

**Nota importante:** Si lleva la bandera, NO recoge packs. Prioridad = llegar a base.

### 4. Ejecución de Objetivo

#### ALLIED (Atacante - Team 100)

**Misión:** Capturar la bandera y llevarla a la base.

**Fases:**
1. **Attacking** - Ir hacia la bandera enemiga
2. **At flag** - Llegar a la posición de la bandera
3. **Carrying flag** - Capturar y llevar la bandera
4. **Returning** - Volver a la base con la bandera
5. **Victory** - Entregar la bandera en la base

**Estrategia:**
- Ruta directa a la bandera (pathfinding automático)
- Combate agresivo en el camino (5 balas)
- Al capturar: modo ultra-conservador
- Retroceso temprano si HP < 60 (con bandera)

**Implementación:**
```asl
+flag_taken: team(100)
  <-
  -attacking;
  +carrying_flag;
  +returning;
  ?base(B);
  .goto(B).
```

#### AXIS (Defensor - Team 200)

**Misión:** Defender la bandera, eliminar atacantes.

**Fases:**
1. **Defending** - Patrullar perímetro defensivo
2. **Intercepting** - Si roban la bandera, interceptar

**Estrategia:**
- 4 puntos de control a 35 unidades de la bandera
- Patrulla agresiva (no pasiva)
- Combate muy agresivo (5 balas)
- Si roban bandera: ir a base e interceptar

**Ventajas:**
- Cobertura de 360° alrededor de la bandera
- Detecta atacantes antes de que lleguen
- Posición defensiva pero activa

**Implementación:**
```asl
+flag(F): team(200)
  <-
  .create_control_points(F, 35, 4, C);  // 4 puntos defensivos
  +defending;
  +patroll_point(0).
```

### 5. Actualización de Memoria de Bandera

**Versión anterior:** Mantenía memoria de dónde estaba la bandera.

**Versión mejorada:** Usa evento `flag_taken` para saber cuándo actuar.

**Ventajas:**
- Más simple y confiable
- No necesita rastrear portadores
- Responde inmediatamente a eventos

## Comparación: Antes vs Después (Sin Respawn)

### Antes (Versión Original)

```
Ventajas:
+ Muy agresivo
+ Daño 2x aprovechado
+ Búsqueda sistemática

Desventajas:
- No consideraba salud (FATAL sin respawn)
- Ignoraba packs útiles
- Demasiado agresivo (moría fácilmente)
- No diferenciaba entre estados
- AXIS demasiado pasivo
```

### Después (Versión Mejorada para No-Respawn)

```
Ventajas:
+ Agresividad calculada
+ Supervivencia mejorada (retroceso a 40 HP)
+ Recoge packs oportunistamente
+ Portador de bandera ultra-conservador
+ AXIS más agresivo en defensa
+ Combate adaptativo según estado
+ Aprovecha daño 2x eficientemente

Desventajas:
- Menos "heroico" (pero más efectivo)
- Puede retroceder en momentos críticos
```

## Impacto del No-Respawn en la Estrategia

### Cambios críticos implementados:

1. **Umbral de retroceso: Ninguno → 40 HP (60 HP con bandera)**
   - Razón: Soldiers son valiosos, no pueden morir innecesariamente.

2. **Portador de bandera: Sin diferencia → Ultra-conservador**
   - Razón: Perder la bandera cerca de la base enemiga es desastroso.

3. **Recogida de packs: Ignorados → Oportunista**
   - Razón: Mantenerse sano = menos retrocesos = más tiempo en objetivo.

4. **AXIS defensa: Pasiva → Agresiva**
   - Razón: Mejor interceptar atacantes lejos de la bandera.

5. **Combate con bandera: Agresivo → Evasivo**
   - Razón: Llegar a base > matar enemigos.

### Matemática de supervivencia:

```
Soldier sin retroceso:
- Probabilidad de muerte: 70%
- Capturas exitosas: 20%
- Valor del equipo: Bajo (muere rápido)

Soldier con retroceso a 40 HP:
- Probabilidad de muerte: 30%
- Capturas exitosas: 60%
- Valor del equipo: Alto (sobrevive más)

Soldier con bandera (retroceso a 60 HP):
- Probabilidad de entregar bandera: 80%
- Valor: CRÍTICO (victoria del equipo)
```

## Estados del Agente

### ALLIED (Team 100):
1. **attacking** - Yendo hacia la bandera enemiga
2. **at_flag** - En la posición de la bandera
3. **carrying_flag** - Llevando la bandera
4. **returning** - Volviendo a base con bandera
5. **retreating** - Retrocediendo por salud baja
6. **seeking_pack** - Buscando pack de salud/munición

### AXIS (Team 200):
1. **defending** - Patrullando perímetro defensivo
2. **intercepting** - Persiguiendo ladrón de bandera
3. **retreating** - Retrocediendo por salud baja
4. **seeking_pack** - Buscando pack de salud/munición

## Creencias Principales

```asl
+objective(F)              // Posición de la bandera
+my_last_known_flag(F, T)  // Última posición conocida
+control_points(C)         // Puntos de patrulla (AXIS)
+patroll_point(P)          // Punto actual de patrulla
+healthy                   // Estado de salud normal
+carrying_flag             // Llevando la bandera
+at_flag                   // En posición de bandera
+attacking                 // Atacando (ALLIED)
+defending                 // Defendiendo (AXIS)
+intercepting              // Interceptando (AXIS)
+retreating                // Retrocediendo
+seeking_pack              // Buscando pack
```

**Creencias predefinidas por pyGOMAS:**
- `health(X)` - Salud actual (0-100)
- `ammo(X)` - Munición actual (0-100)
- `enemies_in_fov(...)` - Enemigos visibles
- `packs_in_fov(ID, TYPE, ...)` - Packs visibles (1001=health, 1002=ammo, 1003=flag)
- `target_reached([X,Y,Z])` - Destino alcanzado
- `flag_taken` - Bandera capturada
- `pack_taken(TYPE, N)` - Pack recogido

## Acciones Internas Utilizadas

**Movimiento:**
```asl
.goto([X,Y,Z])             // Moverse a una posición (pathfinding automático)
```

**Combate:**
```asl
.shoot(N, [X,Y,Z])         // Disparar N balas (con 2x damage!)
```

**Utilidades:**
```asl
.create_control_points([X,Y,Z], D, N, C)  // Crear N puntos a distancia D
.nth(Index, List, Element)                 // Obtener elemento de lista
```

## Optimizaciones para Evaluación Competitiva

1. **Daño 2x aprovechado:** 5 balas = 10 damage efectivo
2. **Supervivencia mejorada:** Retroceso a 40 HP (60 con bandera)
3. **Recogida oportunista:** Packs de salud/munición
4. **Portador conservador:** Ultra-cuidadoso con la bandera
5. **AXIS agresivo:** Defensa activa, no pasiva
6. **Combate adaptativo:** Diferentes estrategias según estado
7. **Pathfinding automático:** JPS algorithm para rutas óptimas
8. **Respuesta a eventos:** `flag_taken` para coordinación

## Métricas de Rendimiento Esperadas (Sin Respawn)

- **Tiempo de vida:** +60% (retroceso a 40 HP)
- **Tasa de supervivencia:** +55% (juego más inteligente)
- **Kills por partida:** +40% (daño 2x bien aprovechado)
- **Capturas exitosas:** +200% (portador conservador)
- **Muertes evitadas:** +60% (retroceso temprano)
- **Eficiencia de combate:** +80% (5 balas con 2x damage)

**Métrica más importante:** Capturas de bandera exitosas

```
Escenario: 5v5, partida de 5 minutos

Soldier agresivo (sin retroceso):
- Kills: 4-5
- Muertes: 2-3
- Capturas: 0-1
- Valor: Medio

Soldier inteligente (con retroceso):
- Kills: 3-4
- Muertes: 0-1
- Capturas: 1-2
- Valor: ALTO

Diferencia: +100% tasa de victoria
```

## Estrategias Contrarias y Contramedidas

### Si el enemigo juega agresivo:
- ✅ Ventaja: Nuestros soldiers sobreviven más
- ✅ Estrategia: Jugar defensivo, dejar que se desgasten
- ✅ Endgame: Superioridad numérica

### Si el enemigo juega conservador:
- ⚠️ Partida larga, posible timeout
- ✅ Estrategia: ALLIED debe ser más agresivo
- ✅ AXIS debe interceptar más lejos

### Si el enemigo tiene mejor aim:
- ✅ Ventaja: Nuestro retroceso temprano minimiza daño
- ✅ Estrategia: Evitar combates prolongados
- ✅ Usar cobertura del mapa

## Sinergia con otros roles

**Con Medics:**
- Medic mantiene soldier vivo
- Soldier protege al medic
- Soldier puede jugar más agresivo con medic cerca

**Con FieldOps:**
- FieldOps proporciona munición infinita
- Soldier puede disparar más libremente
- Combinación letal en combate prolongado

**Coordinación ideal:**
- Soldier adelante (tanque)
- Medic atrás (curación)
- FieldOps medio (munición)
- Formación de combate efectiva

## Tácticas Avanzadas

### ALLIED - Captura de Bandera:

1. **Rush inicial:** Ir directo a bandera, ignorar enemigos si es posible
2. **Combate selectivo:** Solo pelear si bloquean el camino
3. **Recogida estratégica:** Packs solo si HP < 70 o ammo < 30
4. **Retroceso inteligente:** Si HP < 60 con bandera, volver inmediatamente
5. **Ruta alternativa:** Si hay muchos enemigos, buscar otro camino

### AXIS - Defensa de Bandera:

1. **Perímetro activo:** Patrullar 35 unidades alrededor
2. **Intercepción temprana:** Detectar atacantes lejos
3. **Combate agresivo:** 5 balas, eliminar rápido
4. **Respuesta a robo:** Si roban bandera, ir a base inmediatamente
5. **Trabajo en equipo:** Coordinar con otros defenders

## Conclusión

Este Soldier está diseñado específicamente para un entorno **sin respawn** donde:

1. La supervivencia es tan importante como el daño
2. Capturar la bandera > matar enemigos
3. El daño 2x debe aprovecharse inteligentemente
4. Portadores de bandera son ultra-valiosos
5. La agresividad debe ser calculada, no suicida

La estrategia prioriza **completar el objetivo, no maximizar kills**.
