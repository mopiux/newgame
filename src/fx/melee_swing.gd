class_name MeleeSwing
extends Node2D
## Crescent drawn for a lantern swing; fades out in a few frames.

var dir := Vector2.RIGHT
var reach := 26.0
var half_arc := 0.9
var t := 0.0
const DURATION := 0.14


func setup(direction: Vector2, range_px: float, arc: float) -> void:
	dir = direction
	reach = range_px
	half_arc = arc


func _ready() -> void:
	z_as_relative = false
	z_index = Layers.Z_EMISSIVE


func _process(delta: float) -> void:
	t += delta
	if t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := t / DURATION
	var base := dir.angle()
	var sweep := lerpf(-half_arc, half_arc, minf(1.0, k * 1.6))
	var cols := [Color("fff8e0"), Color("ffc85a"), Color("d9622b")]
	for i in 3:
		var r := reach - i * 3.0
		var a0 := base - half_arc
		var a1 := base + sweep
		var c: Color = cols[i]
		c.a = 1.0 - k
		draw_arc(Vector2.ZERO, r, a0, a1, 10, c, 2.0 if i == 0 else 1.0, false)
