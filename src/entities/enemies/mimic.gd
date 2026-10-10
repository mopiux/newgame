class_name Mimic
extends Enemy
## Farol Falso: disguised as an unlit brazier. Approach it (or try to light
## it) and it wakes up hungry, locking the room.

var dormant := true
var interact_range := 22.0
var _bite_t := 0.0


func _ready() -> void:
	if dormant:
		spawning = 0.0
	super._ready()
	if dormant:
		remove_from_group("enemies")
		add_to_group("interactables")
		sprite.play("dormant")
		spawning = 0.0
		sprite.scale = Vector2.ONE
		sprite.self_modulate.a = 1.0
	else:
		sprite.play("awake")


func can_interact(_p) -> bool:
	return dormant


func prompt_text() -> String:
	return tr("PROMPT_LIGHT") % int(Database.balance_value("brazier.cost", 8))


func interact(_p) -> void:
	awaken()


func awaken() -> void:
	if not dormant:
		return
	dormant = false
	remove_from_group("interactables")
	add_to_group("enemies")
	sprite.play("awake")
	telegraph(0.4)
	Audio.sfx("mimic_scream", 0.0)
	Fx.shake(4.0, 0.3)
	Fx.burst(get_parent(), global_position + Vector2(0, -8), "wisps", 1.5)
	stun = 0.5
	if room:
		room.on_ambush()


func is_hittable() -> bool:
	return not dormant and super.is_hittable()


func _physics_process(delta: float) -> void:
	if dormant:
		if target and is_instance_valid(target) and dist_to_target() < float(data.get("wake_distance", 30.0)):
			awaken()
		elif target == null:
			targets_refresh()
		return
	super._physics_process(delta)


func _ai(delta: float) -> void:
	_bite_t -= delta
	var dir := path_dir()
	var lunge := 1.0
	if dist_to_target() < 40.0 and _bite_t <= 0.0:
		_bite_t = 1.1
		lunge = 3.0
		Audio.sfx("bite", -4.0)
	velocity = dir * speed * lunge
