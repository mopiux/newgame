class_name HUD
extends CanvasLayer
## In-run interface: flame gauge, cooldowns, sparks, minimap, relics,
## interaction prompt, toasts, boss bar, depth banner and crosshair.

var level: Level
var root: Control
var flame_gauge: FlameGauge
var minimap: Minimap
var sparks_label: Label
var relic_row: GridContainer
var prompt: Label
var prompt_desc: Label
var toasts: VBoxContainer
var boss_bar: BossBar
var banner: Label
var banner_sub: Label
var crosshair: Crosshair
var fps_label: Label
var vignette: ColorRect
var _relic_count := -1
var _hurt_flash := 0.0
var _vig_t := 0.0


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UITheme.get_theme()
	add_child(root)

	flame_gauge = FlameGauge.new()
	flame_gauge.position = Vector2(6, 5)
	root.add_child(flame_gauge)

	minimap = Minimap.new()
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.offset_left = -96
	minimap.offset_right = -4
	minimap.offset_top = 4
	minimap.offset_bottom = 60
	root.add_child(minimap)

	var sparks_box := HBoxContainer.new()
	sparks_box.anchor_left = 1.0
	sparks_box.anchor_right = 1.0
	sparks_box.offset_left = -96
	sparks_box.offset_right = -6
	sparks_box.offset_top = 62
	sparks_box.alignment = BoxContainer.ALIGNMENT_END
	sparks_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sparks_box)
	var spark_icon := TextureRect.new()
	var sat := AtlasTexture.new()
	sat.atlas = SpriteLib.texture("spark")
	sat.region = Rect2(0, 0, 7, 7)
	spark_icon.texture = sat
	spark_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	spark_icon.custom_minimum_size = Vector2(9, 12)
	sparks_box.add_child(spark_icon)
	sparks_label = UITheme.label("0", 12, UITheme.SPECTRAL)
	sparks_box.add_child(sparks_label)

	relic_row = GridContainer.new()
	relic_row.columns = 9
	relic_row.anchor_top = 1.0
	relic_row.anchor_bottom = 1.0
	relic_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	relic_row.offset_left = 6
	relic_row.offset_top = -40
	relic_row.offset_bottom = -4
	relic_row.add_theme_constant_override("h_separation", 2)
	relic_row.add_theme_constant_override("v_separation", 2)
	relic_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(relic_row)

	prompt = UITheme.label("", 12, UITheme.TEXT)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.anchor_left = 0.5
	prompt.anchor_right = 0.5
	prompt.anchor_top = 1.0
	prompt.anchor_bottom = 1.0
	prompt.offset_left = -200
	prompt.offset_right = 200
	prompt.offset_top = -64
	prompt.offset_bottom = -50
	prompt.add_theme_color_override("font_outline_color", UITheme.INK)
	prompt.add_theme_constant_override("outline_size", 3)
	root.add_child(prompt)
	prompt_desc = UITheme.label("", 12, UITheme.TEXT_DIM)
	prompt_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_desc.anchor_left = 0.5
	prompt_desc.anchor_right = 0.5
	prompt_desc.anchor_top = 1.0
	prompt_desc.anchor_bottom = 1.0
	prompt_desc.offset_left = -170
	prompt_desc.offset_right = 170
	prompt_desc.offset_top = -50
	prompt_desc.offset_bottom = -22
	prompt_desc.add_theme_color_override("font_outline_color", UITheme.INK)
	prompt_desc.add_theme_constant_override("outline_size", 3)
	root.add_child(prompt_desc)

	toasts = VBoxContainer.new()
	toasts.anchor_left = 0.5
	toasts.anchor_right = 0.5
	toasts.offset_left = -160
	toasts.offset_right = 160
	toasts.offset_top = 30
	toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)

	boss_bar = BossBar.new()
	boss_bar.anchor_left = 0.5
	boss_bar.anchor_right = 0.5
	boss_bar.anchor_top = 1.0
	boss_bar.anchor_bottom = 1.0
	boss_bar.offset_left = -130
	boss_bar.offset_right = 130
	boss_bar.offset_top = -30
	boss_bar.offset_bottom = -12
	boss_bar.visible = false
	root.add_child(boss_bar)

	banner = UITheme.title_label("", 40, UITheme.FLAME)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -300
	banner.offset_right = 300
	banner.offset_top = 96
	banner.modulate.a = 0.0
	root.add_child(banner)
	banner_sub = UITheme.label("", 12, UITheme.TEXT_DIM)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	banner_sub.offset_left = -300
	banner_sub.offset_right = 300
	banner_sub.offset_top = 136
	banner_sub.modulate.a = 0.0
	root.add_child(banner_sub)

	fps_label = UITheme.label("", 8, UITheme.TEXT_DIM)
	fps_label.add_theme_font_override("font", UITheme.font_small())
	fps_label.position = Vector2(6, 340)
	root.add_child(fps_label)

	vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = preload("res://assets/shaders/vignette.gdshader")
	vignette.material = vm
	root.add_child(vignette)
	root.move_child(vignette, 0)
	Events.player_damaged.connect(func(_a, _s): _hurt_flash = 1.0)

	crosshair = Crosshair.new()
	root.add_child(crosshair)
	set_crosshair(true)

	Events.toast.connect(show_toast)
	Events.relic_gained.connect(_on_relic_gained)
	Events.boss_started.connect(_on_boss_started)
	Events.boss_health_changed.connect(func(r): boss_bar.ratio = r)
	Events.boss_defeated.connect(func(_b): boss_bar.visible = false)
	Events.sparks_changed.connect(func(n): sparks_label.text = str(n))
	Events.map_changed.connect(func(): minimap.queue_redraw())
	Events.room_cleared.connect(func(_r): show_toast(tr("TOAST_ROOM_CLEAR"), UITheme.FLAME, 1.2))
	Events.room_entered.connect(func(_r): boss_bar.visible = false)


