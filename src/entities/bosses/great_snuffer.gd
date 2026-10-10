class_name GreatSnuffer
extends Boss
## El Gran Apagador. Slams his bell to send rings of penumbra, snuffs the
## light of the whole crypt (only braziers hold out) and calls shades.
## After a slam the bell is stuck: that is the moment to strike.

var _dark: LightEmitter
var _stuck := false


func _on_ready() -> void:
	phase_thresholds = [0.5]
	_dark = LightEmitter.new()
	_dark.radius = 520.0
	_dark.energy = 0.0
	_dark.flicker = 0.0
	_dark.priority = 90
	_dark.enabled = false
	add_child(_dark)


func _idle_move(delta: float) -> void:
	if target == null:
		return
	var d := dist_to_target()
	var desired := path_dir() if d > 70.0 else Vector2.ZERO
	velocity = velocity.move_toward(desired * speed * (1.0 if phase == 1 else 1.35), 300.0 * delta)


func _choose_attack() -> String:
	var options := ["slam", "volley", "slam", "snuff"] if phase == 1 else ["slam", "volley", "snuff", "slam", "volley"]
	if dist_to_target() > 140.0:
		options = options.filter(func(o): return o != "slam")
	return options[randi() % options.size()]


func _begin_attack(a: String) -> void:
	match a:
		"slam":
			telegraph(0.8)
			sprite.play("raise")
			Audio.sfx("golem_roar", -2.0, 0.0, 0.7)
		"snuff":
			sprite.play("cast")
			Events.toast.emit(tr("TOAST_SNUFF"), UITheme.CURSE)
			Audio.sfx("snuff", 0.0, 0.0)
		"volley":
			sprite.play("cast")


func _attack_process(a: String, delta: float) -> bool:
	match a:
		"slam":
			velocity = Vector2.ZERO
			if attack_t >= 0.8 and attack_t - delta < 0.8:
				sprite.play("slam")
				_stuck = true
				ring(16, 75.0, 11.0, 0.0)
				if phase >= 2:
					var tw := create_tween()
					tw.tween_interval(0.35)
					tw.tween_callback(func(): if not dead: ring(16, 60.0, 11.0, PI / 16.0))
				Fx.shake(8.0, 0.4)
				Fx.burst(get_parent(), global_position, "stone", 3.0)
				Audio.sfx("slam", 0.0, 0.0, 0.8)
			if attack_t >= 2.1:
				_stuck = false
				sprite.play("walk")
				return true
			return false
		"snuff":
			velocity = Vector2.ZERO
			if attack_t < 0.6:
				return false
			_dark.enabled = true
			_dark.energy = -0.75 * clampf((attack_t - 0.6) / 0.6, 0.0, 1.0)
			if attack_t - delta < 0.9 and attack_t >= 0.9 and room:
				for i in (2 if phase == 1 else 3):
					var s := Shade.new()
					s.setup("shade", room.depth)
					s.embers = 1
					s.position = room.random_floor_point(RunRng.make(randi(), "s"), target.global_position - room.global_position if target else Vector2.ZERO, 90.0)
					room.add_enemy(s)
			if attack_t > 4.6:
				_dark.energy = 0.0
				_dark.enabled = false
				sprite.play("walk")
				return true
			return false
		"volley":
			velocity = Vector2.ZERO
			var shots := 3 if phase == 1 else 4
			for i in shots:
				var t0 := 0.4 + i * 0.45
				if attack_t >= t0 and attack_t - delta < t0 and target:
					for p in _fan_drain(dir_to_target(), 5, 0.2):
						p.drain_light = true
					Audio.sfx("orb_cast", -4.0)
			if attack_t > 0.4 + shots * 0.45 + 0.3:
				sprite.play("walk")
				return true
			return false
	return true


func _fan_drain(dir: Vector2, n: int, spread: float) -> Array:
	var out := []
	for i in n:
		out.append(shoot_at(dir.rotated((i - (n - 1) * 0.5) * spread), 95.0, 10.0))
	return out


func _damage_taken_mult(_info: Dictionary) -> float:
	return 1.6 if _stuck else 1.0


func die(info: Dictionary) -> void:
	if _dark:
		_dark.enabled = false
	super.die(info)
