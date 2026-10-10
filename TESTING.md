# Pruebas

## Cómo se prueba

| Herramienta | Comando | Qué verifica |
|---|---|---|
| Importación/compilación | `tools/check.sh` | Que todos los scripts compilan y los recursos se importan sin errores |
| Autopiloto | `godot --headless --fixed-fps 60 --path . -- --bot --bot-runs N` | Expediciones completas jugadas por un bot: combate, braseros, reliquias, tienda, sucesos, jefes, descenso, fin de partida y vuelta a la plaza. Imprime `BOT_STATUS`, `BOT_RESULT`, `BOT_BOSS` y al final `BOT_ERRORS` (errores de motor o de script registrados durante todo el lote, capturados con `ErrorCatcher`). `--bot-relics a,b` empieza con esas reliquias |
| Continuar (extremo a extremo) | `godot --headless --path . -- --continue-check` (incluido en `tools/test.sh`) | Juega, cambia de sala, enciende un brasero, obtiene una reliquia, guarda, vuelve al menú, pulsa «Continuar» y compara sala, reliquias, llama, chispas, puerta de entrada y braseros encendidos |
| Flujos de pantallas (extremo a extremo) | `godot --headless --path . -- --flow-check` (incluido en `tools/test.sh`) | Doble pulsación de Empezar durante el fundido, cambiar de pantalla a mitad de fundido, empezar expedición desde el panel del pozo, faroles bloqueados, foco tras Opciones y tras cancelar una confirmación. **Falla si se registra cualquier error** de motor o de script |
| Pruebas unitarias | `tools/test.sh` | 37 pruebas / ~40 300 comprobaciones: validez y determinismo de la generación (150 semillas × 3 profundidades), salas (>1000 distribuciones), estadísticas y reliquias, guardado (corrupción, copias, saneado), integridad de datos y traducciones, reglas de juego, efectos de reliquias sobre un jugador real, reasignación de teclas, minimapa, proyectiles teledirigidos |
| Recorrido de pantallas | `xvfb-run godot --path . --rendering-driver opengl3 -- --tour DIR [--lang es] [--tour-event ID]` | Visita y captura 20 pantallas (menú, opciones, plaza, paneles, pausa, mapa, sucesos, tesoro, tienda, combate, cámara de braseros, jefe, biomas, victoria): revisión visual y prueba de humo de la interfaz |
| Capturas en partida | `xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 60 -- --bot --shots DIR` | El autopiloto guarda capturas al entrar en cada sala, en los jefes y cada 15 s |

## Registro de resultados

### 2026-10-10 — primera integración
- Importación: sin errores tras corregir inferencias de tipo de GDScript.
- Autopiloto, 6 expediciones (`bot6.log`): **0 errores de script**. 1 victoria (3 guardianes vencidos, 610 s de juego), 1 muerte en la profundidad 3, 4 muertes en la profundidad 1 (sobre todo ante la Madre Polilla). → Se bajó la vida de la Madre Polilla (850→760) y se alargó la anticipación de su picado.
- Errores encontrados y corregidos gracias al bot:
  - `Player.setup` antes de `_ready` (componente de reliquias nulo).
  - Botín que caía dentro de muros y dejaba al jugador sin poder recogerlo → ahora todo el botín vuela hacia el jugador fuera de combate.
  - Efectos añadidos mientras el nodo padre configuraba hijos → adición diferida.
  - Proyectil cuya criatura de origen ya había muerto → comprobación de validez.
  - Aviso repetido de `keyboard_get_keycode_from_physical` en modo sin pantalla.
- Captura de la sala inicial revisada: oscuridad correcta (esquinas RGB ≈ 3,3,10), braseros y jugador iluminados; se aclaró la capa del jugador (se confundía con el fondo) y se retrasaron las pistas del suelo para no solaparse con el título.

