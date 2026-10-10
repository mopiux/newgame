class_name MainMenu
extends Node2D
## Title screen: a dark corner of Velaluz lit only by a lantern that follows
## the cursor, with the title and the main options.

var _light: LightEmitter
var _ui: CanvasLayer
var _buttons: VBoxContainer
var _options: OptionsMenu
var _room_layout: RoomLayout
var _t := 0.0


func _ready() -> void:
	Audio.music("menu")
	Audio.ambience("amb_wind")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	_room_layout = RoomLayout.create("big", "plain", [], [], rng)
	var bg := Sprite2D.new()
	bg.centered = false
	bg.texture = RoomArt.compose(_room_layout, "plaza", rng, 0.12)
	bg.z_index = Layers.Z_FLOOR
	bg.position = Vector2(16, 12)
	add_child(bg)
	var cam := Camera2D.new()
	cam.position = Vector2(320, 180)
	add_child(cam)
	cam.make_current()
	var dark := DarknessOverlay.new()
	dark.rect = Rect2(-64, -64, 800, 500)
	dark.dark_color = Color("100e20")
	add_child(dark)
	Lights.ambient = 0.0
	_light = LightEmitter.new()
	_light.radius = 120.0
	_light.flicker = 0.05
	add_child(_light)
	# a lamplighter standing at a lamp post, warming the scene
	var lp := LampPost.new()
	lp.position = Vector2(470, 250)
	lp.lit = true
	lp.decorative = true
	add_child(lp)
	var hero := SpriteLib.make_sprite("player", "idle_side")
	hero.position = Vector2(446, 262)
	add_child(hero)
	var lan := SpriteLib.make_sprite("lantern", "burn")
	lan.position = Vector2(454, 252)
	lan.z_as_relative = false
	lan.z_index = Layers.Z_EMISSIVE
	add_child(lan)
	var embers := CPUParticles2D.new()
	embers.amount = 24
	embers.lifetime = 6.0
	embers.position = Vector2(320, 380)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(320, 4)
	embers.direction = Vector2(0, -1)
	embers.spread = 20.0
	embers.gravity = Vector2(4, -6)
	embers.initial_velocity_min = 10.0
	embers.initial_velocity_max = 25.0
	embers.color = Color("ffc85a")
	embers.z_as_relative = false
	embers.z_index = Layers.Z_EMISSIVE
	add_child(embers)
	_build_ui()


func _exit_tree() -> void:
	Lights.ambient = 0.0


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)
	var title := UITheme.title_label("LUMBRE", 80, UITheme.FLAME)
	title.position = Vector2(36, 40)
	title.add_theme_constant_override("outline_size", 4)
	root.add_child(title)
	var sub := UITheme.label(tr("GAME_SUBTITLE"), 12, UITheme.TEXT_DIM)
	sub.position = Vector2(40, 116)
	root.add_child(sub)
	_buttons = VBoxContainer.new()
	_buttons.position = Vector2(40, 150)
	_buttons.custom_minimum_size = Vector2(180, 0)
	_buttons.add_theme_constant_override("separation", 5)
	root.add_child(_buttons)
	var first: Button = null
	if SaveManager.has_run():
		first = _add_button(tr("MENU_CONTINUE"), func():
			if not Game.continue_run():
				Events.toast.emit(tr("TOAST_SAVE_CORRUPT"), UITheme.CURSE)
				Game.goto_menu())
	var play := _add_button(tr("MENU_PLAY"), _on_play)
	if first == null:
		first = play
	_add_button(tr("MENU_OPTIONS"), _open_options)
	_add_button(tr("MENU_CREDITS"), func(): Game.goto_credits())
	_add_button(tr("MENU_QUIT"), func(): Game.quit_game())
	first.grab_focus.call_deferred()
	var ver := UITheme.label("v%s" % ProjectSettings.get_setting("application/config/version"), 8, UITheme.TEXT_DIM)
	ver.add_theme_font_override("font", UITheme.font_small())
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-40, -14)
	root.add_child(ver)
	if SaveManager.last_load_warning != "":
		var warn := UITheme.label(tr("TOAST_SAVE_RECOVERED"), 12, UITheme.CURSE)
		warn.position = Vector2(40, 330)
		root.add_child(warn)


func _add_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func():
		Audio.ui("ui_select")
		cb.call())
	b.focus_entered.connect(func(): Audio.ui("ui_move"))
	b.mouse_entered.connect(func(): b.grab_focus())
	_buttons.add_child(b)
	return b


func _on_play() -> void:
	# the very first expedition skips the plaza: straight into the dark
	if int(SaveManager.profile.stats.runs) == 0:
		Game.new_run("oil")
	else:
		Game.goto_hub()


func _open_options() -> void:
	if _options:
		return
	_options = OptionsMenu.new()
	_options.closed.connect(func():
		_options = null
		_buttons.get_child(0).grab_focus())
	_ui.add_child(_options)


func _process(delta: float) -> void:
	_t += delta
	var target := get_global_mouse_position()
	if Input.get_last_mouse_velocity().length() < 1.0 and _t > 0.5:
		target = Vector2(470, 220) + Vector2(cos(_t * 0.5) * 60.0, sin(_t * 0.7) * 30.0)
	_light.position = _light.position.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
