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
	var r := radius * minf(1.0, _age * 4.0)
	draw_circle(Vector2.ZERO, r, Color("d9b98f"))
	draw_circle(Vector2(-1, -1), r * 0.7, Color("efdcb8"))
	draw_circle(Vector2(r * 0.3, r * 0.2), r * 0.25, Color("b58b65"))
