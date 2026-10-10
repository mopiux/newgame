class_name GloomEye
extends Enemy
## Ojo de Penumbra: rooted turret that blooms rings of orbs. Closes (and
## shrugs off bolts) for a moment after each volley.

var _t := 1.8
var _ring := 0
var _closed := 0.0


func _ai(delta: float) -> void:
	velocity = Vector2.ZERO
	_t -= delta
	_closed -= delta
	if _closed <= 0.0 and sprite.animation != "open" and sprite.animation != "charge":
		sprite.play("open")
	if _t <= 0.45 and sprite.animation == "open":
		sprite.play("charge")
		telegraph(0.45)
	if _t <= 0.0:
		_t = float(data.get("fire_interval", 2.8))
		var n := int(data.get("orbs", 8))
		var off := (_ring % 2) * PI / n
		for i in n:
			shoot_at(Vector2.RIGHT.rotated(off + TAU * i / n), float(data.get("orb_speed", 70.0)), float(data.get("orb_damage", 7.0)))
		_ring += 1
		_closed = 0.9
		sprite.play("closed")
		Audio.sfx("orb_cast", -4.0, 0.05, 0.8)


func _damage_taken_mult(_info: Dictionary) -> float:
	return 0.35 if _closed > 0.0 else 1.0


func _post_move(_delta: float) -> void:
	pass
