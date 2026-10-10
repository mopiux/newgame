class_name Projectile
extends Node2D
## Bolts of light (player) and orbs of penumbra (enemies). Moved manually:
## walls are found with ray casts (to get normals for bounces), creatures
## with a distance check against their hit radius.

var team := "player"          # "player" | "enemy"
var velocity := Vector2.ZERO
var damage := 10.0
var max_dist := 220.0
var travelled := 0.0
var pierce := 0
var bounce := 0
var radius := 3.0
var knockback := 70.0
var homing := 0.0
var drain_light := false       # enemy orbs that shrink the lantern
var source: Node = null
var hit_list: Array = []
var sprite: AnimatedSprite2D
var light: LightEmitter
var kind := "bolt"
var is_big := false
var on_expire: Callable = Callable()
var accel := 0.0
var lifetime := 6.0


static func player_shot(player: Player, origin: Vector2, dir: Vector2, big: bool = false) -> Projectile:
	var p := Projectile.new()
	var st := player.stats
	p.team = "player"
	p.source = player
	p.position = origin
	p.velocity = dir * st.get_stat("shot_speed")
	p.damage = st.get_stat("shot_damage")
	p.max_dist = st.get_stat("shot_range")
	p.pierce = st.get_int("pierce")
	p.bounce = st.get_int("bounce")
	p.radius = 3.0 * st.get_stat("shot_size")
	p.homing = st.get_stat("homing")
	p.kind = player.relic_fx.bolt_sheet()
	if big:
		p.is_big = true
		p.damage *= 3.0
		p.radius *= 2.0
		p.pierce += 2
	return p


static func enemy_shot(src: Node, origin: Vector2, dir: Vector2, speed: float, dmg: float, sheet: String = "orb") -> Projectile:
	var p := Projectile.new()
	p.team = "enemy"
	p.source = src
	p.position = origin
	p.velocity = dir.normalized() * speed * Game.enemy_shot_speed_mult()
	p.damage = dmg
	p.max_dist = 600.0
	p.radius = 3.0
	p.kind = sheet
	return p


func _ready() -> void:
	sprite = SpriteLib.make_sprite(kind, "fly")
	sprite.z_as_relative = false
	sprite.z_index = Layers.Z_EMISSIVE
	var s := clampf(radius / 3.0, 0.6, 3.0)
	sprite.scale = Vector2(s, s)
	add_child(sprite)
	light = LightEmitter.new()
	if team == "player":
		light.radius = 26.0 * clampf(s, 1.0, 2.0)
		light.energy = 0.9
		light.priority = 50
		light.color = Color(1.0, 0.85, 0.6) if kind == "bolt" else Color(0.7, 0.95, 1.0)
		add_to_group("player_shots")
	else:
		light.radius = 18.0
		light.energy = -0.6 if kind == "orb" else 0.7
		light.color = Color(0.9, 0.5, 0.8)
		light.priority = 40
		add_to_group("enemy_shots")
	light.flicker = 0.1
	add_child(light)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		_expire(false)
		return
	if accel != 0.0:
		velocity = velocity.normalized() * maxf(20.0, velocity.length() + accel * delta)
	if homing > 0.0:
		_home(delta)
	var step := velocity * delta
	var from := global_position
	var to := from + step
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to, Layers.WORLD | Layers.PROPS)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var col: Object = hit.collider
		if col and col.has_method("on_projectile_hit"):
			col.on_projectile_hit(self)
		if bounce > 0 and team == "player":
			bounce -= 1
			velocity = velocity.bounce(hit.normal)
			global_position = hit.position + hit.normal * 1.5
			Audio.sfx("bounce", -10.0)
		else:
			global_position = hit.position
			_expire(true)
			return
	else:
		global_position = to
	travelled += step.length()
	rotation = 0.0
	if team == "player":
		_hit_enemies()
	else:
		_hit_player()
	if travelled >= max_dist:
		_expire(false)


func _home(delta: float) -> void:
	var best: Node2D = null
	var best_d := 140.0
	if team == "enemy":
		# creature shots seek the lamplighter, never their own caster
		var pl := get_tree().get_first_node_in_group("player") as Player
		if pl and pl.is_alive() and not pl.hub_mode:
			best = pl
	else:
		best = _nearest_enemy(best_d)
	if best:
		# turn without losing speed (a plain lerp shortens the vector)
		var speed := velocity.length()
		var desired := (best.global_position + Vector2(0, -4) - global_position).normalized() * speed
		var turned := velocity.lerp(desired, clampf(homing * delta * 4.0, 0.0, 1.0))
		if turned.length() > 0.001:
			velocity = turned.normalized() * speed


func _nearest_enemy(best_d: float) -> Node2D:
	var best: Node2D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.is_targetable() and not hit_list.has(e):
			var d := global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best


func _hit_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or hit_list.has(e) or not e.is_hittable():
			continue
		if global_position.distance_to(e.global_position + Vector2(0, -e.body_height * 0.5)) <= radius + e.hit_radius:
			hit_list.append(e)
			var owner_player: Player = source as Player if is_instance_valid(source) else null
			var info := {"damage": damage, "kind": "bolt", "knockback": velocity.normalized() * knockback, "source": owner_player, "projectile": self}
			if owner_player:
				owner_player.relic_fx.modify_hit(e, info)
			e.take_hit(info)
			if owner_player:
				owner_player.hit_enemy.emit(e, info)
			Fx.impact(get_parent(), global_position, "warm" if kind == "bolt" else "cold")
			if pierce > 0:
				pierce -= 1
			else:
				_expire(false, false)
				return


func _hit_player() -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and p.is_alive() and global_position.distance_to(p.global_position + Vector2(0, -6)) <= radius + 4.0:
			if p.invuln > 0.0:
				return
			p.take_damage(damage, global_position, source if is_instance_valid(source) else null)
			if drain_light:
				p.shrink_timer = 3.0
			_expire(false)
			return


## Melee or flare destroys enemy shots.
func deflect(_by: Node) -> void:
	Fx.impact(get_parent(), global_position, "dark")
	Fx.burst(get_parent(), global_position, "wisps", 0.5)
	Audio.sfx("deflect", -6.0)
	queue_free()


func _expire(hit_wall: bool, impact_fx: bool = true) -> void:
	if is_queued_for_deletion():
		return
	if on_expire.is_valid():
		on_expire.call(self)
	if impact_fx:
		Fx.impact(get_parent(), global_position, "warm" if team == "player" else "dark")
		if hit_wall:
			Fx.burst(get_parent(), global_position, "sparks" if team == "player" else "wisps", 0.4)
	queue_free()
