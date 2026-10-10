class_name Enemy
extends CharacterBody2D
## Base creature: stats from data/enemies.json, spawn animation, hit
## feedback, statuses (stun, burn), light weakness and ember drops.
## Subclasses implement _ai(delta) and may override hooks.

var id := ""
var data: Dictionary = {}
var hp := 10.0
var max_hp := 10.0
var speed := 40.0
var contact_damage := 6.0
var hit_radius := 6.0
var body_height := 10.0
var embers := 1
var elite := false
var flying := false
var light_weakness := 0.25       # extra damage taken standing in brazier light
var hide_in_dark := false        # shades: invisible outside light
var dmg_mult := 1.0

var room: Room
var target: Player
var sprite: AnimatedSprite2D
var shadow: Sprite2D
var stun := 0.0
var knock := Vector2.ZERO
var spawning := 0.7
var dead := false
var burn_time := 0.0
var burn_dps := 0.0
var _burn_tick := 0.0
var _light_fx_t := 0.0
var in_brazier_light := false
var visibility_alpha := 1.0
var ai_time := 0.0


func setup(enemy_id: String, depth: int, is_elite: bool = false) -> void:
	id = enemy_id
	data = Database.enemies.get(enemy_id, {})
	elite = is_elite
	var hp_scale := 1.0 + float(Database.balance_value("difficulty.hp_per_depth", 0.3)) * (depth - 1)
	var dmg_scale := 1.0 + float(Database.balance_value("difficulty.damage_per_depth", 0.15)) * (depth - 1)
	hp_scale *= Game.ascension_mult("enemy_hp")
	dmg_scale *= Game.ascension_mult("enemy_damage")
	if elite:
		hp_scale *= float(Database.balance_value("difficulty.elite_hp", 1.8))
	max_hp = float(data.get("hp", 10)) * hp_scale
	hp = max_hp
	speed = float(data.get("speed", 40)) * Game.ascension_mult("enemy_speed")
	dmg_mult = dmg_scale
	contact_damage = float(data.get("contact_damage", 0)) * dmg_scale
	hit_radius = float(data.get("radius", 6))
	body_height = float(data.get("height", 10))
	embers = int(data.get("embers", 1)) + (2 if elite else 0)
	flying = bool(data.get("flying", false))
	light_weakness = float(data.get("light_weakness", 0.25))
	hide_in_dark = bool(data.get("hide_in_dark", false))


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = Layers.ENEMIES
	collision_mask = Layers.WORLD | Layers.PROPS | (0 if flying else Layers.ENEMIES)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = maxf(3.0, hit_radius - 1.5)
	shape.shape = circle
	add_child(shape)
	shadow = Sprite2D.new()
	shadow.texture = SpriteLib.texture("shadow")
	shadow.z_index = -1
	var sw := clampf(hit_radius / 6.0, 0.6, 3.0)
	shadow.scale = Vector2(sw, sw)
	add_child(shadow)
	sprite = SpriteLib.make_sprite(str(data.get("sprite", id)), str(data.get("anim", "")))
	sprite.material = Fx.make_flash_material()
	if elite:
		sprite.modulate = Color(1.25, 1.0, 0.8)
	if flying:
		sprite.position.y = -6
	add_child(sprite)
	targets_refresh()
	_on_ready()
	# spawn: rise out of the dark
	sprite.scale = Vector2(0.2, 1.6)
	sprite.self_modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "scale", Vector2.ONE, spawning).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "self_modulate:a", 1.0, spawning * 0.6)
	Fx.burst(get_parent(), global_position, "wisps", 0.6)
	SaveManager.mark_seen("enemies", id)


func _on_ready() -> void:
	pass


func targets_refresh() -> void:
	var players := get_tree().get_nodes_in_group("player")
	target = players[0] if not players.is_empty() else null


func is_hittable() -> bool:
	return not dead and spawning <= 0.0


func is_targetable() -> bool:
	return is_hittable() and visibility_alpha > 0.35


func _physics_process(delta: float) -> void:
	if dead:
		return
	if spawning > 0.0:
		spawning -= delta
		return
	ai_time += delta
	if target == null or not is_instance_valid(target):
		targets_refresh()
	_tick_status(delta)
	if stun > 0.0:
		stun -= delta
		velocity = knock
		knock = knock.move_toward(Vector2.ZERO, 700 * delta)
		move_and_slide()
		return
	_ai(delta)
	velocity += knock
	knock = knock.move_toward(Vector2.ZERO, 700 * delta)
	move_and_slide()
	_post_move(delta)


func _ai(_delta: float) -> void:
	pass


func _post_move(_delta: float) -> void:
	if absf(velocity.x) > 4.0:
		sprite.flip_h = velocity.x < 0.0
	shadow.position = Vector2(0, 1)