func set_crosshair(v: bool) -> void:
	crosshair.visible = v
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if v else Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	if level == null or level.player == null:
		return
	var p := level.player
	flame_gauge.player = p
	flame_gauge.queue_redraw()
	minimap.run = level.run
	sparks_label.text = str(level.run.sparks)
	if level.run.relics.size() != _relic_count:
		_rebuild_relics()
	var f := p.focus_interactable
	if f and is_instance_valid(f) and f.has_method("prompt_text"):
		prompt.text = "[%s] %s" % [Settings.binding_label("interact"), f.prompt_text()]
		prompt_desc.text = f.describe() if f.has_method("describe") else ""
	else:
		prompt.text = ""
		prompt_desc.text = ""
	fps_label.visible = Settings.get_value("video", "show_fps")
	if fps_label.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	crosshair.position = root.get_local_mouse_position()
	_update_vignette(p, _delta)


func _update_vignette(p: Player, delta: float) -> void:
	_vig_t += delta
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 2.5)
	var calm: bool = Settings.get_value("access", "reduce_flashes")
	var low := 0.0
	var ratio := p.flame_ratio()
	if ratio < 0.3 and p.is_alive():
		var pulse := 0.5 + 0.5 * sin(_vig_t * (5.0 if not calm else 2.0))
		low = (0.3 - ratio) / 0.3 * (0.55 + 0.25 * pulse)
	var hurt := _hurt_flash * (0.4 if calm else 0.8)
	var m := vignette.material as ShaderMaterial
	m.set_shader_parameter("intensity", clampf(maxf(low, hurt), 0.0, 1.0))


func _rebuild_relics() -> void:
	_relic_count = level.run.relics.size()
	for c in relic_row.get_children():
		c.queue_free()
	var shown := level.run.relics.slice(maxi(0, level.run.relics.size() - 18))
	for id in shown:
		var t := TextureRect.new()
		t.texture = RelicIcons.icon(id)
		t.custom_minimum_size = Vector2(16, 16)
		t.tooltip_text = tr(str(Database.relics.get(id, {}).get("name", id)))
		relic_row.add_child(t)


func _on_relic_gained(id: String) -> void:
	if id == "":
		_relic_count = -1
		return
	var r: Dictionary = Database.relics.get(id, {})
	show_toast(tr(str(r.get("name", id))), RelicIcons.rarity_color(id), 2.4, tr(str(r.get("desc", ""))))


func _on_boss_started(b: Node) -> void:
	boss_bar.visible = true
	boss_bar.ratio = 1.0
	boss_bar.boss_name = tr(str(b.get("display_name")))
	show_banner(tr(str(b.get("display_name"))), tr(str(b.data.get("title", ""))), UITheme.CURSE)


