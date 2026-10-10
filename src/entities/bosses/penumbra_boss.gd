class_name PenumbraBoss
extends Boss
## La Penumbra, heart of the darkness under Velaluz.
## Phase 1: spirals and shades. Phase 2 "El Velo": almost immune unless she
## stands in brazier light - and she snuffs braziers out. Phase 3: the arena
## darkens and her hands hunt the lamplighter.

var _spin := 0.0
var _anchor := Vector2.ZERO
var _dark: LightEmitter
var _snuff_cd := 5.0


func _on_ready() -> void:
	phase_thresholds = [0.66, 0.33]
	_dark = LightEmitter.new()
	_dark.radius = 520.0
	_dark.energy = 0.0
	_dark.flicker = 0.0
	_dark.priority = 90
	_dark.enabled = false
	add_child(_dark)


func _on_phase(p: int) -> void:
	super._on_phase(p)
	if p == 2:
		Events.toast.emit(tr("TOAST_VEIL"), UITheme.CURSE)
	if p == 3:
		_dark.enabled = true
		_dark.energy = -0.35
		Events.toast.emit(tr("TOAST_HEART"), UITheme.CURSE)


func _idle_move(delta: float) -> void:
	_spin += delta
	if _anchor == Vector2.ZERO or global_position.distance_to(_anchor) < 8.0:
		var c := arena_center()
		_anchor = c + Vector2(randf_range(-120, 120), randf_range(-50, 40))
	velocity = velocity.move_toward((_anchor - global_position).normalized() * speed, 200.0 * delta)
	_snuff_cd -= delta


func _choose_attack() -> String:
	match phase:
		1:
			return ["spiral", "shades", "spiral"][randi() % 3]
		2:
			if _snuff_cd <= 0.0 and _any_lit():
				return "snuff_brazier"
			return ["spiral", "drift", "shades"][randi() % 3]
	return ["spiral", "hands", "spiral", "hands", "shades"][randi() % 5]


func _any_lit() -> bool:
	for b in get_tree().get_nodes_in_group("braziers"):
		if b.is_lit:
			return true
	return false


func _begin_attack(a: String) -> void:
	sprite.play("cast")
	if a == "spiral":
		Audio.sfx("orb_cast", -2.0, 0.0, 0.6)


func _attack_process(a: String, delta: float) -> bool:
	match a:
		"spiral":
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			_spin += delta * (1.6 if phase < 3 else 2.2)
			var period := 0.14 if phase < 3 else 0.11
			if int((attack_t - delta) / period) != int(attack_t / period):
				var arms := 2 if phase == 1 else 3
				for i in arms:
					shoot_at(Vector2.RIGHT.rotated(_spin + TAU * i / arms), 70.0, 9.0)
			if attack_t > 3.2:
				sprite.play("idle")
				return true
			return false
		"shades":
			velocity = Vector2.ZERO
			if attack_t >= 0.5 and attack_t - delta < 0.5 and room:
				for i in (2 if phase < 3 else 3):
					var s := Shade.new()
					s.setup("shade", room.depth)
					s.embers = 1
					s.position = room.random_floor_point(RunRng.make(randi(), "p"), target.global_position - room.global_position if target else Vector2.ZERO, 90.0)
					room.add_enemy(s)
			if attack_t > 1.0:
				sprite.play("idle")
				return true
			return false
		"drift":
			# glides past a brazier (lit or not): an opening if the player lit it
			var b := _nearest_brazier()
			if b == null:
				return true
			var goal := b.global_position + Vector2(0, -24)
			velocity = (goal - global_position).normalized() * speed * 1.4
			if global_position.distance_to(goal) < 10.0 or attack_t > 4.0:
				sprite.play("idle")
				return attack_t > 2.6
			return false
		"snuff_brazier":
			velocity = Vector2.ZERO
			if attack_t >= 0.9 and attack_t - delta < 0.9:
				var lit := []
				for b in get_tree().get_nodes_in_group("braziers"):
					if b.is_lit:
						lit.append(b)
				if not lit.is_empty():
					var victim: Brazier = lit[randi() % lit.size()]
					_extinguish(victim)
				ring(12, 60.0, 8.0, randf() * TAU)
				_snuff_cd = 12.0
			if attack_t > 1.4:
				sprite.play("idle")
				return true
			return false
		"hands":
			velocity = Vector2.ZERO
			for i in 3:
				var t0 := 0.3 + i * 0.5
				if attack_t >= t0 and attack_t - delta < t0 and target:
					var p := shoot_at(dir_to_target().rotated(randf_range(-0.6, 0.6)), 55.0, 11.0, "orb")
					p.homing = 0.8
					p.lifetime = 4.5
					p.drain_light = true
			if attack_t > 2.0:
				sprite.play("idle")
				return true
			return false
	return true


func _nearest_brazier() -> Brazier:
	var best: Brazier = null
	var best_d := INF
	for b in get_tree().get_nodes_in_group("braziers"):
		var d := global_position.distance_to(b.global_position)
		if d < best_d and d > 30.0:
			best_d = d
			best = b
	return best


func _extinguish(b: Brazier) -> void:
	b.is_lit = false
	b.light.enabled = false
	b.sprite.play("unlit")
	b.add_to_group("interactables")
	Fx.burst(b.get_parent(), b.global_position + Vector2(0, -12), "wisps", 2.0)
	Audio.sfx("snuff", -2.0)
	if room:
		var lit: Array = room.state.get("lit", [])
		lit.erase(b.index)


func _damage_taken_mult(info: Dictionary) -> float:
	if phase == 2:
		var lit := Lights.static_light_at(global_position + Vector2(0, -16)) > 0.25
		if not lit and info.get("kind", "") != "flare":
			return 0.25
	return 1.0


func die(info: Dictionary) -> void:
	if _dark:
		_dark.enabled = false
	super.die(info)


func _post_move(_delta: float) -> void:
	pass
