# LUMBRE — Documento de diseño

> *El último farolero de Velaluz.* Roguelite de acción en pixel art donde tu llama es a la vez tu vida, tu munición y tu radio de visión.

## 1. Visión

La ciudad de Velaluz se apagó: la **Penumbra** inunda su subsuelo y se ha tragado la luz. Eres el último farolero. Desciendes con un farol cuya llama es todo lo que tienes. Cada disparo te debilita y te deja ver menos; cada criatura vencida suelta ascuas que la reavivan. Los braseros que enciendes cambian la sala; las chispas que traes de vuelta reencienden la ciudad.

**Pilares**

1. **Una sola barra lo decide todo.** Llama = vida = munición = luz. Cada decisión (disparar, encender, comprar) se paga con lo mismo que te mantiene vivo.
2. **La luz es un arma de sistema.** Los braseros debilitan a las criaturas, atraen polillas, aturden a la Madre Polilla, son el único modo de herir a la Penumbra bajo su Velo… y cuestan llama.
3. **Ver menos es peligroso.** Con poca llama, el radio de luz se encoge y las sombras (invisibles en la oscuridad) se acercan sin que las veas.
4. **Progreso visible.** La plaza se ilumina farola a farola con lo que traes del subsuelo.

## 2. Ciclo de juego

**Momento a momento (segundos)**: moverse, apuntar, disparar luz (cuesta llama), golpe de farol (gratis, corto alcance, destruye orbes), esquivar (invulnerable), fogonazo (área: aturde, destruye orbes, enciende braseros, revela secretos).

**Sala (≈30–60 s)**: entras a oscuras; las puertas se cierran; 1–3 oleadas. ¿Gastas llama en encender braseros para pelear con ventaja? Al despejar: ascuas, y si encendiste todos los braseros, una chispa.

**Profundidad (≈5–8 min)**: plano procedural con sala de tesoro (elige 1 de 3 reliquias), tienda del Cerero (reliquias por **llama**, consumibles por **chispas**), sucesos con decisiones, sala élite, sala secreta tras un muro agrietado y el guardián. Tras vencerlo: reliquia (1 de 2) y trampilla de descenso.

**Expedición (≈15–25 min)**: 3 profundidades (Cloacas → Catacumbas de Cera → Fundición Fría) y 3 guardianes. Victoria o muerte, las chispas recogidas vuelven a la plaza.

**Meta (horas)**: en la Plaza de Velaluz gastas chispas en reencender 11 farolas (desbloqueos permanentes). Tras vencer a la Penumbra, el Gran Faro y 10 niveles de **Noche** (dificultad creciente, estilo «ascensión»).

### Primeros 10 minutos

- Menú → «Jugar» lleva **directamente** a la primera expedición (sin plaza ni tutorial de texto).
- La sala inicial tiene dos braseros encendidos y las instrucciones escritas con tiza en el suelo (aparecen tras el título de la profundidad).
- La primera sala de combate enseña la regla central sin texto: disparar consume la barra; las ascuas la rellenan.
- Primera sorpresa: los braseros atraen a las polillas y las queman; las sombras desaparecen fuera de la luz.
- Recompensa significativa: sala de tesoro con elección de reliquias; minimapa con iconos de salas especiales.
- Tras la primera expedición: la plaza, con el mensaje «las chispas reencienden las farolas».

## 3. Sistemas

### Llama
- Máximo base 100. Disparo: −1 (modificable). Ascua: +3 × multiplicador.
- Radio de luz = `light_min + (light_max − light_min) · ratio^0.7` × multiplicador.
- Por debajo del 25%: latido, parpadeo de la barra, farol "bajo".
- Llama 0 → te apagas (salvo Fénix de Sebo).

### Luz como sistema
- Las criaturas en luz de brasero reciben +25–60% de daño (`light_weakness`).
- Las polillas orbitan braseros cercanos y se queman.
- Las sombras son invisibles fuera de la luz (opción de accesibilidad para verlas siempre).
- Los orbes del Apagavelas tienen luz negativa y encogen tu luz al impactar.
- Jefes: deslumbramiento (Madre Polilla), apagón global (Gran Apagador), Velo (Penumbra).

