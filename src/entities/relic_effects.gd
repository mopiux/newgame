class_name RelicEffects
extends Node
## Behaviour side of relics. Plain stat changes live in data/relics.json and
## are applied by Stats; anything that reacts to events (kills, dashes, room
## clears, low flame...) is implemented here, keyed by relic id.

var player: Player
var run: RunState
var shield_ready := false
var _wisp: Wisp = null
var _decay_t := 0.0


func setup(p: Player) -> void:
	player = p
	run = p.run
	if not p.hit_enemy.is_connected(_on_hit):
		p.hit_enemy.connect(_on_hit)
		p.dashed.connect(_on_dashed)
		p.flared.connect(_on_flared)
		Events.enemy_killed.connect(_on_killed)
		Events.room_entered.connect(_on_room_entered)
		Events.room_cleared.connect(_on_room_cleared)
		Events.relic_gained.connect(_on_relic_gained)
	refresh()


func _on_relic_gained(_id: String) -> void:
	refresh()


func has(id: String) -> bool:
	return run != null and run.has_relic(id)


func count(id: String) -> int:
	return run.relic_count(id) if run else 0


func refresh() -> void:
	if has("twin_lantern"):
		if _wisp == null or not is_instance_valid(_wisp):
			_wisp = Wisp.new()
			_wisp.player = player
			player.add_child.call_deferred(_wisp)
		_wisp.level = count("twin_lantern")
	elif _wisp and is_instance_valid(_wisp):
		_wisp.queue_free()
		_wisp = null


func _process(delta: float) -> void:
	if player == null or not player.is_alive() or player.hub_mode:
		return
	if has("hungry_flame") and Game.in_combat():
		_decay_t += delta
		if _decay_t >= 1.0:
			_decay_t = 0.0
			if player.run.flame > 10.0:
				player.spend_flame(0.7 * count("hungry_flame"))


# --- queries used by Player / Projectile ------------------------------------------

func low_flame() -> bool:
	return player.flame_ratio() < 0.3


func fire_rate_mult() -> float:
	return 1.3 if has("living_ember") and low_flame() else 1.0


func flare_cost_mult() -> float:
	return 1.0


func is_big_shot(counter: int) -> bool:
	return has("candle_crown") and counter % maxi(2, 6 - count("candle_crown")) == 0


func bolt_sheet() -> String:
	return "bolt_blue" if has("blue_flame") or has("solar_heart") else "bolt"


func modify_hit(enemy: Node2D, info: Dictionary) -> void:
	var dmg: float = info.get("damage", 0.0)
	if randf() < player.stats.get_stat("crit_chance"):
		dmg *= 2.0
		info["crit"] = true
	if has("living_ember") and low_flame():
		dmg *= 1.4
	if has("tinder") and enemy is Enemy and enemy.room:
		var lit := 0
		for b in enemy.room.braziers:
			if b.is_lit:
				lit += 1
		dmg *= 1.0 + 0.12 * lit * count("tinder")
	if has("phosphor") and randf() < 0.3 * count("phosphor"):
		info["burn"] = 7.0
	info["damage"] = dmg


func try_block_hit() -> bool:
	if shield_ready and has("sealed_wax"):
		shield_ready = false
		Events.toast.emit(tr("TOAST_SHIELD"), UITheme.TEXT)
		return true
	return false


func try_revive() -> bool:
	if has("tallow_phoenix") and not run.revive_used:
		run.revive_used = true
		run.flame = player.max_flame() * 0.5
		player.invuln = 2.0
		Events.player_flame_changed.emit(run.flame, player.max_flame())
		Events.toast.emit(tr("TOAST_PHOENIX"), UITheme.FLAME)
		Fx.burst(player.get_parent(), player.global_position + Vector2(0, -8), "embers", 4.0)
		Fx.shake(6.0, 0.4)
		Audio.sfx("phoenix", 0.0, 0.0)
		player.light.pulse(160.0, 1.0)
		for e in player.get_tree().get_nodes_in_group("enemies"):
			if e is Enemy and e.global_position.distance_to(player.global_position) < 90.0:
				e.take_hit({"damage": 30.0, "kind": "flare", "knockback": (e.global_position - player.global_position).normalized() * 250.0, "stun": 1.5})
		return true
	return false


func on_flame_gained(_gained: float, _overflow: float) -> void:
	pass


# --- event reactions ---------------------------------------------------------------

func _on_hit(_enemy: Node2D, _info: Dictionary) -> void:
	pass


