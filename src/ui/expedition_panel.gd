class_name ExpeditionPanel
extends Control
## Preparing an expedition at the well: lantern, ascension ("Noches") and
## optional seed.

var _lantern := "oil"
var _asc := 0
var _lantern_box: VBoxContainer
var _desc: Label
var _asc_label: Label
var _seed: LineEdit
var _start: Button


func _ready() -> void:
	var box := HubPanels.base_panel(self, Vector2(420, 0))
	_lantern = str(SaveManager.profile.selected_lantern)
	if not SaveManager.lantern_unlocked(_lantern):
		_lantern = "oil"
	_asc = int(SaveManager.profile.ascension_selected)
	box.add_child(UITheme.title_label(tr("EXP_TITLE"), 26))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	box.add_child(hb)
	_lantern_box = VBoxContainer.new()
	_lantern_box.custom_minimum_size = Vector2(150, 0)
	hb.add_child(_lantern_box)
	_desc = UITheme.label("", 12, UITheme.TEXT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(240, 110)
	_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(_desc)
	var ids: Array = Database.lanterns.keys()
	ids.sort_custom(func(a, b): return int(Database.lanterns[a].get("order", 0)) < int(Database.lanterns[b].get("order", 0)))
	var group := ButtonGroup.new()
	for id in ids:
		var l: Dictionary = Database.lanterns[id]
		var b := Button.new()
		var unlocked := SaveManager.lantern_unlocked(id)
		b.text = tr(str(l.get("name", id))) if unlocked else "? ? ?"
		b.disabled = not unlocked
		if not unlocked:
			# disabled buttons can still take keyboard/pad focus in Godot
			b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# the pressed (brass) look marks the chosen lantern; focus only previews
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = id == _lantern
		b.pressed.connect(func():
			if not SaveManager.lantern_unlocked(id):
				return
			Audio.ui("ui_select")
			_lantern = id
			_refresh())
		b.focus_entered.connect(func():
			Audio.ui("ui_move")
			_refresh(id))
		b.focus_exited.connect(func(): _refresh())
		_lantern_box.add_child(b)
	if int(SaveManager.profile.ascension_unlocked) > 0:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		box.add_child(row)
		row.add_child(UITheme.label(tr("EXP_ASCENSION"), 12))
		var minus := Button.new()
		minus.text = "-"
		minus.pressed.connect(func():
			_asc = maxi(0, _asc - 1)
			_refresh())
		row.add_child(minus)
		_asc_label = UITheme.label("", 12, UITheme.FLAME)
		_asc_label.custom_minimum_size = Vector2(24, 0)
		_asc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(_asc_label)
		var plus := Button.new()
		plus.text = "+"
		plus.pressed.connect(func():
			_asc = mini(int(SaveManager.profile.ascension_unlocked), _asc + 1)
			_refresh())
		row.add_child(plus)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	box.add_child(srow)
	srow.add_child(UITheme.label(tr("EXP_SEED"), 12))
	_seed = LineEdit.new()
	_seed.placeholder_text = tr("EXP_SEED_HINT")
	_seed.max_length = 12
	_seed.custom_minimum_size = Vector2(150, 0)
	srow.add_child(_seed)
	var brow := HBoxContainer.new()
	brow.alignment = BoxContainer.ALIGNMENT_END
	brow.add_theme_constant_override("separation", 8)
	box.add_child(brow)
	var cancel := Button.new()
	cancel.text = tr("BACK")
	cancel.pressed.connect(func():
		Audio.ui("ui_back")
		queue_free())
	brow.add_child(cancel)
	_start = Button.new()
	_start.text = tr("EXP_START")
	_start.pressed.connect(_go)
	brow.add_child(_start)
	_refresh()
	_start.grab_focus.call_deferred()


func _refresh(preview: String = "") -> void:
	var shown := preview if preview != "" else _lantern
	var l: Dictionary = Database.lanterns.get(shown, {})
	var text := tr(str(l.get("name", shown))) + "\n" + tr(str(l.get("desc", "")))
	if _asc > 0:
		text += "\n\n" + tr("ASCENSION_N") % _asc + ":"
		for i in _asc:
			var lvl: Dictionary = Database.balance_value("ascension.%d" % (i + 1), {})
			text += "\n- " + tr(str(lvl.get("desc", "")))
	_desc.text = text
	if _asc_label:
		_asc_label.text = str(_asc)


func _go() -> void:
	if not SaveManager.lantern_unlocked(_lantern):
		_lantern = "oil"
	Audio.ui("ui_select")
	SaveManager.profile.ascension_selected = _asc
	get_tree().paused = false
	Game.new_run(_lantern, _seed.text, _asc)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		queue_free()
