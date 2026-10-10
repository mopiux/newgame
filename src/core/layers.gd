class_name Layers
## Shared z-index and physics-layer constants.

# z ordering inside a room (absolute z indices)
const Z_FLOOR := -20
const Z_DECAL := -15
const Z_SHADOW := -5
const Z_ENTITIES := 0
const Z_DARKNESS := 100
const Z_EMISSIVE := 110
const Z_FX_TOP := 120

# physics layer bits (see project.godot layer_names)
const WORLD := 1
const PLAYER := 2
const ENEMIES := 4
const PLAYER_SHOTS := 8
const ENEMY_SHOTS := 16
const PICKUPS := 32
const PROPS := 64
