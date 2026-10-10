class_name Fx
## Spawners for short-lived visual effects. All effects free themselves.

const SPRITE_FX := preload("res://assets/shaders/sprite_fx.gdshader")

const PRESETS := {
	"embers": {"amount": 14, "colors": [Color("ffc85a"), Color("f29a38"), Color("d9622b")], "speed": [30.0, 90.0], "life": 0.6, "gravity": Vector2(0, -40), "size": 1.0, "emissive": true},
	"dust": {"amount": 10, "colors": [Color("6b6a86"), Color("4a4766")], "speed": [15.0, 45.0], "life": 0.5, "gravity": Vector2(0, -10), "size": 1.0, "emissive": false},
	"wisps": {"amount": 14, "colors": [Color("8a3b7d"), Color("4e2459"), Color("2b1838")], "speed": [20.0, 60.0], "life": 0.7, "gravity": Vector2(0, -30), "size": 1.0, "emissive": true},
	"wax": {"amount": 12, "colors": [Color("efdcb8"), Color("d9b98f")], "speed": [30.0, 80.0], "life": 0.5, "gravity": Vector2(0, 120), "size": 1.0, "emissive": false},
	"sparks": {"amount": 10, "colors": [Color("fff8e0"), Color("ffe9a3"), Color("ffc85a")], "speed": [60.0, 140.0], "life": 0.3, "gravity": Vector2.ZERO, "size": 1.0, "emissive": true},
	"cold": {"amount": 14, "colors": [Color("9fe0e6"), Color("4f9bb0")], "speed": [30.0, 90.0], "life": 0.6, "gravity": Vector2(0, -30), "size": 1.0, "emissive": true},
	"stone": {"amount": 12, "colors": [Color("6b6a86"), Color("34304f"), Color("9493a8")], "speed": [40.0, 100.0], "life": 0.5, "gravity": Vector2(0, 160), "size": 2.0, "emissive": false},
	"moss": {"amount": 8, "colors": [Color("86a86a"), Color("4f7350")], "speed": [30.0, 70.0], "life": 0.5, "gravity": Vector2(0, 100), "size": 1.0, "emissive": false},
}


static var disabled := false  # benchmarking switch (autopilot --no-fx)


static func perf_scale() -> float:
	return 0.5 if Settings.get_value("video", "performance_mode") else 1.0


static func burst(parent: Node, pos: Vector2, preset: String, amount_mult: float = 1.0, direction: Vector2 = Vector2.ZERO) -> void:
	if parent == null or not is_instance_valid(parent) or disabled:
		return
	var p: Dictionary = PRESETS.get(preset, PRESETS.dust)
	var cp := CPUParticles2D.new()
	cp.one_shot = true
	cp.emitting = false
	cp.amount = maxi(2, int(p.amount * amount_mult * perf_scale()))
	cp.lifetime = p.life
	cp.explosiveness = 0.95
	cp.spread = 180.0 if direction == Vector2.ZERO else 55.0
	cp.direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	cp.initial_velocity_min = p.speed[0]
	cp.initial_velocity_max = p.speed[1]
	cp.gravity = p.gravity
	cp.damping_min = 40.0
	cp.damping_max = 80.0
	cp.scale_amount_min = p.size
	cp.scale_amount_max = p.size * 2.0
	var grad := Gradient.new()
	var cols: Array = p.colors
	grad.set_color(0, cols[0])
	grad.set_color(1, Color(cols[cols.size() - 1], 0.0))
	if cols.size() > 2:
		grad.add_point(0.5, cols[1])
	cp.color_ramp = grad
	cp.position = pos
	if p.emissive:
		cp.z_as_relative = false
		cp.z_index = Layers.Z_EMISSIVE
	else:
		cp.z_index = 5
	cp.emitting = true
	cp.finished.connect(cp.queue_free)
	_add(parent, cp)


static func impact(parent: Node, pos: Vector2, kind: String = "warm") -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var spr := SpriteLib.make_sprite("impact", kind)
	spr.position = pos
	spr.z_as_relative = false
	spr.z_index = Layers.Z_EMISSIVE
	spr.animation_finished.connect(spr.queue_free)
	_add(parent, spr)


## Effects are added deferred: spawners often run while the parent is
## still adding its own children (e.g. from a creature's _ready).
static func _add(parent: Node, child: Node) -> void:
	parent.add_child.call_deferred(child)


static func make_flash_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SPRITE_FX
	return m


static func flash(node: CanvasItem, duration: float = 0.12, color: Color = Color(1, 0.97, 0.9)) -> void:
	if node == null or not (node.material is ShaderMaterial):
		return
	var m := node.material as ShaderMaterial
	m.set_shader_parameter("flash_color", color)
	m.set_shader_parameter("flash", 1.0)
	var tw := node.create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter("flash", v), 1.0, 0.0, duration)


static func damage_number(parent: Node, pos: Vector2, amount: float, kind: String = "normal") -> void:
	if not Settings.get_value("access", "damage_numbers") or parent == null:
		return
	var lbl := Label.new()
	lbl.text = str(int(round(amount)))
	lbl.add_theme_font_override("font", UITheme.font_small())
	lbl.add_theme_font_size_override("font_size", 8)
	var col := Color("fff8e0")
	match kind:
		"crit":
			col = Color("ffc85a")
			lbl.text += "!"
		"burn":
			col = Color("d9622b")
		"player":
			col = Color("d46aa6")
		"light":
			col = Color("9fe0e6")
		"immune":
			col = Color("6b6a86")
			lbl.text = "·" + lbl.text + "·"
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color("0b0a12"))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.position = pos + Vector2(randf_range(-4, 4) - 6, -14)
	lbl.z_as_relative = false
	lbl.z_index = Layers.Z_FX_TOP
	parent.add_child(lbl)
	var tw := lbl.create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 12, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3).set_delay(0.35)
	tw.chain().tween_callback(lbl.queue_free)


static func afterimage(parent: Node, source: AnimatedSprite2D, color: Color = Color(1, 0.6, 0.25, 0.5)) -> void:
	if parent == null or source == null or source.sprite_frames == null:
		return
	var tex := source.sprite_frames.get_frame_texture(source.animation, source.frame)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = source.offset
	s.flip_h = source.flip_h
	s.global_position = source.global_position
	s.modulate = color
	s.z_index = -1
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.25)
	tw.tween_callback(s.queue_free)


static func shake(strength: float, duration: float = 0.2) -> void:
	Events.screen_shake.emit(strength, duration)


static func hit_stop(duration: float) -> void:
	Events.hit_stop.emit(duration)
