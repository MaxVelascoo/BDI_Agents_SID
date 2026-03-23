# BDI Agents SID — PyGOMAS Capture the Flag

Agentes BDI implementados en AgentSpeak (`.asl`) para el juego **PyGOMAS** (Python Game Oriented Multi-Agent System), un juego de captura de bandera basado en el framework SPADE.

## Estructura del repositorio

```
BDI_Agents_SID/
├── bdisoldier.asl          # Agente soldado (versión final)
├── bdimedic.asl            # Agente médico (versión final)
├── bdifieldop.asl          # Agente operador de campo (versión final)
├── bdisoldier_old.asl      # Versión anterior del soldado
├── bdimedic_old.asl        # Versión anterior del médico
├── bdifieldop_old.asl      # Versión anterior del fieldops
├── bdisoldier_dummy.asl    # Agente dummy (referencia)
├── bdimedic_dummy.asl      # Agente dummy (referencia)
├── bdifieldop_dummy.asl    # Agente dummy (referencia)
├── ejemplo.json            # Configuración de partida de ejemplo
├── test_game.json          # Configuración para pruebas locales
└── run_test.py             # Script de ejecución local
```

## Agentes

### Soldado (`bdisoldier.asl`)
Combatiente principal con ventaja de daño 2x.

- **ALLIED**: empuje agresivo hacia la bandera enemiga y retorno a base
- **AXIS**: patrulla defensiva con puntos de control alrededor de la bandera
- Retirada automática si salud < 40 (sin respawn)
- Recogida oportunista de packs de salud y munición
- Evasión de combate cuando porta la bandera

### Médico (`bdimedic.asl`)
Soporte médico estratégico con siembra de medpacks.

- Avance hacia el objetivo dejando medpacks en la ruta
- Seguimiento y curación de aliados heridos en zona de combate
- Escolta al portador de la bandera de vuelta a base
- Retirada si salud < 50 (prioridad de supervivencia)

### Operador de Campo (`bdifieldop.asl`)
Soporte logístico con siembra de ammopacks.

- Avance hacia el objetivo dejando ammopacks en la ruta
- Seguimiento a soldados en combate activo para suministrar munición
- Escolta al portador de la bandera de vuelta a base
- Retirada si salud < 50 (prioridad de supervivencia)

## Requisitos

```bash
conda activate sid
pip install pygomas
```

## Ejecución

Necesitas tres terminales, todas con el entorno `sid` activado y desde el directorio `BDI_Agents_SID/`:

**Terminal 1 — Manager:**
```bash
pygomas manager --jid cmanager-coconut@sidfib.mooo.com --service-jid cservice-coconut@sidfib.mooo.com --num-players 10 --match-time 120
```

**Terminal 2 — Agentes:**
```bash
pygomas run -g ejemplo.json
```

**Terminal 3 — Visualizador:**
```bash
pygomas render --host sidfib.mooo.com
```

## Configuración (`ejemplo.json`)

El archivo `ejemplo.json` enfrenta la versión nueva de los agentes (AXIS) contra la versión anterior (ALLIED):

| Equipo | Agentes |
|--------|---------|
| AXIS   | `bdisoldier.asl`, `bdimedic.asl`, `bdifieldop.asl` |
| ALLIED | `bdisoldier_old.asl`, `bdimedic_old.asl`, `bdifieldop_old.asl` |

Para usar `test_game.json`, que enfrenta los agentes propios contra dummies:
```bash
pygomas run -g test_game.json
```

## Documentación adicional

Cada agente tiene su propio README detallado:
- [`README_SOLDIER.md`](README_SOLDIER.md)
- [`README_MEDIC.md`](README_MEDIC.md)
- [`README_FIELDOPS.md`](README_FIELDOPS.md)
