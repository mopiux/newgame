class_name Wraith
extends Enemy
## Espectro de ceniza: blinks around the lamplighter and casts slow homing
## embers. Untouchable while it fades.

enum Mode { CAST, FADE_OUT, FADE_IN }

var mode := Mode.CAST
var _t := 1.4
var _cast := 0.8


func _ai(delta: float) -> void:
	_t -= delta
	match mode:
		Mode.CAST:
			velocity = Vector2(-dir_to_target().y, dir_to_target().x) * speed * 0.4
			_cast -= delta
			if _cast <= 0.0:
				_cast = 99.0
				var p := shoot_at(dir_to_target(), float(data.get("orb_speed", 60.0)), float(data.get("orb_damage", 9.0)), "orb_ember")
				p.homing = 0.5
				p.lifetime = 4.0
				Audio.sfx("orb_cast", -6.0, 0.05, 1.3)
			if _t <= 0.0:
				mode = Mode.FADE_OUT
				_t = 0.4
				var tw := create_tween()
				tw.tween_property(sprite, "modulate:a", 0.0, 0.4)
		Mode.FADE_OUT:
			velocity = Vector2.ZERO
			if _t <= 0.0:
				if room and target:
					global_position = room.random_point_near(target.global_position, 60.0, 110.0)
				mode = Mode.FADE_IN
				_t = 0.35
				var tw2 := create_tween()
				tw2.tween_property(sprite, "modulate:a", 1.0, 0.35)
				Audio.sfx("blink", -8.0)
		Mode.FADE_IN:
			velocity = Vector2.ZERO
			if _t <= 0.0:
				mode = Mode.CAST
				_t = 1.6
				_cast = 0.5


func is_hittable() -> bool:
	return super.is_hittable() and mode != Mode.FADE_OUT


func _post_move(_delta: float) -> void:
	if target:
		sprite.flip_h = target.global_position.x < global_position.x