func _tick_status(delta: float) -> void:
	var sl := Lights.static_light_at(global_position)
	in_brazier_light = sl > 0.35
	if hide_in_dark:
		var l := Lights.light_at(global_position + Vector2(0, -4))
		var always: bool = Settings.get_value("access", "enemy_outlines")
		visibility_alpha = clampf((l - 0.08) * 3.0, 0.0, 1.0)
		if always:
			visibility_alpha = maxf(visibility_alpha, 0.45)
		sprite.modulate.a = visibility_alpha
		shadow.visible = visibility_alpha > 0.2
	if in_brazier_light and light_weakness > 0.0:
		_light_fx_t -= delta
		if _light_fx_t <= 0.0:
			_light_fx_t = 0.35
			Fx.burst(get_parent(), global_position + Vector2(randf_range(-4, 4), -body_height), "embers", 0.15)
	if burn_time > 0.0:
		burn_time -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 0.5
			_apply_damage(burn_dps * 0.5, "burn", null)
			Fx.burst(get_parent(), global_position + Vector2(0, -body_height * 0.6), "embers", 0.2)


func take_hit(info: Dictionary) -> void:
	if not is_hittable():
		return
	var dmg: float = info.get("damage", 1.0)
	if in_brazier_light:
		dmg *= 1.0 + light_weakness
	var resist := _damage_taken_mult(info)
	dmg *= resist
	var kind := "normal"
	if resist < 0.5:
		# shrugged off: make it obvious so the player changes approach
		kind = "immune"
		Audio.sfx("deflect", -10.0, 0.05, 1.6)
	elif info.get("crit", false):
		kind = "crit"
	elif in_brazier_light and light_weakness >= 0.4:
		kind = "light"
	var kb: Vector2 = info.get("knockback", Vector2.ZERO)
	knock += kb * float(data.get("knockback_mult", 1.0))
	if info.has("stun"):
		stun = maxf(stun, float(info.stun) * float(data.get("stun_mult", 1.0)))
	if info.get("burn", 0.0) > 0.0:
		burn_time = 3.0
		burn_dps = maxf(burn_dps, float(info.burn))
	Fx.flash(sprite, 0.1)
	_apply_damage(dmg, kind, info)
	_on_hit(info)


func _damage_taken_mult(_info: Dictionary) -> float:
	return 1.0


func _apply_damage(dmg: float, kind: String, info) -> void:
	if dead:
		return
	hp -= dmg
	Fx.damage_number(get_parent(), global_position + Vector2(0, -body_height), dmg, kind)
	Audio.sfx("hit", -8.0, 0.15)
	if hp <= 0.0:
		die(info if info != null else {})


func _on_hit(_info: Dictionary) -> void:
	pass


func die(info: Dictionary) -> void:
	if dead:
		return
	dead = true
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	var count := embers
	if room:
		room.drop_embers(global_position, count)
		if randf() < float(Database.balance_value("drops.spark_chance", 0.04)) or elite:
			room.drop_spark(global_position)
	Events.enemy_killed.emit(self, info)
	_on_death(info)
	Audio.sfx(str(data.get("death_sfx", "enemy_die")), -4.0, 0.12)
	Fx.burst(get_parent(), global_position + Vector2(0, -body_height * 0.5), str(data.get("death_fx", "embers")), 1.2)
	Fx.shake(1.5, 0.1)
	var m := sprite.material as ShaderMaterial
	var tw := create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter("dissolve", v), 0.0, 1.0, 0.35)
	tw.tween_callback(queue_free)


func _on_death(_info: Dictionary) -> void:
	pass


# --- helpers for behaviours -------------------------------------------------

func dir_to_target() -> Vector2:
	if target == null:
		return Vector2.ZERO
	return (target.global_position - global_position).normalized()


func dist_to_target() -> float:
	if target == null:
		return 9999.0
	return global_position.distance_to(target.global_position)


## Direction along the room flow field (walks around pillars).
func path_dir() -> Vector2:
	if room == null or target == null:
		return dir_to_target()
	if room.has_line_of_sight(global_position, target.global_position):
		return dir_to_target()
	var d := room.flow_dir(global_position)
	return d if d != Vector2.ZERO else dir_to_target()


func shoot_at(dir: Vector2, spd: float, dmg: float, sheet: String = "orb") -> Projectile:
	var p := Projectile.enemy_shot(self, global_position + Vector2(0, -body_height * 0.6), dir, spd, dmg * dmg_mult, sheet)
	get_parent().add_child(p)
	return p


func telegraph(duration: float) -> void:
	Fx.flash(sprite, duration, Color(1.0, 0.35, 0.5))
	var tw := create_tween()
	var base := sprite.position
	for i in int(duration / 0.05):
		tw.tween_property(sprite, "position", base + Vector2(randf_range(-1, 1), 0), 0.05)
	tw.tween_property(sprite, "position", base, 0.01)
