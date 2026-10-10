class_name Pickup
extends Node2D
## Embers (refill the flame) and sparks (meta currency). They pop out,
## settle, then fly to the lamplighter when close or when the room is clear.

enum Kind { EMBER, SPARK }

var kind := Kind.EMBER
var value := 3.0
var vel := Vector2.ZERO
var magnet := false
var _age := 0.0
var _z := 0.0
var _vz := 0.0
var sprite: AnimatedSprite2D
var light: LightEmitter


static func ember(pos: Vector2, val: float) -> Pickup:
	var p := Pickup.new()
	p.kind = Kind.EMBER
	p.value = val
	p.position = pos
	return p


static func spark(pos: Vector2, val: int = 1) -> Pickup:
	var p := Pickup.new()
	p.kind = Kind.SPARK
	p.value = val
	p.position = pos
	return p


func _ready() -> void:
	add_to_group("pickups")
	sprite = SpriteLib.make_sprite("ember" if kind == Kind.EMBER else "spark", "idle")
	sprite.z_as_relative = false
	sprite.z_index = Layers.Z_EMISSIVE
	add_child(sprite)
	light = LightEmitter.new()
	light.radius = 12.0 if kind == Kind.EMBER else 18.0
	light.energy = 0.7
	light.priority = -10
	light.color = Color(1.0, 0.7, 0.4) if kind == Kind.EMBER else Color(0.6, 0.95, 1.0)
	add_child(light)
	var a := randf() * TAU
	vel = Vector2(cos(a), sin(a)) * randf_range(30.0, 70.0)
	_vz = randf_range(60.0, 100.0)


func _physics_process(delta: float) -> void:
	_age += delta
	var players := get_tree().get_nodes_in_group("player")
	var player: Player = players[0] if not players.is_empty() else null
	# toss arc
	if _age < 0.6:
		_vz -= 320.0 * delta
		_z = maxf(0.0, _z + _vz * delta)
		position += vel * delta
		vel = vel.move_toward(Vector2.ZERO, 120.0 * delta)
	sprite.position.y = -_z - 2.0 + sin(_age * 4.0) * 0.8
	if player == null or not player.is_alive():
		return
	var reach := player.stats.get_stat("magnet_radius") if player.stats else 40.0
	var d := global_position.distance_to(player.global_position + Vector2(0, -6))
	# outside combat everything drifts to the lamplighter (no loot left behind walls)
	if _age > 0.9 and not Game.in_combat():
		magnet = true
	if _age > 0.45 and (magnet or d < reach):
		magnet = true
		var dir := (player.global_position + Vector2(0, -6) - global_position).normalized()
		vel = vel.move_toward(dir * 260.0, 900.0 * delta)
		position += vel * delta
		if d < 8.0:
			_collect(player)


func _collect(player: Player) -> void:
	if kind == Kind.EMBER:
		player.add_flame(value * player.stats.get_stat("ember_mult"))
		Audio.sfx("ember", -10.0, 0.2)
	else:
		Game.add_sparks(int(value))
		Audio.sfx("spark", -4.0, 0.05)
		Fx.burst(get_parent(), global_position, "cold", 0.5)
	queue_free()
