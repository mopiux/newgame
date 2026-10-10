class_name PauseMenu
extends Overlay
## Pause: resume, options, current relics, seed, and quitting (the run is
## saved and can be continued from the main menu).

var _list: VBoxContainer
var _options: OptionsMenu


func _ready() -> void:
	dim_background(0.75)
	Audio.ui("pause")
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 24
	hb.offset_right = -24
	hb.offset_top = 20
	hb.offset_bottom = -20
	hb.add_theme_constant_override("separation", 12)
	add_child(hb)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(170, 0)
	left.add_theme_constant_override("separation", 5)
	hb.add_child(left)
	left.add_child(UITheme.title_label(tr("PAUSE_TITLE"), 30))
	var resume := make_button(tr("PAUSE_RESUME"), func(): level.close_overlay())
	left.add_child(resume)
	left.add_child(make_button(tr("MENU_OPTIONS"), _open_options))
	left.add_child(make_button(tr("PAUSE_SAVE_QUIT"), func():
		Game.save_run_snapshot()
		Game.goto_menu()))
	left.add_child(make_button(tr("PAUSE_ABANDON"), _confirm_abandon))
	var run := level.run
	var info := UITheme.label("", 12, UITheme.TEXT_DIM)
	info.text = "%s\n%s %s\n%s %d   %s %d" % [
		tr(str(Database.biome_for_depth(run.depth).get("name", ""))),
		tr("SEED"), run.seed_text,
		tr("STAT_KILLS"), run.kills, tr("STAT_ROOMS"), run.rooms_cleared,
	]
	if run.ascension > 0:
		info.text += "\n" + tr("ASCENSION_N") % run.ascension
	left.add_child(info)

	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_list)
	_list.add_child(UITheme.title_label(tr("PAUSE_RELICS"), 20, UITheme.BRASS_LIGHT))
	if run.relics.is_empty():
		_list.add_child(UITheme.label(tr("PAUSE_NO_RELICS"), 12, UITheme.TEXT_DIM))
	var counted := {}
	for id in run.relics:
		counted[id] = int(counted.get(id, 0)) + 1
	for id in counted:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		icon.texture = RelicIcons.icon(id)
		icon.custom_minimum_size = Vector2(16, 16)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(icon)
		var r: Dictionary = Database.relics.get(id, {})
		var txt := VBoxContainer.new()
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		txt.add_theme_constant_override("separation", 0)
		var name_text := tr(str(r.get("name", id)))
		if counted[id] > 1:
			name_text += " x%d" % counted[id]
		txt.add_child(UITheme.label(name_text, 12, RelicIcons.rarity_color(id)))
		var d := UITheme.label(tr(str(r.get("desc", ""))), 12, UITheme.TEXT_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.add_child(d)
		row.add_child(txt)
		_list.add_child(row)
	resume.grab_focus.call_deferred()


func _open_options() -> void:
	_options = OptionsMenu.new()
	_options.closed.connect(func(): _options = null)
	add_child(_options)


func can_close() -> bool:
	return _options == null


func _confirm_abandon() -> void:
	var c := ConfirmBox.new()
	c.text = tr("PAUSE_ABANDON_CONFIRM")
	c.confirmed.connect(func(): Game.abandon_run())
	add_child(c)


## Yes/No dialog.
class ConfirmBox extends Control:
	signal confirmed()
	var text := ""

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		theme = UITheme.get_theme()
		var bg := ColorRect.new()
		bg.color = Color(UITheme.INK, 0.6)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(center)
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(260, 0)
		center.add_child(panel)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		panel.add_child(box)
		var l := UITheme.label(text)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)
		var hb := HBoxContainer.new()
		hb.alignment = BoxContainer.ALIGNMENT_CENTER
		hb.add_theme_constant_override("separation", 8)
		box.add_child(hb)
		var yes := Button.new()
		yes.text = tr("YES")
		yes.pressed.connect(func():
			Audio.ui("ui_select")
			confirmed.emit()
			queue_free())
		var no := Button.new()
		no.text = tr("NO")
		no.pressed.connect(func():
			Audio.ui("ui_back")
			queue_free())
		hb.add_child(no)
		hb.add_child(yes)
		no.grab_focus.call_deferred()

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			queue_free()