func show_toast(text: String, color: Color = UITheme.TEXT, duration: float = 1.8, sub: String = "") -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	var l := UITheme.label(text, 12, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", UITheme.INK)
	l.add_theme_constant_override("outline_size", 3)
	box.add_child(l)
	if sub != "":
		var s := UITheme.label(sub, 12, UITheme.TEXT_DIM)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.add_theme_color_override("font_outline_color", UITheme.INK)
		s.add_theme_constant_override("outline_size", 3)
		box.add_child(s)
	toasts.add_child(box)
	while toasts.get_child_count() > 3:
		toasts.get_child(0).free()
	var tw := box.create_tween()
	box.modulate.a = 0.0
	tw.tween_property(box, "modulate:a", 1.0, 0.15)
	tw.tween_interval(duration)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(box.queue_free)


func show_banner(title: String, sub: String, color: Color = UITheme.FLAME) -> void:
	banner.text = title
	banner.add_theme_color_override("font_color", color)
	banner_sub.text = sub
	for n in [banner, banner_sub]:
		var tw: Tween = n.create_tween()
		n.modulate.a = 0.0
		tw.tween_property(n, "modulate:a", 1.0, 0.5)
		tw.tween_interval(1.8)
		tw.tween_property(n, "modulate:a", 0.0, 0.8)


func show_depth_banner(depth: int) -> void:
	var b := Database.biome_for_depth(depth)
	show_banner(tr(str(b.get("name", ""))), tr("DEPTH_N") % depth)


class FlameGauge extends Control:
	var player: Player
	var _pulse := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(170, 34)
		size = custom_minimum_size

	func _process(delta: float) -> void:
		_pulse += delta

	func _draw() -> void:
		if player == null or player.run == null:
			return
		var mx := player.max_flame()
		var cur := player.run.flame
		var ratio := clampf(cur / mx, 0.0, 1.0)
		var w := clampf(mx * 1.1, 80.0, 160.0)
		var x0 := 14.0
		# frame
		draw_rect(Rect2(x0 - 1, 3, w + 2, 9), UITheme.INK)
		draw_rect(Rect2(x0, 4, w, 7), Color("231f3a"))
		var col := UITheme.FLAME if ratio > 0.25 else UITheme.FLAME_DEEP
		if ratio < 0.25 and int(_pulse * 4.0) % 2 == 0:
			col = Color("fff8e0")
		draw_rect(Rect2(x0, 4, w * ratio, 7), col)
		draw_rect(Rect2(x0, 4, w * ratio, 2), Color(1, 1, 1, 0.35))
		# tick every 25 flame
		var t := 25.0
		while t < mx:
			var tx := x0 + w * (t / mx)
			draw_rect(Rect2(tx, 4, 1, 7), Color(UITheme.INK, 0.5))
			t += 25.0
		# lantern icon
		var tex := SpriteLib.frames("lantern").get_frame_texture("burn" if ratio > 0.25 else "low", int(_pulse * 6.0) % 2)
		draw_texture(tex, Vector2(2, 2))
		var font := UITheme.font_small()
		draw_string_outline(font, Vector2(x0 + w + 5, 11), "%d/%d" % [ceili(cur), int(mx)], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, UITheme.INK)
		draw_string(font, Vector2(x0 + w + 5, 11), "%d/%d" % [ceili(cur), int(mx)], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UITheme.TEXT)
		# cooldowns: dash and flare
		_draw_cd(Vector2(x0, 15), player.cooldown_ratio("dash"), Settings.binding_label("dash"), UITheme.TEXT)
		_draw_cd(Vector2(x0 + 34, 15), player.cooldown_ratio("flare"), Settings.binding_label("flare"), UITheme.FLAME)

	func _draw_cd(pos: Vector2, r: float, key: String, col: Color) -> void:
		draw_rect(Rect2(pos, Vector2(30, 7)), UITheme.INK)
		draw_rect(Rect2(pos + Vector2(1, 1), Vector2(28 * clampf(r, 0.0, 1.0), 5)), col if r >= 1.0 else Color(col, 0.45))
		var font := UITheme.font_small()
		var label := key.left(5)
		draw_string_outline(font, pos + Vector2(1, 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, UITheme.INK)
		draw_string(font, pos + Vector2(1, 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UITheme.TEXT_DIM)


class Minimap extends Control:
	var run: RunState
	const CELL := Vector2(9, 6)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if run == null or run.floor.is_empty():
			return
		Minimap.draw_map(self, run, size, CELL, false)

	static func draw_map(ci: CanvasItem, r: RunState, area: Vector2, cell: Vector2, big: bool) -> void:
		var cur := DungeonGenerator.parse_key(r.current_room)
		var center := area * 0.5
		var revealed := Game.map_revealed_depth == r.depth
		ci.draw_rect(Rect2(Vector2.ZERO, area), Color(UITheme.INK, 0.55))
		for k in r.floor.rooms:
			var info: Dictionary = r.floor.rooms[k]
			var p := Vector2i(info.pos[0], info.pos[1])
			var st: Dictionary = r.rooms.get(k, {})
			var visited := bool(st.get("visited", false))
			var known := visited or revealed
			if not known and info.type != "secret":
				# rooms adjacent to visited ones are known as silhouettes
				for d in DungeonGenerator.DIRS:
					var np: Vector2i = p + DungeonGenerator.DIRS[d]
					var nk := DungeonGenerator.key(np)
					if r.rooms.get(nk, {}).get("visited", false) and (info.get("doors", []) as Array).has(DungeonGenerator.OPPOSITE[d]):
						known = true
			if info.type == "secret" and not visited:
				continue
			if not known:
				continue
			var off := Vector2(p - cur) * (cell + Vector2(2, 2))
			var rect := Rect2(center + off - cell * 0.5, cell)
			if not Rect2(Vector2.ZERO, area).encloses(rect):
				continue
			var col := Color("4a4766") if not visited else Color("9493a8")
			if k == r.current_room:
				col = UITheme.FLAME
			ci.draw_rect(rect, col)
			var icon_col := Color(0, 0, 0, 0)
			match str(info.type):
				"boss":
					icon_col = UITheme.CURSE
				"treasure":
					icon_col = Color("ffc85a")
				"shop":
					icon_col = Color("86a86a")
				"event":
					icon_col = Color("8a3b7d")
				"secret":
					icon_col = UITheme.SPECTRAL
				"elite":
					icon_col = Color("d9622b")
			if icon_col.a > 0.0:
				ci.draw_rect(Rect2(rect.get_center() - Vector2(1.5, 1.5), Vector2(3, 3)), icon_col)
			if st.get("cleared", false) and big:
				ci.draw_rect(Rect2(rect.position + Vector2(1, rect.size.y - 2), Vector2(rect.size.x - 2, 1)), Color(UITheme.INK, 0.6))


class BossBar extends Control:
	var ratio := 1.0
	var boss_name := ""
	var _shown := 1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_shown = move_toward(_shown, ratio, delta * 0.6)
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var font := UITheme.font_body()
		draw_string_outline(font, Vector2(0, 8), boss_name, HORIZONTAL_ALIGNMENT_CENTER, w, 12, 3, UITheme.INK)
		draw_string(font, Vector2(0, 8), boss_name, HORIZONTAL_ALIGNMENT_CENTER, w, 12, UITheme.CURSE)
		draw_rect(Rect2(0, 11, w, 7), UITheme.INK)
		draw_rect(Rect2(1, 12, (w - 2) * _shown, 5), Color("f2eee6"))
		draw_rect(Rect2(1, 12, (w - 2) * ratio, 5), UITheme.CURSE)


class Crosshair extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = 50

	func _draw() -> void:
		var c := UITheme.FLAME
		var k := UITheme.INK
		for v in [Vector2(-5, 0), Vector2(3, 0)]:
			draw_rect(Rect2(v + Vector2(-1, -1), Vector2(4, 3)), k)
			draw_rect(Rect2(v, Vector2(2, 1)), c)
		for v in [Vector2(0, -5), Vector2(0, 3)]:
			draw_rect(Rect2(v + Vector2(-1, -1), Vector2(3, 4)), k)
			draw_rect(Rect2(v, Vector2(1, 2)), c)
		draw_rect(Rect2(0, 0, 1, 1), Color("fff8e0"))
