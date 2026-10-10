class_name MothMother
extends Boss
## La Madre Polilla. Flutters, dives at the lamplighter and calls swarms.
## Below half health she cannot resist a lit brazier: she hovers over it,
## dazzled, taking double damage - spend flame on braziers to open windows.

var _orbit := 0.0
var _dive_target := Vector2.ZERO
var _dive_from := Vector2.ZERO
var _marker: Node2D
var _lure: LightEmitter
var _lure_cd := 6.0


func _on_ready() -> void:
	phase_thresholds = [0.5]


func _idle_move(delta: float) -> void:
	_orbit += delta * (0.9 if phase == 1 else 1.3)
	var c := arena_center() + Vector2(0, -20)
	var goal := c + Vector2(cos(_orbit) * 110.0, sin(_orbit * 2.0) * 36.0)
	velocity = velocity.move_toward((goal - global_position) * 2.2, 400.0 * delta)
	_lure_cd -= delta


func _choose_attack() -> String:
	if phase >= 2 and _lure_cd <= 0.0:
		_lure = Lights.brightest_static_near(global_position, 600.0)
		if _lure:
			return "dazzled"
	var options := ["flutter", "dive", "swarm"] if phase == 1 else ["flutter", "dive", "dive", "swarm"]
	return options[randi() % options.size()]


func _begin_attack(a: String) -> void:
	match a:
		"dive":
			_dive_target = target.global_position if target else arena_center()
			_dive_from = global_position
			_marker = DiveMarker.new()
			_marker.position = _dive_target - (room.global_position if room else Vector2.ZERO)
			if room:
				room.entities.add_child(_marker)
			telegraph(0.8)
			Audio.sfx("boss_screech", -2.0)
		"swarm":
			sprite.play("cast")
			Audio.sfx("nest_pulse", 0.0, 0.0, 0.7)
		"dazzled":
			Events.toast.emit(tr("TOAST_DAZZLED"), UITheme.FLAME)


func _attack_process(a: String, delta: float) -> bool:
	match a:
		"flutter":
			_idle_move(delta)
			if int((attack_t - delta) / 0.9) != int(attack_t / 0.9) and target:
				fan(dir_to_target(), 5 if phase == 1 else 7, 0.22, 85.0, 9.0, "orb_ember")
				Audio.sfx("orb_cast", -6.0)
			return attack_t > 3.0
		"dive":
			if attack_t < 1.05:
				velocity = (global_position - _dive_target).normalized() * 30.0
				return false
			var k := clampf((attack_t - 1.05) / 0.4, 0.0, 1.0)
			global_position = _dive_from.lerp(_dive_target, k * k)
			velocity = Vector2.ZERO
			contact_damage = 18.0 * dmg_mult
			if k >= 1.0:
				contact_damage = float(data.get("contact_damage", 10)) * dmg_mult
				ring(10 if phase == 1 else 14, 70.0, 9.0, randf() * TAU, "orb_ember")
				Fx.shake(6.0, 0.3)
				Fx.burst(get_parent(), global_position, "dust", 3.0)
				Audio.sfx("slam", 0.0)
				if is_instance_valid(_marker):
					_marker.queue_free()
				return true
			return false
		"swarm":
			velocity = Vector2.ZERO
			if attack_t >= 0.6 and attack_t - delta < 0.6 and room:
				for i in (3 if phase == 1 else 4):
					var m := Moth.new()
					m.setup("moth", room.depth)
					m.embers = 1
					m.spawning = 0.3
					m.position = global_position - room.global_position + Vector2(randf_range(-20, 20), randf_range(-10, 10))
					room.add_enemy(m)
				sprite.play("fly")
			return attack_t > 1.0
		"dazzled":
			if _lure == null or not is_instance_valid(_lure) or not _lure.enabled:
				_lure_cd = 4.0
				return true
			var goal := _lure.global_position + Vector2(0, -18)
			velocity = (goal - global_position) * 3.0
			if global_position.distance_to(goal) < 14.0:
				stun = 0.0
				if attack_t > 4.5:
					_lure_cd = 9.0
					return true
			return attack_t > 6.0
	return true


func _damage_taken_mult(_info: Dictionary) -> float:
	if attack == "dazzled" and _lure and is_instance_valid(_lure) and global_position.distance_to(_lure.global_position + Vector2(0, -18)) < 20.0:
		return 2.0
	return 1.0


func _post_move(_delta: float) -> void:
	if target:
		sprite.flip_h = target.global_position.x < global_position.x


class DiveMarker extends Node2D:
	var t := 0.0

	func _ready() -> void:
		z_as_relative = false
		z_index = Layers.Z_EMISSIVE

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()
		if t > 1.6:
			queue_free()

	func _draw() -> void:
		var r := 6.0 + minf(t, 0.9) * 20.0
		var c := Color(0.85, 0.4, 0.65, 0.5 + 0.4 * sin(t * 20.0))
		draw_arc(Vector2.ZERO, r, 0, TAU, 24, c, 1.0)
		draw_arc(Vector2.ZERO, r * 0.5, 0, TAU, 16, Color(c, 0.3), 1.0)
