class_name LightEmitter
extends Node2D
## A light source read by the darkness overlay (and by gameplay through the
## Lights autoload). Negative energy creates moving pockets of darkness.

@export var radius: float = 64.0
@export var energy: float = 1.0
@export var color: Color = Color(1.0, 0.86, 0.66)
@export var flicker: float = 0.06       # fraction of radius
@export var flicker_speed: float = 9.0
@export var priority: int = 0           # higher survives the light cap first
@export var is_static: bool = false     # braziers, lamps (not the player)
@export var enabled: bool = true

var current_radius: float = 0.0
var current_energy: float = 1.0
var _t: float = 0.0
var _pulse: float = 0.0
var _pulse_time: float = 0.0
var _pulse_total: float = 0.0


func _ready() -> void:
	_t = randf() * 100.0
	current_radius = radius
	current_energy = energy


func _enter_tree() -> void:
	Lights.register(self)


func _exit_tree() -> void:
	Lights.unregister(self)


## Temporarily boosts the radius (muzzle flashes, flares, ignitions).
func pulse(extra_radius: float, duration: float) -> void:
	_pulse = extra_radius
	_pulse_time = duration
	_pulse_total = maxf(duration, 0.001)


func _process(delta: float) -> void:
	_t += delta * flicker_speed
	var f := (sin(_t) * 0.6 + sin(_t * 2.37 + 1.3) * 0.4) * flicker
	var extra := 0.0
	if _pulse_time > 0.0:
		_pulse_time -= delta
		extra = _pulse * clampf(_pulse_time / _pulse_total, 0.0, 1.0)
	current_radius = maxf(0.0, radius * (1.0 + f) + extra)
	current_energy = energy
