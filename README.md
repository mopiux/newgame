# LUMBRE — El último farolero

Roguelite de acción en pixel art hecho con **Godot 4.5**. Tu llama es tu vida, tu munición y tu luz: cada disparo te debilita y te deja ver menos; las ascuas de las criaturas la reavivan. Enciende braseros para debilitar a la Penumbra, combina reliquias, vence a los tres guardianes del subsuelo y reenciende, chispa a chispa, la plaza de Velaluz.

- Diseño: [GAME_DESIGN.md](GAME_DESIGN.md) · Estado: [ROADMAP.md](ROADMAP.md) · Pruebas: [TESTING.md](TESTING.md) · Decisiones: [DECISIONS.md](DECISIONS.md) · Créditos: [CREDITS.md](CREDITS.md)

## Requisitos
- **Godot 4.5 estable** (versión estándar, no .NET): https://godotengine.org/download
- Opcional, para regenerar arte/textos/audio: Python 3.10+ con `pillow` y `numpy`, y `ffmpeg` con libvorbis.

## Ejecutar
1. Abre Godot 4.5 → *Importar* → selecciona `project.godot` → *Ejecutar* (F5).

O desde la terminal:
```bash
godot --path .            # primera vez: abre el editor una vez o ejecuta tools/check.sh para importar
tools/run.sh              # importa si hace falta y lanza el juego
```

### Controles
| Acción | Teclado/ratón | Mando |
|---|---|---|
| Mover | WASD / flechas | Stick izquierdo |
| Apuntar | Ratón | Stick derecho (ayuda de apuntado opcional) |
| Disparar luz (cuesta llama) | Clic izquierdo | RT / RB |
| Golpe de farol (gratis, rompe orbes) | Clic derecho | X |
| Esquivar | Espacio | A / LT |
| Fogonazo | Q | Y |
| Interactuar | E | B |
| Mapa | Tab | Select |
| Pausa | Esc | Start |

Las teclas se pueden reasignar en *Opciones → Controles*.

## Estructura
```
data/          equilibrio, reliquias, enemigos, biomas, sucesos, farolas (JSON)
i18n/          textos ES/EN (generado por tools/i18n/strings_source.py)
assets/gfx     sprites y casillas (generados por tools/art/build_art.py)
assets/audio   efectos y música (generados por tools/audio)
assets/shaders oscuridad dinámica y efectos de sprite
src/autoload   servicios globales: Database, Settings, SaveManager, Audio, Lights, Game, SpriteLib, Events
src/core       estado de expedición, estadísticas, RNG por semilla, reliquias, sucesos
src/world      generación de plantas y salas, sala, nivel, plaza, cámara, luz
src/entities   jugador, proyectiles, criaturas, guardianes, objetos interactivos
src/ui         HUD, menús, opciones, plaza, códice
src/debug      autopiloto para pruebas automáticas
tools/         generadores de arte/audio/textos y scripts de pruebas
```

## Regenerar recursos
```bash
python3 tools/art/build_art.py        # todos los sprites (determinista)
python3 tools/i18n/strings_source.py  # i18n/strings.csv
tools/check.sh                        # reimporta en Godot y lista errores
```

## Compilar ejecutables
1. Instala las plantillas de exportación de Godot 4.5 (*Editor → Gestionar plantillas de exportación → Descargar*), o extrae el `.tpz` oficial en `~/.local/share/godot/export_templates/4.5.stable/`.
2. Ejecuta:
```bash
tools/export.sh            # build/linux/Lumbre.x86_64 y build/windows/Lumbre.exe
```
O desde el editor: *Proyecto → Exportar* (perfiles «Linux» y «Windows» ya configurados en `export_presets.cfg`). El ejecutable incluye todos los datos (un solo fichero, ~77 MB en Linux, ~103 MB en Windows).

## Pruebas automáticas
```bash
tools/test.sh                                                           # 28 pruebas unitarias sin pantalla
tools/check.sh                                                          # compila e importa todo
godot --headless --fixed-fps 60 --path . -- --bot --bot-runs 5         # 5 expediciones con autopiloto
xvfb-run godot --path . -- --tour capturas/                             # captura todas las pantallas
```
Detalles y resultados en [TESTING.md](TESTING.md).

## Datos de usuario
Perfil, expedición guardada y ajustes se guardan en la carpeta de usuario de Godot (`user://`, carpeta `Lumbre`):
- Windows: `%APPDATA%\Lumbre\` · Linux: `~/.local/share/Lumbre/` · macOS: `~/Library/Application Support/Lumbre/`