### 2026-10-10 — audio y equilibrio con autopiloto
- Audio sintetizado (47 efectos WAV, 9 pistas + 3 ambientes OGG): el generador verifica pico/RMS de cada sonido y que no sea silencio; costuras de bucle medidas (salto < 0,03); espectrogramas revisados (ritmo y melodía presentes). Godot los carga sin avisos de sonido ausente.
- Hallazgo: el bot no moría por daño (9–28 puntos recibidos) sino por **agotar la llama disparando al jefe** (sin ascuas en la pelea). → Los guardianes sueltan 1 ascua por cada 4% de vida perdida.
- Hallazgo: una puerta podía cruzarse durante su tiempo de espera y el jugador salía del recinto (atasco en la sala de tienda, semilla BOT55916). → Muro invisible exterior en cada abertura y zona de activación ampliada. 0 atascos en las 20 partidas siguientes.
- Con el bot ganando 9/10, las criaturas normales apenas hacían daño (polillas: 18 puntos en 10 partidas). → Criaturas más rápidas (polilla 62→80, sombra 44→56, gólem 24→32), sombras más agresivas, más presupuesto por sala (7 + 4/profundidad + 0,8/distancia), más daño en profundidades 2–3.
- Resultado actual (10 partidas, `bot12.log`): **5 victorias**, 4 muertes en la profundidad 3 (Penumbra), 1 en la profundidad 1. Duración de jefes para el bot: Madre Polilla 18–42 s, Gran Apagador 22–41 s, Penumbra 60–160 s. Expedición victoriosa: 12–15 min de juego para el bot.

### 2026-10-10 — pruebas unitarias y revisión visual
- Las pruebas unitarias destaparon dos errores reales, ya corregidos:
  - **Las reliquias de nivel 1 y 2 nunca aparecían** aunque estuvieran desbloqueadas: los números JSON llegan como `float` y `1.0 in [0, 1]` es falso en GDScript.
  - Al **continuar** una partida, los braseros encendidos y las vasijas rotas no se restauraban por el mismo motivo (`[0.0].has(0)` es falso). Ahora el estado de sala se normaliza al cargar.
- Revisión visual (138 capturas del bot + recorrido de pantallas):
  - Los **jefes no se distinguían** en la oscuridad → cada guardián emite un aura propia; la oscuridad base deja ver siluetas.
  - Paneles de opciones y de la plaza colapsados o descentrados (`set_anchors_preset` dentro de `_ready` conserva tamaño 0) → `set_anchors_and_offsets_preset` en todo el proyecto.
  - La fila de reliquias tapaba la barra del jefe → cuadrícula de 9 columnas.
  - Charcos de cera con aspecto de bolas grises → elipses planas pixeladas.
  - El farol tapaba la cara del personaje → se sostiene a un lado.
  - La barra del jefe seguía visible al cambiar de sala → se oculta al entrar en otra sala.
- El bot y el recorrido usan un perfil de pruebas separado (`profile_test.json`) para no alterar el progreso real.
- `tools/test.sh`: **28 pruebas, 36 520 comprobaciones, 0 fallos**.

### 2026-10-10 — rendimiento y exportación
Medido con el autopiloto (`BOT_PERF`): tiempo real por fotograma descontando el coste del propio bot.

| Escenario | Medida | Resultado |
|---|---|---|
| Lógica de juego sin renderizar (CPU, 2 expediciones, 63 000 fotogramas) | media / p50 / p99 / máx | **0,60 / 0,41 / 2,85 / 32,6 ms** (el máximo es la construcción de una sala, oculta tras el fundido) |
| Render **por software** (llvmpipe, Xeon 2,8 GHz, 4 núcleos, sin GPU), 640×360 escalado a 1280×720 | FPS medio / mínimo | **80 / 54 FPS** |
| Sala en reposo | coste por fotograma | 0,20 ms (0,14 ms de interfaz) |
| Picos de entidades | nodos / proyectiles / criaturas | ~410 / 87 / 8 |

No hay GPU en el entorno: **no se ha medido en un PC real**. Que el render por software ya supere 60 FPS de media es una buena señal para equipos modestos con GPU integrada, pero no sustituye a una medición real. El modo rendimiento (opciones) reduce partículas y limita las luces a 24.

**Exportación**: `tools/export.sh` genera `build/linux/Lumbre.x86_64` (77 MB) y `build/windows/Lumbre.exe` (103 MB). El ejecutable de Linux se probó: el autopiloto completó una expedición hasta la profundidad 3 y el recorrido de pantallas capturó las 19 pantallas sin errores. El de Windows se generó pero **no se ha podido ejecutar** aquí (no hay Windows/Wine).

### 2026-10-10 — salas especiales y tercera pasada de equilibrio
- Nuevas salas: cámaras de braseros y salas sin luz (prueba `test_special_rooms_appear`); nueva prueba `test_real_floor_rooms_have_all_doors` (360 plantas reales).
- Diagnóstico con el autopiloto: las muertes ante los guardianes se producían con muy poco daño recibido → **agotamiento de llama**:
  - Madre Polilla: el bot no recogía las ascuas que ella suelta → las ascuas de guardián se atraen desde +70 px; el bot las recoge con poca llama.
  - Penumbra (Velo): el bot gastaba llama disparando a un objetivo casi inmune → aviso visual/sonoro de inmunidad, braseros a mitad de precio en salas de jefe, Velo al 25% (antes 15%) y menos apagados (cada 12 s).
