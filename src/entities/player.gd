class_name Player
extends CharacterBody2D
## The lamplighter. The flame is health, ammunition and light radius at once.

signal shot_fired(proj: Projectile)
signal hit_enemy(enemy: Node2D, info: Dictionary)
signal killed_enemy(enemy: Node2D)
signal took_damage(amount: float)
signal dashed(from: Vector2, to: Vector2)
signal flared(pos: Vector2)
signal meleed(pos: Vector2, dir: Vector2)

enum State { NORMAL, DASH, DEAD, LOCKED }

const INTERACT_RANGE := 22.0

var run: RunState
var stats: Stats
var state: State = State.NORMAL
var aim_dir := Vector2.DOWN
var move_dir := Vector2.ZERO
var facing := "down"
var invuln := 0.0
var knock := Vector2.ZERO
var slow_timer := 0.0
var shield_charges := 0
var shrink_timer := 0.0        # temporary light shrink (snuffer orbs)
var aim_source := "mouse"
var focus_interactable: Node = null
var hub_mode := false           # plaza: no shooting, no flame loss
var bot: Object = null          # autopilot used by automated play tests
var _move_vel := Vector2.ZERO

var _fire_cd := 0.0
var _melee_cd := 0.0
var _dash_cd := 0.0
var _flare_cd := 0.0
var _dash_time := 0.0
var _dash_dir := Vector2.ZERO
var _afterimage_t := 0.0
var _step_t := 0.0
var _low_beat_t := 0.0
var _last_mouse := Vector2.ZERO
var _shot_counter := 0

var body: AnimatedSprite2D
var lantern_pivot: Node2D
var lantern: AnimatedSprite2D
var light: LightEmitter
var relic_fx: RelicEffects


func _ready() -> void:
	add_to_group("player")
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.PROPS
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.5
	shape.shape = circle
	add_child(shape)
	var shadow := Sprite2D.new()
	shadow.texture = SpriteLib.texture("shadow")
	shadow.position = Vector2(0, 1)
	shadow.z_index = -1
	add_child(shadow)
	body = SpriteLib.make_sprite("player", "idle_down")
	body.material = Fx.make_flash_material()
	add_child(body)
	lantern_pivot = Node2D.new()
	lantern_pivot.position = Vector2(0, -7)
	add_child(lantern_pivot)
	lantern = SpriteLib.make_sprite("lantern", "burn")
	lantern.z_as_relative = false
	lantern.z_index = Layers.Z_EMISSIVE
	lantern_pivot.add_child(lantern)
	light = LightEmitter.new()
	light.priority = 100
	light.flicker = 0.035
	light.color = Color(1.0, 0.82, 0.6)
	lantern.add_child(light)
	relic_fx = RelicEffects.new()
	relic_fx.name = "RelicEffects"
	add_child(relic_fx)
	if run:
		relic_fx.setup(self)


func setup(run_state: RunState) -> void:
	run = run_state
	stats = run.stats
	if relic_fx:
		relic_fx.setup(self)


func max_flame() -> float:
	return stats.get_stat("max_flame") if stats else 100.0


func flame_ratio() -> float:
	return clampf(run.flame / max_flame(), 0.0, 1.0) if run else 1.0


func is_alive() -> bool:
	return state != State.DEAD


func lock(locked: bool) -> void:
	if state == State.DEAD:
		return
	state = State.LOCKED if locked else State.NORMAL
	if locked:
		velocity = Vector2.ZERO


# --- per-frame ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_update_light(delta)
	match state:
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, 600 * delta)
			move_and_slide()
			return
		State.LOCKED:
			_move_vel = Vector2.ZERO
			velocity = velocity.move_toward(Vector2.ZERO, 900 * delta)
			move_and_slide()
			_animate()
			return
		State.DASH:
			_dash_step(delta)
			return
	var inp := _gather_input()
	move_dir = inp.move
	var speed := stats.get_stat("move_speed") if stats else 100.0
	if slow_timer > 0.0:
		speed *= 0.55
	var target := move_dir * speed
	var accel := 1100.0 if move_dir != Vector2.ZERO else 1400.0
	_move_vel = _move_vel.move_toward(target, accel * delta)
	velocity = _move_vel + knock
	knock = knock.move_toward(Vector2.ZERO, 900 * delta)
	move_and_slide()
	_animate()
	_footsteps(delta)
	_update_interact()
	if inp.interact:
		_try_interact()
	if inp.dash:
		_start_dash()
	if hub_mode:
		return
	if inp.shoot:
		_try_shoot()
	if inp.melee:
		_try_melee()
	if inp.flare:
		_try_flare()
	_check_contact_damage()


