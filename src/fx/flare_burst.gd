class_name FlareBurst
extends Node2D
## The "Fogonazo": an expanding ring of light that damages and stuns
## creatures, erases enemy shots, ignites braziers and cracks secret walls.

var radius := 96.0
var damage := 20.0
var source: Player
var t := 0.0
var _done := false
const DURATION := 0.35


func setup(player: Player, r: float, dmg: float) -> void:
	source = player
	radius = r
	damage = dmg


func _ready() -> void:
	z_as_relative = false
	z_index = Layers.Z_EMISSIVE
	Audio.sfx("flare", 0.0, 0.05)
	Fx.shake(4.0, 0.25)
	Fx.burst(get_parent(), position, "embers", 2.5)


func _process(delta: float) -> void:
	t += delta
	if not _done:
		_done = true
		_apply()
	if t >= DURATION:
		queue_free()
	queue_redraw()


func _apply() -> void:
	var center := global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.is_hittable() and e.global_position.distance_to(center) <= radius + e.hit_radius:
			var info := {"damage": damage, "kind": "flare", "knockback": (e.global_position - center).normalized() * 200.0, "source": source, "stun": 1.6}
			if source:
				source.relic_fx.modify_hit(e, info)
			e.take_hit(info)
			if source:
				source.hit_enemy.emit(e, info)
	for p in get_tree().get_nodes_in_group("enemy_shots"):
		if p.global_position.distance_to(center) <= radius:
			p.deflect(source)
	for b in get_tree().get_nodes_in_group("braziers"):
		if b.global_position.distance_to(center) <= radius * 0.8 and b.has_method("ignite"):
			b.ignite(false)
	for w in get_tree().get_nodes_in_group("secret_walls"):
		if (w.global_position + w.rect.get_center()).distance_to(center) <= radius + 8.0:
			w.reveal()
	for br in get_tree().get_nodes_in_group("breakables"):
		if br.global_position.distance_to(center) <= radius * 0.6:
			br.break_open(source)


func _draw() -> void:
	var k := t / DURATION
	var r := radius * (0.25 + 0.75 * sqrt(k))
	var c := Color("fff8e0")
	c.a = 1.0 - k
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, c, 2.0, false)
	var c2 := Color("ffc85a")
	c2.a = (1.0 - k) * 0.7
	draw_arc(Vector2.ZERO, r - 4.0, 0, TAU, 48, c2, 1.0, false)