### Criaturas (9) y guardianes (3)
| Criatura | Comportamiento distintivo |
|---|---|
| Polilla de ceniza | Vuelo errático; atraída por braseros (se quema) |
| Babosa de cera | Lenta; deja cera que ralentiza; se divide al morir |
| Sombra rastrera | Invisible en la oscuridad; acecha y se abalanza tras telegrafiar |
| Nido de polillas | Estático; incuba polillas sin ascuas |
| Apagavelas | Mantiene distancia; abanico de orbes que encogen tu luz |
| Gólem de cera | Embiste en línea recta; si choca con un muro queda aturdido (×2 daño) |
| Ojo de Penumbra | Torreta de anillos; se cierra (resiste) tras disparar |
| Farol falso | Se hace pasar por brasero; despierta y cierra la sala |
| Espectro de ceniza | Se teletransporta; ascuas teledirigidas |
| **Madre Polilla** | Picados con marca en el suelo, enjambres; herida, el brasero la deslumbra |
| **Gran Apagador** | Campanazo con anillos (luego queda atascado), apagón + sombras, ráfagas |
| **La Penumbra** | Espirales; fase 2 «Velo» (solo la hiere la luz de brasero y apaga braseros); fase 3 oscurece la arena |

### Reliquias (32)
Datos en `data/relics.json`. Rarezas: común, rara, legendaria, maldita. Tres niveles de desbloqueo (farolas). Combinan estadísticas y efectos: rebotes, perforación, división, quemadura, explosiones en cadena, compañero orbital, rastro de fuego, escudo por sala, renacer, disparo grande cada N, daño por braseros encendidos, poder con poca llama… Sinergias deliberadas: Prisma + Espejo roto + Llama azul (lluvia de luz), Vela negra + Brasa viva + Llama hambrienta (cañón de cristal), Fósforo + Ceniza ardiente (reacciones en cadena), Yesca + braseros.

### Faroles (4)
Aceite (equilibrado), Candil de espejos (rebote), Brasero de mano (escopeta + golpe fuerte), Vela del peregrino (perforación, mucha luz, lento).

### Generación procedural (reproducible por semilla)
- `DungeonGenerator`: grafo de salas en rejilla; el jefe es el callejón sin salida más lejano (distancia ≥ 3); tesoro y tienda en callejones; sala secreta adyacente a ≥ 2 salas, nunca al inicio ni al jefe.
- `RoomLayout`: 5 tamaños, 8 estilos de obstáculos simétricos, braseros y vasijas; validación por relleno (puertas y braseros conectados, ≥ 85% del suelo alcanzable).
- `WaveBuilder`: presupuesto de peligro por profundidad, distancia y tamaño → oleadas.
- Toda la aleatoriedad del mundo deriva de `(semilla, etiqueta)` → la misma semilla da las mismas plantas, salas y ofertas.

### Meta-progresión
11 farolas (8–60 chispas): nuevas reliquias, +15 llama, faroles, sucesos, reliquia inicial, ofertas extra, ascuas mejores y el Gran Faro. 10 Noches de dificultad. Códice de reliquias y bestiario, estadísticas.

## 4. Dirección artística

- **Resolución lógica** 640×360 escalada (opción de escalado entero). Casillas de 16 px, personajes de 16–24 px, jefes de 48–56 px.
- **Paleta propia «Lumbre»** (`tools/art/palette.py`, 40 colores): rampa índigo nocturna, rampa de fuego, cera/madera, musgo, espectral turquesa, penumbra violeta, latón.
- **Iluminación**: capa de oscuridad multiplicativa con luces dinámicas, cuantizada en 5 bandas con tramado Bayer 4×4 (aspecto pixel art, no degradado suave). Tinte frío en la oscuridad, cálido en la luz. Los píxeles **emisivos** (ojos, llamas, ascuas, proyectiles) se dibujan por encima de la oscuridad: en la negrura ves pares de ojos.
- **Biomas**: Cloacas (losas azuladas, musgo, rejillas), Catacumbas de Cera (ladrillo arena, velas, huesos), Fundición Fría (placas de hierro, cristal turquesa, vetas violeta).
- **Interfaz**: latón y cera; tipografías pixel OFL (Pixelify Sans, Jersey 10, Silkscreen).
- **Respuesta**: destello blanco al impactar, retroceso, parada de impacto (hit-stop), temblor de cámara, números de daño, partículas de ascuas/cera/polvo, disolución tramada al morir, anticipación (telegraph) roja antes de los ataques.
- Referencias de espíritu (sin copiar contenido): la lectura de salas de los roguelites de mazmorras cenitales, la atmósfera de juegos de luz y sombra, el pixel art de paleta limitada.

## 5. Audio
Todo sintetizado por código (`tools/audio`): efectos por evento (disparo, golpe, esquiva, ascua, brasero, puertas, jefes…), música por bioma, jefe, plaza y menú, ambientes (goteo, viento, zumbido). Buses Música / Efectos / Interfaz con volumen ajustable.

## 6. Controles
Teclado y ratón (reasignables) y mando. WASD mover · ratón apuntar · clic izq. disparar · clic der. golpe · Espacio esquivar · Q fogonazo · E interactuar · Tab mapa · Esc pausa.
