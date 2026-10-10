# Decisiones técnicas

| # | Decisión | Motivo |
|---|---|---|
| 1 | **Godot 4.5 estable**, renderizador *Compatibility* (OpenGL 3.3) | 2D nativo y ligero, licencia MIT, exporta a Windows/Linux, escenas/scripts en texto (desarrollo y pruebas por CLI). Unity no es accesible en este entorno (dominios bloqueados, requiere cuenta); Unreal es desproporcionado para 2D. Compatibility funciona en GPUs modestas y con renderizado por software (llvmpipe), que es lo que hay en el contenedor. |
| 2 | Resolución lógica 640×360, `stretch=viewport` | Píxel nítido y coherente (UI incluida). Escalado entero opcional. |
| 3 | Sombreado de luz propio (shader de oscuridad multiplicativa con hasta 64 luces) en vez de `Light2D` | Control total del aspecto (bandas + tramado Bayer), coste predecible y **la misma fórmula en CPU** (`Lights.light_at`) para la jugabilidad (visibilidad de sombras, debilidad en luz). |
| 4 | Capa emisiva separada (`*_glow.png` generados automáticamente) | Los ojos y llamas se leen en la oscuridad sin trucos de material. |
| 5 | Arte 100% generado por código (`tools/art`, Python + Pillow) con paleta fija | Coherencia estilística, licencia limpia, reproducible (`build_art.py` es determinista) y modificable. Se evaluaron Canva (estilo no pixel) y SpriteCook (servicio externo con cuenta); se descartaron. |
| 6 | Audio sintetizado (`tools/audio`, numpy) | Sin dependencias de licencias; el entorno no tiene dispositivo de audio, así que se verifica por análisis de forma de onda. |
| 7 | Nodos construidos por código en lugar de muchas `.tscn` | Entidades y UI se crean en scripts con `class_name`; menos ficheros frágiles y revisables en diff. Contrapartida: menos edición visual en el editor. |
| 8 | Datos en JSON (`data/`) validados al arrancar por `Database` | Equilibrio, reliquias, enemigos, eventos y desbloqueos editables sin tocar código. Los comportamientos complejos viven en código (enemigos, efectos de reliquias). |
| 9 | Estadísticas con modificadores apilables por fuente (`Stats`) | Reliquias, faroles, maldiciones, ascensión y farolas se combinan sin casos especiales. |
| 10 | Aleatoriedad derivada `(semilla, etiqueta)` (`RunRng`) | Plantas, salas, oleadas y ofertas reproducibles; la partida guardada solo almacena la semilla y el estado mutable. |
| 11 | Sala de tamaño ≤ pantalla, cámara fija por sala | Lectura clara del combate, sin desplazamientos; transiciones rápidas con fundido. |
| 12 | Guardado JSON con suma de verificación, escritura atómica (tmp + rename) y copia `.bak` | Resistencia a cierres bruscos y ficheros corruptos; valores saneados al cargar. |
| 13 | Guardado de expedición al entrar en cada sala | «Continuar» retoma en la entrada de la última sala (si había combate, se repite). |
| 14 | Traducción con CSV de Godot (`i18n/strings.csv`, fuente en `tools/i18n/strings_source.py`) | Español e inglés; el script comprueba que los marcadores `%s/%d` coinciden. |
| 15 | Autopiloto (`src/debug/autopilot.gd`) + `--fixed-fps` sin interfaz | Partidas completas automatizadas ~50× más rápido que en tiempo real: detecta bloqueos, errores y datos de equilibrio. |
| 16 | Pathfinding por campo de flujo en rejilla (BFS desde el jugador, 5 Hz) | Barato y suficiente para salas pequeñas; los enemigos rodean obstáculos. |
| 17 | Proyectiles movidos a mano con *raycast* contra muros | Permite rebotes con normal real y evita túneles a alta velocidad. |
