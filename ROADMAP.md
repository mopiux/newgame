# Hoja de ruta

Leyenda: ✅ hecho y verificado · 🟡 en progreso / parcial · ⬜ pendiente

## Fase A — Investigación y propuesta
- ✅ Inspección del entorno, Skills, herramientas y motores
- ✅ Evaluación de 6 conceptos y elección (LUMBRE)
- ✅ Motor elegido y verificado (Godot 4.5 + Compatibility; renderiza bajo Xvfb/llvmpipe)
- ✅ Documento de diseño, decisiones y dirección artística

## Fase B — Prototipo jugable
- ✅ Movimiento, apuntado ratón/mando, disparo con coste de llama, golpe, esquiva, fogonazo
- ✅ Llama como vida/munición/radio de luz
- ✅ Shader de oscuridad con luces dinámicas y capa emisiva
- ✅ Salas con colisión, puertas, enemigos y recompensas

## Fase C — Circuito completo
- ✅ Generación procedural de plantas (semilla) y salas (validadas)
- ✅ Transiciones entre salas, minimapa y mapa completo
- ✅ Reliquias data-driven con efectos; tienda; sucesos; sala élite; sala secreta
- ✅ 3 guardianes con fases; descenso; victoria y derrota
- ✅ Menú principal, pausa, opciones (audio/vídeo/accesibilidad/controles reasignables/idioma), créditos
- ✅ Guardado de perfil y de expedición («Continuar»)
- ✅ Plaza (hub) con farolas desbloqueables, pozo de expediciones, tablón (códice/bestiario/registros)
- ✅ Verificado con autopiloto: expediciones completas hasta la victoria sin errores de script

## Fase D — Contenido y profundidad
- ✅ 9 criaturas con comportamientos distintos, 3 jefes, 32 reliquias, 4 faroles, 10 sucesos, 11 farolas, 10 Noches
- 🟡 Equilibrio: primera pasada con datos del autopiloto (ver TESTING.md); falta ajuste con más partidas
- ⬜ Más variedad de salas hechas a mano (puzles de luz, salas oscuras especiales)

## Fase E — Arte, audio y pulido
- ✅ Arte pixel definitivo generado por código para todo el contenido
- ⬜ Audio: efectos y música sintetizados (pendiente — el juego avisa de sonidos ausentes)
- 🟡 Pulido de animaciones (babosa y gólem mejorables)

## Fase F — Pruebas y distribución
- 🟡 Autopiloto de partidas completas
- ⬜ Batería de pruebas unitarias headless
- ⬜ Medición de rendimiento documentada
- ⬜ Exportación Linux/Windows
