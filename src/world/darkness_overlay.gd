class_name DarknessOverlay
extends Node2D
## Full-room darkness rectangle that feeds LightEmitter data to the shader.

const SHADER := preload("res://assets/shaders/darkness.gdshader")
const MAX_LIGHTS := 64

var rect := Rect2(0, 0, 640, 360)
var dark_color := Color(0.07, 0.065, 0.14)
var _mat: ShaderMaterial
var _poly: Polygon2D
var _positions := PackedVector4Array()
var _colors := PackedVector4Array()


func _ready() -> void:
	z_as_relative = false
	z_index = Layers.Z_DARKNESS
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_poly = Polygon2D.new()
	_poly.material = _mat
	add_child(_poly)
	_positions.resize(MAX_LIGHTS)
	_colors.resize(MAX_LIGHTS)
	set_rect(rect)


func set_rect(r: Rect2) -> void:
	rect = r
	if _poly:
		_poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	var view := rect
	if cam:
		var size := get_viewport_rect().size / cam.zoom
		view = Rect2(cam.get_screen_center_position() - size * 0.5, size).grow(8.0)
	var limit := mini(MAX_LIGHTS, 24 if Settings.get_value("video", "performance_mode") else Lights.max_lights)
	var list := Lights.collect(view, limit)
	var n := list.size()
	for i in n:
		var e: LightEmitter = list[i]
		var p := e.global_position
		_positions[i] = Vector4(p.x, p.y, e.current_radius, e.current_energy)
		_colors[i] = Vector4(e.color.r, e.color.g, e.color.b, 1.0)
	_mat.set_shader_parameter("light_count", n)
	_mat.set_shader_parameter("lights", _positions)
	_mat.set_shader_parameter("light_colors", _colors)
	_mat.set_shader_parameter("ambient", Lights.ambient)
	_mat.set_shader_parameter("dark_color", dark_color)
	_mat.set_shader_parameter("dither_strength", 0.0 if Settings.get_value("access", "reduce_flashes") else 1.0)
