class_name Hub
extends Node2D
## Plaza de Velaluz: the meta-progression space. Sparks brought back from the
## depths relight its lamps (permanent unlocks); the well starts expeditions;
## the notice board holds the codex and records.

var player: Player
var run_stub: RunState
var layout: RoomLayout
var ui: CanvasLayer
var root: Control
var sparks_label: Label
var prompt: Label
var prompt_desc: Label
var toasts: VBoxContainer
var _panel: Control = null
var lamps: Array[LampPost] = []


func _ready() -> void:
	Audio.music("plaza")
	Audio.ambience("amb_wind")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	layout = RoomLayout.create("big", "plain", [], [], rng)
	var bg := Sprite2D.new()
	bg.centered = false
	bg.texture = RoomArt.compose(layout, "plaza", rng, 0.1)
	bg.z_index = Layers.Z_FLOOR
	add_child(bg)
	var walls := StaticBody2D.new()
	walls.collision_layer = Layers.WORLD
	add_child(walls)
	for y in layout.height:
		for x in layout.width:
			if layout.get_cell(x, y) == "W":
				var cs := CollisionShape2D.new()
				var r := RectangleShape2D.new()
				r.size = Vector2(16, 16)
				cs.shape = r
				cs.position = Vector2(x * 16 + 8, y * 16 + 8)
				walls.add_child(cs)
	var ents := Node2D.new()
	ents.y_sort_enabled = true
	add_child(ents)
	var dark := DarknessOverlay.new()
	dark.rect = Rect2(-64, -64, layout.width * 16 + 128, layout.height * 16 + 128)
	dark.dark_color = Color("14122a")
	add_child(dark)
	var lit_count := 0
	for l in Database.lamps:
		var lp := LampPost.new()
		lp.lamp = l
		lp.big = bool(l.get("big", false))
		lp.lit = SaveManager.has_lamp(str(l.id))
		var pos: Array = l.get("pos", [10, 10])
		lp.position = Vector2(pos[0] * 16 + 8, pos[1] * 16 + 14)
		ents.add_child(lp)
		lamps.append(lp)
		if lp.lit:
			lit_count += 1
	Lights.ambient = _plaza_ambient()
	# the Great Lighthouse is the final goal: once lit, all of Velaluz shines
	_decorate(ents, 99 if SaveManager.has_lamp("lighthouse") else lit_count)
	var well := Well.new()
	well.hub = self
	well.position = Vector2(19 * 16, 12 * 16)
	ents.add_child(well)
	var board := NoticeBoard.new()
	board.hub = self
	board.position = Vector2(4 * 16, 9 * 16)
	ents.add_child(board)
	run_stub = RunState.create("PLAZA", str(SaveManager.profile.selected_lantern), 0)
	player = Player.new()
	player.hub_mode = true
	player.setup(run_stub)
	player.position = Vector2(19 * 16, 16 * 16)
	ents.add_child(player)
	var cam := GameCamera.new()
	add_child(cam)
	cam.make_current()
	cam.focus(Vector2(layout.width * 8, layout.height * 8 - 4))
	_build_ui()
	Events.toast.connect(_toast)
	Events.sparks_changed.connect(func(n): sparks_label.text = str(n))
	if int(SaveManager.profile.stats.runs) <= 1 and SaveManager.profile.lamps.is_empty():
		_toast.call_deferred(tr("HUB_INTRO"), UITheme.FLAME)


func _exit_tree() -> void:
	get_tree().paused = false


