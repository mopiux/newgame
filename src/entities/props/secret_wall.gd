class_name SecretWall
extends StaticBody2D
## Cracked wall hiding a secret room. Hairline cracks glint in the light;
## a flare or a few bolts bring it down.

signal revealed(dir: String)

var dir := "n"
var rect := Rect2()
var hp := 4
var is_open := false


func setup(direction: String, r: Rect2) -> void:
	dir = direction
	rect = r


func _ready() -> void:
	add_to_group("secret_walls")
	collision_layer = Layers.WORLD
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = rect.size
	shape.shape = rs
	shape.position = rect.get_center()
	add_child(shape)
	z_index = 1


func on_projectile_hit(p: Projectile) -> void:
	if p.team != "player" or is_open:
		return
	hp -= 1
	Fx.burst(get_parent(), p.global_position, "stone", 0.5)
	queue_redraw()
	if hp <= 0:
		reveal()


func reveal() -> void:
	if is_open:
		return
	is_open = true
	collision_layer = 0
	Fx.burst(get_parent(), rect.get_center(), "stone", 3.0)
	Fx.shake(4.0, 0.3)
	Audio.sfx("secret", 0.0, 0.0)
	revealed.emit(dir)
	queue_redraw()


func _draw() -> void:
	if is_open:
		return
	# cracks: visible only where light falls (the darkness layer handles that)
	var c := Color("0b0a12")
	var hl := Color("9fe0e6") if hp < 4 else Color("6b6a86")
	var cx := rect.get_center()
	var pts := [Vector2(-5, -6), Vector2(-2, -2), Vector2(1, -3), Vector2(3, 2), Vector2(6, 5)]
	for i in pts.size() - 1:
		draw_line(cx + pts[i], cx + pts[i + 1], c, 1.0)
	draw_line(cx + Vector2(-2, -2), cx + Vector2(-6, 3), c, 1.0)
	draw_rect(Rect2(cx + Vector2(1, -4), Vector2(1, 1)), hl)
	draw_rect(Rect2(cx + Vector2(-5, 2), Vector2(1, 1)), hl)
	for i in 4 - hp:
		draw_line(cx + Vector2(-8 + i * 4, 6), cx + Vector2(-4 + i * 4, -7), c, 1.0)
