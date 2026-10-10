class_name Moth
extends Enemy
## Ash moth: erratic flier drawn to the brightest light. A lit brazier
## nearby lures it away from the player... and slowly burns it.

var _wobble := randf() * TAU
var _lure: LightEmitter = null
var _orbit := randf() * TAU


func _ai(delta: float) -> void:
	_wobble += delta * 7.0
	var to_player := dir_to_target()
	var desired := to_player
	_lure = Lights.brightest_static_near(global_position, 150.0)
	if _lure and dist_to_target() > 70.0:
		# circle the flame
		_orbit += delta * 3.2
		var goal := _lure.global_position + Vector2(cos(_orbit), sin(_orbit) * 0.7) * 14.0 + Vector2(0, -10)
		desired = (goal - global_position).normalized()
		if global_position.distance_to(_lure.global_position) < 26.0:
			# burn status ticks every 0.5 s: one number and one sound per tick
			burn_time = maxf(burn_time, 0.6)
			burn_dps = maxf(burn_dps, float(data.get("burn_dps", 6.0)))
	var side := Vector2(-desired.y, desired.x) * sin(_wobble) * 0.8
	velocity = (desired + side).normalized() * speed
