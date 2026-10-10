class_name Shade
extends Enemy
## Shade: invisible outside light, stalks and lunges. Weak to brazier light,
## terrified of flares (long stun).

enum Mode { STALK, WINDUP, LUNGE, RETREAT }

var mode := Mode.STALK
var _t := 0.0
var _lunge_dir := Vector2.ZERO


func _ai(delta: float) -> void:
	_t -= delta
	match mode:
		Mode.STALK:
			var d := dist_to_target()
			velocity = path_dir() * speed
			if d < 88.0 and room and room.has_line_of_sight(global_position, target.global_position) and ai_time > 0.6:
				mode = Mode.WINDUP
				_t = 0.38
				telegraph(0.38)
				Audio.sfx("shade_hiss", -6.0)
		Mode.WINDUP:
			velocity = -dir_to_target() * 12.0
			if _t <= 0.0:
				mode = Mode.LUNGE
				_t = 0.32
				_lunge_dir = dir_to_target()
				sprite.play("lunge")
		Mode.LUNGE:
			velocity = _lunge_dir * speed * 4.2
			if _t <= 0.0:
				mode = Mode.RETREAT
				_t = 0.9
				sprite.play("float")
		Mode.RETREAT:
			velocity = -dir_to_target() * speed * 0.8
			if _t <= 0.0:
				mode = Mode.STALK
				ai_time = 0.0


func _on_hit(info: Dictionary) -> void:
	if info.get("kind", "") == "flare":
		mode = Mode.RETREAT
		_t = 1.5
