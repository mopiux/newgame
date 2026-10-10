class_name Snuffer
extends Enemy
## Apagavelas: keeps its distance and throws orbs of penumbra that shrink
## the lantern's light. Melee swings destroy its orbs.

var _shoot_t := 1.5
var _strafe := 1.0
var _winding := false


func _on_ready() -> void:
	_strafe = 1.0 if randf() < 0.5 else -1.0


func _ai(delta: float) -> void:
	var d := dist_to_target()
	var to := dir_to_target()
	var desired := Vector2.ZERO
	var keep := float(data.get("keep_distance", 110.0))
	if d > keep + 30.0:
		desired = path_dir()
	elif d < keep - 30.0:
		desired = -to
	desired += Vector2(-to.y, to.x) * _strafe * 0.7
	if randf() < delta * 0.4:
		_strafe = -_strafe
	velocity = desired.normalized() * speed * (0.35 if _winding else 1.0)
	_shoot_t -= delta
	if _shoot_t <= 0.5 and not _winding:
		_winding = true
		telegraph(0.5)
		sprite.play("attack")
	if _shoot_t <= 0.0:
		_shoot_t = float(data.get("fire_interval", 2.4)) + randf_range(-0.3, 0.3)
		_winding = false
		sprite.play("idle")
		var n := int(data.get("orbs", 3))
		for i in n:
			var p := shoot_at(to.rotated((i - (n - 1) * 0.5) * 0.3), float(data.get("orb_speed", 80.0)), float(data.get("orb_damage", 8.0)))
			p.drain_light = true
		Audio.sfx("orb_cast", -6.0)