- Resultado (10 partidas, `bot19.log`): **4 victorias**, 3 muertes en la profundidad 3, 1 en la 2 y 2 en la 1. Guardianes vencidos por el bot en 14–38 s (Madre Polilla, Gran Apagador) y 33–49 s (Penumbra).
- `tools/test.sh`: **30 pruebas, 39 620 comprobaciones, 0 fallos**.

### 2026-10-10 — variantes: Noches y faroles
- Autopiloto con `--bot-asc 5` y `--bot-asc 10` (3 partidas cada uno): sin errores; la dificultad sube como se pretende (el bot sin mejoras muere en las profundidades 1–2).
- Autopiloto con cada farol alternativo (`--bot-lantern mirror|ember|pilgrim`, 2 partidas cada uno): sin errores; los tres llegan a la profundidad 2–3 y la Vela del peregrino consiguió una victoria.

### 2026-10-10 — revisión de código independiente
Un agente revisor (sin acceso a escribir) leyó los sistemas centrales buscando errores que ni las pruebas ni el bot detectan. Cada hallazgo se verificó contra el código antes de corregirlo. **10 errores reales, todos corregidos**:

| # | Gravedad | Error | Corrección | Prueba |
|---|---|---|---|---|
| 1 | Alta | Perder una reliquia en un suceso dejaba al jugador con estadísticas antiguas para el resto de la partida | `Stats.reset()` reconstruye en el mismo objeto | `test_rebuilding_stats_keeps_the_same_object` |
| 2 | Alta | Se podía «escapar de la muerte» guardando o cerrando durante la animación de muerte | No se guarda con el jugador apagado; cerrar en ese momento cierra la expedición; no se puede pausar muerto | manual |
| 3 | Alta | Despertar un farol falso en una sala ya despejada volvía a pagar la sala (reliquia élite duplicada) | Una segunda limpieza solo reabre puertas | manual |
| 4 | Media | Los pesos de los sucesos se desordenaban al ordenar los ids | Pesos construidos tras ordenar | `test_event_weights_follow_their_events` |
| 5 | Media | El fogonazo revelaba muros secretos según la esquina de la sala | Distancia al centro del muro | — |
| 6 | Media | Las peleas iniciadas por sucesos no se guardaban (Guardar y salir = recompensa sin pelea) | `pending_waves` guardado y reanudado | — |
| 7 | Baja | La pantalla anterior ponía a 0 la luz ambiente después de que la nueva la fijara | Cada pantalla fija la suya al entrar | — |
| 8 | Baja | El alijo secreto se marcaba como cogido antes de recogerlo | Chispas acreditadas directamente | — |
| 9 | Baja | El Gran Apagador podía embestir desde lejos | Filtrar todas las opciones de «campanazo» | — |
| 10 | Baja | Una partida de otra versión de guardado mostraba «Continuar» para siempre | `has_run()` valida versión; se limpia si no carga | `test_incompatible_run_is_not_offered` |

Tras los arreglos: **33 pruebas / 39 670 comprobaciones, 0 fallos**, «Continuar» OK, 10 partidas del bot sin errores (4 victorias), recorrido de pantallas completo.

### 2026-10-10 — cuatro reliquias nuevas
- Farol de bolsillo, Fósforo blanco, Aceite bendito y Espejo de mano (iconos 32–35).
- Nueva prueba `test_new_relic_hooks_on_a_live_player`: crea un jugador real en el árbol de escena y comprueba el reembolso de llama al encender braseros (y que se acumula), la quemadura solo en el fogonazo, el suelo de luz y que el espejo devuelve el orbe como disparo propio en sentido contrario.
- Nueva opción del autopiloto `--bot-relics a,b,…` (empieza cada expedición con esas reliquias). 3 partidas con las cuatro nuevas: sin errores de script, 3 victorias (esperable: empieza con cuatro reliquias extra).
- `tools/test.sh`: **34 pruebas, 39 714 comprobaciones, 0 fallos**, «Continuar» OK.
- Dos sucesos nuevos (La campana ahogada, Capullo luminoso). El recorrido acepta `--tour-event ID`; captura del diálogo de la campana en español revisada (el texto cabe). `tools/test.sh`: 34 pruebas, 39 741 comprobaciones, 0 fallos.

