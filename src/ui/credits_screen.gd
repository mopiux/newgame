class_name CreditsScreen
extends Control
## Credits and third-party asset attribution.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	var bg := ColorRect.new()
	bg.color = UITheme.INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 60
	scroll.offset_right = -60
	scroll.offset_top = 20
	scroll.offset_bottom = -40
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	box.add_child(UITheme.title_label("LUMBRE", 40))
	for key in ["CREDITS_1", "CREDITS_2", "CREDITS_3", "CREDITS_4", "CREDITS_5"]:
		var l := UITheme.label(tr(key), 12)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	var back := Button.new()
	back.text = tr("BACK")
	back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	back.offset_left = 60
	back.offset_top = -32
	back.offset_bottom = -12
	back.pressed.connect(func():
		Audio.ui("ui_back")
		Game.goto_menu())
	add_child(back)
	back.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		Game.goto_menu()
