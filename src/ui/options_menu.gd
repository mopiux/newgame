class_name OptionsMenu
extends Control
## Options: audio, video, accessibility, language and key rebinding.
## Every change is applied immediately and saved on close.

signal closed()

var _tabs: TabContainer
var _waiting_action := ""
var _bind_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(UITheme.INK, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = 16
	panel.offset_bottom = -16
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	panel.add_child(root)
	root.add_child(UITheme.title_label(tr("MENU_OPTIONS"), 26))
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.NIGHT, 0.6), UITheme.BRASS_DARK, 1, 6))
	_tabs.add_theme_stylebox_override("tab_selected", UITheme.box(UITheme.PANEL_LIGHT, UITheme.BRASS, 1, 3))
	_tabs.add_theme_stylebox_override("tab_unselected", UITheme.box(UITheme.NIGHT, UITheme.BRASS_DARK, 1, 3))
	_tabs.add_theme_stylebox_override("tab_hovered", UITheme.box(UITheme.PANEL, UITheme.BRASS, 1, 3))
	_tabs.add_theme_color_override("font_selected_color", UITheme.FLAME)
	_tabs.add_theme_color_override("font_unselected_color", UITheme.TEXT_DIM)
	_tabs.add_theme_font_size_override("font_size", 12)
	root.add_child(_tabs)
	_build_audio()
	_build_video()
	_build_access()
	_build_controls()
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)
	var back := Button.new()
	back.text = tr("BACK")
	back.pressed.connect(_close)
	bottom.add_child(back)
	back.grab_focus.call_deferred()


func _page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	return box


func _slider(box: VBoxContainer, label: String, section: String, key: String) -> void:
	var row := HBoxContainer.new()
	var l := UITheme.label(label)
	l.custom_minimum_size = Vector2(180, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Settings.get_value(section, key))
	s.custom_minimum_size = Vector2(180, 14)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct := UITheme.label("%d%%" % int(s.value * 100), 12, UITheme.TEXT_DIM)
	s.value_changed.connect(func(v):
		Settings.set_value(section, key, v)
		pct.text = "%d%%" % int(v * 100)
		if section == "audio":
			Audio.ui("ui_move"))
	row.add_child(s)
	row.add_child(pct)
	box.add_child(row)


func _check(box: VBoxContainer, label: String, section: String, key: String, hint: String = "") -> void:
	var c := CheckBox.new()
	c.text = label
	c.button_pressed = bool(Settings.get_value(section, key))
	c.toggled.connect(func(v):
		Audio.ui("ui_select")
		Settings.set_value(section, key, v))
	if hint != "":
		c.tooltip_text = hint
	box.add_child(c)


func _build_audio() -> void:
	var b := _page(tr("OPT_AUDIO"))
	_slider(b, tr("OPT_MASTER"), "audio", "master")
	_slider(b, tr("OPT_MUSIC"), "audio", "music")
	_slider(b, tr("OPT_SFX"), "audio", "sfx")


func _build_video() -> void:
	var b := _page(tr("OPT_VIDEO"))
	_check(b, tr("OPT_FULLSCREEN"), "video", "fullscreen")
	_check(b, tr("OPT_VSYNC"), "video", "vsync")
	_check(b, tr("OPT_INTEGER"), "video", "integer_scale", tr("OPT_INTEGER_HINT"))
	_check(b, tr("OPT_PERF"), "video", "performance_mode", tr("OPT_PERF_HINT"))
	_check(b, tr("OPT_FPS"), "video", "show_fps")
	var row := HBoxContainer.new()
	var l := UITheme.label(tr("OPT_LANGUAGE"))
	l.custom_minimum_size = Vector2(180, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	opt.add_item("Español", 0)
	opt.add_item("English", 1)
	opt.selected = 0 if Settings.get_value("game", "language") == "es" else 1
	opt.item_selected.connect(func(i):
		Settings.set_value("game", "language", "es" if i == 0 else "en")
		Settings.save_settings())
	row.add_child(opt)
	b.add_child(row)
	var note := UITheme.label(tr("OPT_LANGUAGE_NOTE"), 12, UITheme.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(note)


func _build_access() -> void:
	var b := _page(tr("OPT_ACCESS"))
	_slider(b, tr("OPT_SHAKE"), "access", "shake")
	_check(b, tr("OPT_FLASHES"), "access", "reduce_flashes", tr("OPT_FLASHES_HINT"))
	_check(b, tr("OPT_NUMBERS"), "access", "damage_numbers")
	_check(b, tr("OPT_AIM_ASSIST"), "access", "aim_assist", tr("OPT_AIM_ASSIST_HINT"))
	_check(b, tr("OPT_OUTLINES"), "access", "enemy_outlines", tr("OPT_OUTLINES_HINT"))


func _build_controls() -> void:
	var b := _page(tr("OPT_CONTROLS"))
	for action in Settings.REBINDABLE:
		var row := HBoxContainer.new()
		var l := UITheme.label(tr("ACTION_" + action.to_upper()))
		l.custom_minimum_size = Vector2(180, 0)
		row.add_child(l)
		var btn := Button.new()
		btn.text = Settings.binding_label(action)
		btn.custom_minimum_size = Vector2(120, 0)
		btn.pressed.connect(func(): _start_rebind(action))
		row.add_child(btn)
		_bind_buttons[action] = btn
		b.add_child(row)
	var reset := Button.new()
	reset.text = tr("OPT_RESET_KEYS")
	reset.pressed.connect(func():
		Settings.reset_bindings()
		_refresh_bindings())
	b.add_child(reset)
	var pad := UITheme.label(tr("OPT_PAD_NOTE"), 12, UITheme.TEXT_DIM)
	pad.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_child(pad)
	# wiping progress is only offered outside an expedition
	if Game.level == null:
		b.add_child(HSeparator.new())
		var wipe := Button.new()
		wipe.text = tr("OPT_RESET_PROGRESS")
		wipe.add_theme_color_override("font_color", UITheme.CURSE)
		wipe.pressed.connect(func():
			var c := PauseMenu.ConfirmBox.new()
			c.text = tr("OPT_RESET_PROGRESS_CONFIRM")
			c.confirmed.connect(func():
				SaveManager.reset_profile()
				Game.goto_menu())
			add_child(c))
		b.add_child(wipe)


func _start_rebind(action: String) -> void:
	_waiting_action = action
	_bind_buttons[action].text = tr("OPT_PRESS_KEY")


func _refresh_bindings() -> void:
	for a in _bind_buttons:
		_bind_buttons[a].text = Settings.binding_label(a)


func _input(event: InputEvent) -> void:
	if _waiting_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_waiting_action = ""
			_refresh_bindings()
		else:
			Settings.rebind(_waiting_action, event)
			_waiting_action = ""
			_refresh_bindings()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
		var btn: Button = _bind_buttons[_waiting_action]
		if event.button_index == MOUSE_BUTTON_LEFT and not btn.get_global_rect().has_point(btn.get_global_mouse_position()):
			# a left click elsewhere (Back, a tab...) cancels instead of binding
			_waiting_action = ""
			_refresh_bindings()
			return
		Settings.rebind(_waiting_action, event)
		_waiting_action = ""
		_refresh_bindings.call_deferred()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_action == "" and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	Settings.save_settings()
	Audio.ui("ui_back")
	closed.emit()
	queue_free()