### 2026-10-10 — segunda revisión de código independiente
El agente revisor (solo lectura) cubrió interfaz, plaza, generación, enemigos, props, audio, luces, proyectiles y shaders. Cada hallazgo se comprobó contra el código; el nº 8 se reprodujo antes de arreglarlo. **8 errores reales, todos corregidos**, más uno encontrado al escribir la prueba del nº 3:

| # | Gravedad | Error | Corrección | Prueba |
|---|---|---|---|---|
| 1 | Alta | Doble pulsación de Empezar (o Continuar y luego Jugar) durante el fundido: se veía una expedición y el juego seguía otra (guardado, descenso y muerte rotos) | La última petición sustituye a la pantalla en cola; el fundido bloquea clics; `new_run`/`continue_run` ignoran una segunda pulsación | `--flow-check` |
| 2 | Alta | Los faroles bloqueados se podían elegir con teclado o mando, y pasar el foco por un farol lo seleccionaba | Bloqueados sin foco; la elección solo cambia al pulsar (botón de grupo, resaltado en latón) | `--flow-check` |
| 3 | Media | Los orbes teledirigidos de criaturas (espectro, manos de la Penumbra) buscaban a su propio lanzador | Los disparos enemigos persiguen al jugador | `test_enemy_homing_shots_seek_the_player` |
| 3b | Media | Todo proyectil teledirigido (también los del jugador) perdía velocidad al girar | Giro conservando la velocidad | misma prueba |
| 4 | Media | Reasignar una acción a la tecla por defecto de otra dejaba las dos en la misma tecla; un clic en «Volver» mientras se esperaba una tecla se asignaba como botón izquierdo | Conflictos contra las asignaciones reales (por defecto incluidas) con intercambio; un clic izquierdo fuera del botón cancela | `test_rebinding_never_shares_a_key` |
| 5 | Media-baja | El minimapa usaba la dirección de puerta opuesta: los callejones vecinos (tesoro, tienda, jefe…) nunca aparecían como silueta | Dirección correcta, lógica extraída a `Minimap.room_known` | `test_minimap_shows_every_neighbour_of_a_visited_room` |
| 6 | Baja-media | Las polillas que rodean un brasero creaban un número de daño y un sonido por fotograma | Usan el estado de quemadura (ticks de 0,5 s) | — |
| 7 | Baja-media | Tras cerrar Opciones o cancelar una confirmación se perdía el foco de teclado/mando | El foco vuelve al botón del menú | `--flow-check` |
| 8 | Baja | Error de script al empezar expedición desde el panel del pozo (la plaza ya no estaba en el árbol) | Comprobación `is_inside_tree()` | `--flow-check` (reproducido antes del arreglo) |

- Nuevo `ErrorCatcher` (API `Logger` de Godot 4.5): el flujo de pantallas falla si se registra cualquier error y el autopiloto imprime `BOT_ERRORS`.
- Comprobación inversa: con el código anterior, `--flow-check` falla en los nº 1, 2 y 8 (incluidos los dos errores del nº 8).
- `tools/test.sh`: **37 pruebas, 40 318 comprobaciones, 0 fallos**, `CONTINUE_OK`, `FLOW_OK`. Recorrido de pantallas en español: 20 capturas sin errores.
- Regresión con el autopiloto (10 partidas, `bot20.log`): **`BOT_ERRORS 0`** en todo el lote; **4 victorias**, 3 muertes en la profundidad 3 y 3 en la 2 (antes 4/10: el equilibrio se mantiene aunque los orbes del espectro y de la Penumbra ahora sí persiguen al jugador). Guardianes vencidos en 17–34 s (Madre Polilla, Gran Apagador) y 36–54 s (Penumbra). Lógica de juego: 0,34 ms de media por fotograma, p99 1,49 ms (sin renderizado; el máximo de 182 ms coincide con cargas de planta).

## Limitaciones conocidas de las pruebas
- El contenedor no tiene GPU: los tiempos de fotograma medidos son de CPU + render por software y **no** representan un PC real.
- No hay dispositivo de audio: el sonido se verifica por análisis de ficheros, no escuchándolo.
- El autopiloto juega de forma simple (no esquiva bien); sus tasas de victoria/derrota son orientativas, no equivalen a las de una persona.
