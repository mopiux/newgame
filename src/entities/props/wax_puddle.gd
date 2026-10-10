class_name WaxPuddle
extends Node2D
## Sticky wax left by slugs: slows the lamplighter while standing in it.

var radius := 9.0
var life := 5.0
var _age := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = Layers.Z_DECAL


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= life:
		queue_free()
		return
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and p.global_position.distance_to(global_position) < radius:
			p.slow_timer = maxf(p.slow_timer, 0.15)
	if _age > life - 1.0:
		modulate.a = life - _age
	queue_redraw()


func _draw() -> void:
	# flat, pixel-stepped ellipse of wax with a glossy streak
	var r := roundf(radius * minf(1.0, _age * 4.0))
	var ry := maxf(2.0, roundf(r * 0.45))
	for y in range(-int(ry), int(ry) + 1):
		var w := roundf(r * sqrt(maxf(0.0, 1.0 - float(y * y) / (ry * ry))))
		if w <= 0.0:
			continue
		var col := Color("b58b65") if y > ry * 0.4 else Color("d9b98f")
		draw_rect(Rect2(-w, y, w * 2.0, 1.0), Color(col, 0.85))
	draw_rect(Rect2(-r * 0.4, -ry * 0.4, r * 0.5, 1.0), Color("efdcb8"))
