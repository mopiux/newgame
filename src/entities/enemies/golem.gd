class_name Golem
extends Enemy
## Wax golem: lumbering tank that charges in a straight line. If it slams
## into a wall it is stunned and takes double damage - dodge, then punish.

enum Mode { WALK, WINDUP, CHARGE, DAZED }

var mode := Mode.WALK
var _t := 0.0
var _charge_dir := Vector2.ZERO
var _cooldown := 1.5


func _ai(delta: float) -> void:
	_t -= delta
	_cooldown -= delta
	match mode:
		Mode.WALK:
			velocity = path_dir() * speed
			if _cooldown <= 0.0 and dist_to_target() < 170.0 and room and room.has_line_of_sight(global_position, target.global_position):
				mode = Mode.WINDUP
				_t = 0.7
				telegraph(0.7)
				sprite.play("windup")
				Audio.sfx("golem_roar", -4.0)
		Mode.WINDUP:
			velocity = Vector2.ZERO
			_charge_dir = dir_to_target()
			if _t <= 0.0:
				mode = Mode.CHARGE
				_t = 1.3
				contact_damage = float(data.get("charge_damage", 16.0)) * dmg_mult
				sprite.play("charge")
		Mode.CHARGE:
			velocity = _charge_dir * speed * 4.8
			if get_slide_collision_count() > 0 and _t < 1.2:
				var col := get_slide_collision(0)
				if col and col.get_collider() and not (col.get_collider() is Enemy):
					_daze()
					return
			if _t <= 0.0:
				_end_charge(0.6)
		Mode.DAZED:
			velocity = Vector2.ZERO
			if _t <= 0.0:
				_end_charge(1.8)


func _daze() -> void:
	mode = Mode.DAZED
	_t = 1.5
	contact_damage = 0.0
	sprite.play("dazed")
	Fx.shake(5.0, 0.3)
	Fx.burst(get_parent(), global_position, "wax", 2.0)
	Audio.sfx("slam", 0.0)


func _end_charge(cd: float) -> void:
	mode = Mode.WALK
	_cooldown = cd + randf() * 0.8
	contact_damage = float(data.get("contact_damage", 10.0)) * dmg_mult
	sprite.play("walk")


func _damage_taken_mult(_info: Dictionary) -> float:
	return 2.0 if mode == Mode.DAZED else 1.0


func _post_move(delta: float) -> void:
	super._post_move(delta)