## Input for this frame, from the devices or from an autopilot (tests/bot).
func _gather_input() -> Dictionary:
	if bot != null:
		return bot.get_input(self)
	_read_aim()
	return {
		"move": Input.get_vector("move_left", "move_right", "move_up", "move_down"),
		"shoot": Input.is_action_pressed("shoot"),
		"melee": Input.is_action_just_pressed("melee"),
		"dash": Input.is_action_just_pressed("dash"),
		"flare": Input.is_action_just_pressed("flare"),
		"interact": Input.is_action_just_pressed("interact"),
	}


func _tick_timers(delta: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_melee_cd = maxf(0.0, _melee_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_flare_cd = maxf(0.0, _flare_cd - delta)
	slow_timer = maxf(0.0, slow_timer - delta)
	shrink_timer = maxf(0.0, shrink_timer - delta)
	if invuln > 0.0:
		invuln -= delta
		body.visible = state == State.DEAD or int(invuln * 20.0) % 2 == 0 or invuln <= 0.0
	else:
		body.visible = true


func _read_aim() -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	var mouse := get_viewport().get_mouse_position()
	if stick.length() > 0.3:
		aim_source = "stick"
		aim_dir = stick.normalized()
	elif mouse.distance_to(_last_mouse) > 0.5:
		aim_source = "mouse"
	_last_mouse = mouse
	if aim_source == "mouse":
		var d := get_global_mouse_position() - lantern_pivot.global_position
		if d.length() > 2.0:
			aim_dir = d.normalized()
	elif stick.length() <= 0.3:
		# gamepad without right-stick input: aim assist or movement direction
		var target := _assist_target() if Settings.get_value("access", "aim_assist") else null
		if target:
			aim_dir = (target.global_position - global_position).normalized()
		elif move_dir.length() > 0.2:
			aim_dir = move_dir.normalized()


func _assist_target() -> Node2D:
	var best: Node2D = null
	var best_d := 220.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.is_targetable():
			var d: float = global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best


func _animate() -> void:
	var a := aim_dir
	if absf(a.y) > absf(a.x) * 0.9:
		facing = "up" if a.y < 0 else "down"
		body.flip_h = false
	else:
		facing = "side"
		body.flip_h = a.x < 0
	var moving := velocity.length() > 12.0
	var anim := ("run_" if moving else "idle_") + facing
	if invuln > 0.6 and state != State.DEAD:
		anim = "hurt_" + facing
	if body.animation != anim:
		body.play(anim)
	# lantern held towards the aim, bobbing with the walk
	var bob := sin(Time.get_ticks_msec() * 0.012) * (1.0 if moving else 0.4)
	# held in the hand on the aiming side, pushed a little towards the aim
	var side := 1.0 if aim_dir.x >= -0.05 else -1.0
	lantern.position = Vector2(5.0 * side, 1.0 + bob) + aim_dir * 5.0
	lantern.z_index = Layers.Z_EMISSIVE if aim_dir.y > -0.3 else Layers.Z_EMISSIVE - 1
	lantern.play("low" if flame_ratio() < 0.25 else "burn")


func _update_light(delta: float) -> void:
	if light == null or stats == null:
		return
	var ratio := flame_ratio() if not hub_mode else 1.0
	var r := lerpf(stats.get_stat("light_min"), stats.get_stat("light_max"), pow(ratio, 0.7))
	r *= stats.get_stat("light_mult")
	if shrink_timer > 0.0:
		r *= 0.6
	if state == State.DEAD:
		r = move_toward(light.radius, 0.0, 60.0 * delta)
	light.radius = lerpf(light.radius, r, clampf(delta * 6.0, 0.0, 1.0)) if light.radius > 0.0 else r
	light.flicker = 0.035 + (0.08 if ratio < 0.25 else 0.0)
	if ratio < 0.25 and state != State.DEAD and not hub_mode:
		_low_beat_t -= delta
		if _low_beat_t <= 0.0:
			_low_beat_t = 0.9
			Audio.sfx("heartbeat", -6.0, 0.0)


func _footsteps(delta: float) -> void:
	if velocity.length() < 20.0:
		_step_t = 0.0
		return
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.28
		Audio.sfx("step", -14.0, 0.15)


# --- actions ----------------------------------------------------------------

func _try_shoot() -> void:
	if _fire_cd > 0.0:
		return
	var cost := stats.get_stat("shot_cost")
	if run.flame <= cost + 0.5:
		_fire_cd = 0.35
		Audio.sfx("fizzle", -6.0)
		return
	_fire_cd = 1.0 / maxf(0.5, stats.get_stat("fire_rate") * relic_fx.fire_rate_mult())
	spend_flame(cost)
	var count := maxi(1, stats.get_int("shot_count"))
	var spread := deg_to_rad(stats.get_stat("shot_spread"))
	var origin := lantern.global_position
	_shot_counter += 1
	var big := relic_fx.is_big_shot(_shot_counter)
	for i in count:
		var off := (i - (count - 1) * 0.5) * spread
		var dir := aim_dir.rotated(off + randf_range(-0.03, 0.03))
		var p := Projectile.player_shot(self, origin, dir, big)
		get_parent().add_child(p)
		shot_fired.emit(p)
	light.pulse(14.0, 0.12)
	knock -= aim_dir * 12.0
	Audio.sfx("shoot", -5.0, 0.1)


func _try_melee() -> void:
	if _melee_cd > 0.0:
		return
	_melee_cd = stats.get_stat("melee_cooldown")
	var rng_ := stats.get_stat("melee_range")
	var arc := deg_to_rad(stats.get_stat("melee_arc")) * 0.5
	var dmg := stats.get_stat("melee_damage")
	var center := global_position + Vector2(0, -6)
	var swing := MeleeSwing.new()
	swing.setup(aim_dir, rng_, arc)
	swing.position = center
	get_parent().add_child(swing)
	Audio.sfx("swing", -4.0, 0.12)
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or not e.is_hittable():
			continue
		var to: Vector2 = e.global_position + Vector2(0, -4) - center
		if to.length() <= rng_ + e.hit_radius and absf(aim_dir.angle_to(to)) <= arc + 0.25:
			var info := {"damage": dmg, "kind": "melee", "knockback": to.normalized() * stats.get_stat("melee_knockback"), "source": self}
			relic_fx.modify_hit(e, info)
			e.take_hit(info)
			hit_enemy.emit(e, info)
			hit_any = true
	# melee destroys enemy projectiles: the counter to orb-throwers
	for p in get_tree().get_nodes_in_group("enemy_shots"):
		var to2: Vector2 = p.global_position - center
		if to2.length() <= rng_ + 6.0 and absf(aim_dir.angle_to(to2)) <= arc + 0.35:
			p.deflect(self)
			hit_any = true
	for b in get_tree().get_nodes_in_group("breakables"):
		var to3: Vector2 = b.global_position - center
		if to3.length() <= rng_ + 8.0 and absf(aim_dir.angle_to(to3)) <= arc + 0.3:
			b.break_open(self)
	if hit_any:
		Fx.hit_stop(0.05)
		Fx.shake(2.0, 0.1)
	meleed.emit(center, aim_dir)


func _start_dash() -> void:
	if _dash_cd > 0.0 or state != State.NORMAL:
		return
	var dir := move_dir if move_dir.length() > 0.2 else aim_dir
	_dash_dir = dir.normalized()
	_dash_time = stats.get_stat("dash_time")
	_dash_cd = stats.get_stat("dash_cooldown")
	state = State.DASH
	invuln = maxf(invuln, _dash_time + 0.05)
	_afterimage_t = 0.0
	Audio.sfx("dash", -4.0, 0.1)
	body.play("dash_" + facing)
	var from := global_position
	dashed.emit(from, from + _dash_dir * stats.get_stat("dash_speed") * _dash_time)


func _dash_step(delta: float) -> void:
	_dash_time -= delta
	_move_vel = _dash_dir * stats.get_stat("move_speed")
	velocity = _dash_dir * stats.get_stat("dash_speed")
	move_and_slide()
	_afterimage_t -= delta
	if _afterimage_t <= 0.0:
		_afterimage_t = 0.03
		Fx.afterimage(get_parent(), body)
	if _dash_time <= 0.0:
		state = State.NORMAL


func _try_flare() -> void:
	if _flare_cd > 0.0:
		return
	var cost := stats.get_stat("flare_cost") * relic_fx.flare_cost_mult()
	if run.flame <= cost + 1.0:
		Audio.sfx("fizzle", -6.0)
		_flare_cd = 0.3
		return
	spend_flame(cost)
	_flare_cd = stats.get_stat("flare_cooldown")
	var burst := FlareBurst.new()
	burst.setup(self, stats.get_stat("flare_radius"), stats.get_stat("flare_damage"))
	burst.position = global_position + Vector2(0, -6)
	get_parent().add_child(burst)
	light.pulse(110.0, 0.7)
	flared.emit(global_position)


func _update_interact() -> void:
	var best: Node = null
	var best_d := INTERACT_RANGE
	for n in get_tree().get_nodes_in_group("interactables"):
		if not n.has_method("can_interact") or not n.can_interact(self):
			continue
		var d: float = global_position.distance_to(n.global_position)
		var r: float = n.get("interact_range") if n.get("interact_range") != null else INTERACT_RANGE
		if d < maxf(r, best_d) and (best == null or d < best_d):
			best_d = d
			best = n
	focus_interactable = best


func _try_interact() -> void:
	if focus_interactable and is_instance_valid(focus_interactable):
		focus_interactable.interact(self)


func _check_contact_damage() -> void:
	if invuln > 0.0:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.contact_damage > 0.0 and e.is_hittable():
			if global_position.distance_to(e.global_position) < e.hit_radius + 5.0:
				take_damage(e.contact_damage, e.global_position, e)
				return


# --- flame -------------------------------------------------------------------

func spend_flame(amount: float) -> void:
	if hub_mode:
		return
	run.flame = maxf(0.0, run.flame - amount)
	Events.player_flame_changed.emit(run.flame, max_flame())


func add_flame(amount: float) -> void:
	if run == null or state == State.DEAD:
		return
	var before := run.flame
	run.flame = minf(max_flame(), run.flame + amount)
	relic_fx.on_flame_gained(run.flame - before, amount - (run.flame - before))
	Events.player_flame_changed.emit(run.flame, max_flame())


func take_damage(amount: float, from_pos: Vector2, source: Node = null) -> void:
	if state == State.DEAD or invuln > 0.0 or hub_mode or state == State.LOCKED:
		return
	if relic_fx.try_block_hit():
		invuln = 0.5
		Fx.burst(get_parent(), global_position + Vector2(0, -8), "wax", 1.5)
		Audio.sfx("shield", -2.0)
		return
	amount *= stats.get_stat("damage_taken_mult")
	run.flame = maxf(0.0, run.flame - amount)
	invuln = stats.get_stat("iframes")
	var dir := (global_position - from_pos).normalized()
	knock = dir * 140.0
	Fx.flash(body, 0.15, Color("ffffff"))
	Fx.shake(5.0, 0.25)
	Fx.hit_stop(0.07)
	Fx.burst(get_parent(), global_position + Vector2(0, -8), "embers", 0.8)
	Fx.damage_number(get_parent(), global_position + Vector2(0, -10), amount, "player")
	Audio.sfx("hurt", -2.0, 0.08)
	Events.player_damaged.emit(amount, source)
	Events.player_flame_changed.emit(run.flame, max_flame())
	took_damage.emit(amount)
	if run.flame <= 0.0:
		if relic_fx.try_revive():
			return
		die()


func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	invuln = 99.0
	body.visible = true
	body.play("dead")
	lantern.play("low")
	Audio.sfx("extinguish", 0.0, 0.0)
	Fx.burst(get_parent(), global_position + Vector2(0, -8), "dust", 2.0)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(func(): Events.player_died.emit())


## Returns cooldown progress 0..1 (1 = ready) for the HUD.
func cooldown_ratio(which: String) -> float:
	match which:
		"dash":
			return 1.0 - _dash_cd / maxf(0.01, stats.get_stat("dash_cooldown"))
		"flare":
			return 1.0 - _flare_cd / maxf(0.01, stats.get_stat("flare_cooldown"))
	return 1.0


func reset_cooldowns() -> void:
	_fire_cd = 0.0
	_melee_cd = 0.0
	_dash_cd = 0.0
	_flare_cd = 0.0


func reduce_flare_cooldown(seconds: float) -> void:
	_flare_cd = maxf(0.0, _flare_cd - seconds)