func _on_killed(enemy: Node2D, _info: Dictionary) -> void:
	if player == null or not is_instance_valid(enemy) or not (enemy is Enemy):
		return
	run.kills += 1
	if has("ember_heart") and randf() < 0.25 * count("ember_heart") and enemy.room:
		enemy.room.drop_embers(enemy.global_position, maxi(1, enemy.embers))
	if has("wanderer_ember"):
		player.reduce_flare_cooldown(0.6 * count("wanderer_ember"))
	if has("ash_burst") and enemy.room:
		var pos: Vector2 = enemy.global_position
		var room: Room = enemy.room
		var t := player.get_tree().create_timer(0.08)
		t.timeout.connect(func(): _explode(room, pos, 12.0 * count("ash_burst"), 30.0))


func _explode(room: Room, pos: Vector2, dmg: float, radius: float) -> void:
	if not is_instance_valid(room):
		return
	Fx.impact(room.entities, pos - room.global_position, "warm")
	Fx.burst(room.entities, pos - room.global_position, "embers", 1.2)
	Audio.sfx("explode", -8.0, 0.15)
	for e in player.get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.is_hittable() and e.global_position.distance_to(pos) <= radius + e.hit_radius:
			e.take_hit({"damage": dmg, "kind": "explosion", "knockback": (e.global_position - pos).normalized() * 120.0, "source": player})


func _on_dashed(from: Vector2, to: Vector2) -> void:
	if has("flint"):
		var steps := 5
		for i in steps:
			var f := FireTrail.new()
			f.damage_per_sec = 10.0 * count("flint")
			f.position = from.lerp(to, float(i) / (steps - 1)) - player.get_parent().global_position
			player.get_parent().add_child(f)


func _on_flared(_pos: Vector2) -> void:
	pass


func _on_room_entered(_room: Node) -> void:
	shield_ready = has("sealed_wax")


func _on_room_cleared(_room: Node) -> void:
	if has("portable_fire"):
		player.add_flame(10.0 * count("portable_fire"))
		Fx.burst(player.get_parent(), player.global_position + Vector2(0, -8), "embers", 1.0)


## Orbiting companion flame from "Linterna Gemela".
class Wisp extends Node2D:
	var player: Player
	var level := 1
	var _t := 0.0
	var _cd := 1.0
	var spr: AnimatedSprite2D
	var light: LightEmitter

	func _ready() -> void:
		top_level = true
		spr = SpriteLib.make_sprite("bolt_blue", "fly")
		spr.z_as_relative = false
		spr.z_index = Layers.Z_EMISSIVE
		add_child(spr)
		light = LightEmitter.new()
		light.radius = 30.0
		light.energy = 0.8
		light.color = Color(0.7, 0.95, 1.0)
		add_child(light)

	func _physics_process(delta: float) -> void:
		if player == null or not is_instance_valid(player):
			queue_free()
			return
		_t += delta * 2.4
		global_position = player.global_position + Vector2(cos(_t) * 18.0, sin(_t) * 10.0 - 12.0)
		_cd -= delta
		if _cd <= 0.0 and not player.hub_mode:
			_cd = maxf(0.35, 0.9 - 0.15 * level)
			var best: Enemy = null
			var best_d := 150.0
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Enemy and e.is_targetable():
					var d := global_position.distance_to(e.global_position)
					if d < best_d:
						best_d = d
						best = e
			if best:
				var p := Projectile.new()
				p.team = "player"
				p.source = player
				p.kind = "bolt_blue"
				p.position = global_position
				p.velocity = (best.global_position + Vector2(0, -4) - global_position).normalized() * 220.0
				p.damage = 4.0 + 2.0 * level
				p.radius = 2.0
				p.max_dist = 180.0
				player.get_parent().add_child(p)


## Burning ground left by "Chispero" dashes.
class FireTrail extends Node2D:
	var damage_per_sec := 10.0
	var life := 1.4
	var _tick := 0.0
	var light: LightEmitter

	func _ready() -> void:
		z_as_relative = false
		z_index = Layers.Z_EMISSIVE - 2
		light = LightEmitter.new()
		light.radius = 16.0
		light.energy = 0.6
		add_child(light)

	func _physics_process(delta: float) -> void:
		life -= delta
		_tick -= delta
		if life <= 0.0:
			queue_free()
			return
		if _tick <= 0.0:
			_tick = 0.25
			for e in get_tree().get_nodes_in_group("enemies"):
				if e is Enemy and e.is_hittable() and e.global_position.distance_to(global_position) < 10.0 + e.hit_radius:
					e._apply_damage(damage_per_sec * 0.25, "burn", null)
		queue_redraw()

	func _draw() -> void:
		var a := clampf(life, 0.0, 1.0)
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.55, 0.2, a))
		draw_circle(Vector2(0, -1), 2.0, Color(1.0, 0.9, 0.6, a))
