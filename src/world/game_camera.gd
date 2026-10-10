class_name GameCamera
extends Camera2D
## Static per-room camera with trauma-based screen shake and hit-stop.

var trauma := 0.0
var _shake_time := 0.0
var _base := Vector2.ZERO
var _hitstop_left := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.screen_shake.connect(_on_shake)
	Events.hit_stop.connect(_on_hit_stop)


func focus(center: Vector2) -> void:
	_base = center
	global_position = center
	reset_smoothing()


func _on_shake(strength: float, duration: float) -> void:
	var s := strength * float(Settings.get_value("access", "shake"))
	trauma = maxf(trauma, s)
	_shake_time = maxf(_shake_time, duration)


func _on_hit_stop(duration: float) -> void:
	if get_tree().paused:
		return
	_hitstop_left = maxf(_hitstop_left, duration)
	Engine.time_scale = 0.05


func _process(delta: float) -> void:
	var real_delta := delta / maxf(Engine.time_scale, 0.001) if Engine.time_scale < 1.0 else delta
	if _hitstop_left > 0.0:
		_hitstop_left -= real_delta
		if _hitstop_left <= 0.0:
			Engine.time_scale = 1.0
	if get_tree().paused:
		offset = Vector2.ZERO
		return
	if _shake_time > 0.0:
		_shake_time -= real_delta
		offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * trauma
		offset = offset.round()
		trauma = move_toward(trauma, 0.0, trauma * real_delta * 6.0)
	else:
		trauma = 0.0
		offset = Vector2.ZERO


func _exit_tree() -> void:
	Engine.time_scale = 1.0
