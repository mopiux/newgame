# Pruebas

## Cómo se prueba

| Herramienta | Comando | Qué verifica |
|---|---|---|
| Importación/compilación | `tools/check.sh` | Que todos los scripts compilan y los recursos se importan sin errores |
| Autopiloto | `godot --headless --fixed-fps 60 --path . -- --bot --bot-runs N` | Expediciones completas jugadas por un bot: combate, braseros, reliquias, tienda, sucesos, jefes, descenso, fin de partida y vuelta a la plaza. Imprime `BOT_STATUS`, `BOT_RESULT` y cualquier `SCRIPT ERROR` |
| Pruebas unitarias | `tools/test.sh` | 28 pruebas / ~36 500 comprobaciones: validez y determinismo de la generación (150 semillas × 3 profundidades), salas (>1000 distribuciones), estadísticas y reliquias, guardado (corrupción, copias, saneado), integridad de datos y traducciones, reglas de juego |
| Recorrido de pantallas | `xvfb-run godot --path . --rendering-driver opengl3 -- --tour DIR` | Visita y captura 19 pantallas (menú, opciones, plaza, paneles, pausa, mapa, sucesos, tesoro, tienda, combate, jefe, biomas, victoria): revisión visual y prueba de humo de la interfaz |
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

## Limitaciones conocidas de las pruebas
- El contenedor no tiene GPU: los tiempos de fotograma medidos son de CPU + render por software y **no** representan un PC real.
- No hay dispositivo de audio: el sonido se verifica por análisis de ficheros, no escuchándolo.
- El autopiloto juega de forma simple (no esquiva bien); sus tasas de victoria/derrota son orientativas, no equivalen a las de una persona.