## Facades, benches, planters and the statue. Each relit lamp lights two
## windows of the houses around the plaza.
func _decorate(ents: Node2D, lit_count: int) -> void:
	var window_x := [2, 5, 8, 11, 14, 24, 27, 30, 33, 36]
	# light windows in a fixed shuffled order so progress spreads around
	var order := [4, 5, 0, 9, 2, 7, 1, 8, 3, 6]
	for i in window_x.size():
		var lit := order.find(i) < lit_count * 2
		var w := Sprite2D.new()
		w.texture = SpriteLib.texture("window_lit" if lit else "window_dark")
		w.centered = false
		w.position = Vector2(window_x[i] * 16, 16)
		w.z_as_relative = false
		w.z_index = Layers.Z_EMISSIVE if lit else Layers.Z_DECAL
		add_child(w)
		if lit:
			var l := LightEmitter.new()
			l.position = w.position + Vector2(8, 14)
			l.radius = 34.0
			l.energy = 0.55
			l.is_static = true
			l.color = Color(1.0, 0.8, 0.5)
			add_child(l)
	var props := [
		["bench", Vector2(10, 7)], ["bench", Vector2(28, 7)], ["bench", Vector2(10, 17)], ["bench", Vector2(28, 17)],
		["planter", Vector2(16, 6)], ["planter", Vector2(22, 6)], ["planter", Vector2(16, 18)], ["planter", Vector2(22, 18)],
		["statue", Vector2(34, 10)],
	]
	for pr in props:
		var tex := SpriteLib.texture(pr[0])
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
		sp.position = pr[1] * 16.0 + Vector2(8, 14)
		ents.add_child(sp)
		var body := StaticBody2D.new()
		body.collision_layer = Layers.WORLD
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(tex.get_width() - 4, 6)
		cs.shape = r
		cs.position = Vector2(0, -3)
		body.add_child(cs)
		sp.add_child(body)
		if pr[0] == "statue":
			var sl := LightEmitter.new()
			sl.position = Vector2(6, -34)
			sl.radius = 40.0
			sl.energy = 0.6
			sl.is_static = true
			sp.add_child(sl)


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var title := UITheme.title_label(tr("HUB_TITLE"), 20, UITheme.BRASS_LIGHT)
	title.position = Vector2(8, 2)
	root.add_child(title)
	var hb := HBoxContainer.new()
	hb.position = Vector2(8, 24)
	root.add_child(hb)
	var spark_icon := TextureRect.new()
	var sat := AtlasTexture.new()
	sat.atlas = SpriteLib.texture("spark")
	sat.region = Rect2(0, 0, 7, 7)
	spark_icon.texture = sat
	spark_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	spark_icon.custom_minimum_size = Vector2(9, 14)
	hb.add_child(spark_icon)
	sparks_label = UITheme.label(str(SaveManager.profile.sparks), 12, UITheme.SPECTRAL)
	hb.add_child(sparks_label)
	prompt = UITheme.label("", 12)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_left = -220
	prompt.offset_right = 220
	prompt.offset_top = -48
	prompt.add_theme_color_override("font_outline_color", UITheme.INK)
	prompt.add_theme_constant_override("outline_size", 3)
	root.add_child(prompt)
	prompt_desc = UITheme.label("", 12, UITheme.TEXT_DIM)
	prompt_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_desc.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_desc.offset_left = -200
	prompt_desc.offset_right = 200
	prompt_desc.offset_top = -34
	prompt_desc.add_theme_color_override("font_outline_color", UITheme.INK)
	prompt_desc.add_theme_constant_override("outline_size", 3)
	root.add_child(prompt_desc)
	toasts = VBoxContainer.new()
	toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toasts.offset_left = -200
	toasts.offset_right = 200
	toasts.offset_top = 40
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toasts)


func _toast(text: String, color: Color) -> void:
	var l := UITheme.label(text, 12, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_outline_color", UITheme.INK)
	l.add_theme_constant_override("outline_size", 3)
	toasts.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(2.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)
	Lights.ambient = _plaza_ambient()


func _plaza_ambient() -> float:
	var a: float = 0.04 + 0.015 * (SaveManager.profile.lamps as Array).size()
	if SaveManager.has_lamp("lighthouse"):
		a += 0.3
	return a


func _process(_delta: float) -> void:
	var f := player.focus_interactable
	if _panel == null and f and is_instance_valid(f) and f.has_method("prompt_text"):
		prompt.text = "[%s] %s" % [Settings.binding_label("interact"), f.prompt_text()]
		prompt_desc.text = f.describe() if f.has_method("describe") else ""
	else:
		prompt.text = ""
		prompt_desc.text = ""


func open_panel(c: Control) -> void:
	if _panel:
		_panel.queue_free()
	_panel = c
	c.tree_exited.connect(func():
		if _panel == c:
			_panel = null
			get_tree().paused = false)
	ui.add_child(c)
	get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _panel == null:
		get_viewport().set_input_as_handled()
		open_panel(HubPauseMenu.new())


## The old well: entrance to the depths.
class Well extends Node2D:
	var hub: Hub
	var interact_range := 26.0

	func _ready() -> void:
		add_to_group("interactables")
		var s := Sprite2D.new()
		s.texture = SpriteLib.texture("well")
		s.centered = false
		s.offset = Vector2(-16, -26)
		add_child(s)
		var body := StaticBody2D.new()
		body.collision_layer = Layers.WORLD
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(28, 10)
		cs.shape = r
		cs.position = Vector2(0, -4)
		body.add_child(cs)
		add_child(body)
		var l := LightEmitter.new()
		l.position = Vector2(0, -10)
		l.radius = 48.0
		l.energy = 0.6
		l.color = Color(0.6, 0.9, 1.0)
		l.is_static = true
		add_child(l)

	func can_interact(_p) -> bool:
		return true

	func prompt_text() -> String:
		return tr("PROMPT_WELL")

	func interact(_p) -> void:
		hub.open_panel(ExpeditionPanel.new())


## Notice board: codex, bestiary and records.
class NoticeBoard extends Node2D:
	var hub: Hub
	var interact_range := 24.0

	func _ready() -> void:
		add_to_group("interactables")
		var s := Sprite2D.new()
		s.texture = SpriteLib.texture("notice_board")
		s.centered = false
		s.offset = Vector2(-12, -28)
		add_child(s)
		var body := StaticBody2D.new()
		body.collision_layer = Layers.WORLD
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(20, 6)
		cs.shape = r
		cs.position = Vector2(0, -3)
		body.add_child(cs)
		add_child(body)

	func can_interact(_p) -> bool:
		return true

	func prompt_text() -> String:
		return tr("PROMPT_BOARD")

	func interact(_p) -> void:
		hub.open_panel(CodexPanel.new())
