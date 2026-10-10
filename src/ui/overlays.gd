class_name Overlay
extends Control
## Base for modal panels shown over the game (pause, map, events, results).
## Runs while the tree is paused and closes on the pause/cancel action.

var level: Level


func set_level(l: Level) -> void:
	level = l


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UITheme.get_theme()
	mouse_filter = Control.MOUSE_FILTER_STOP


func dim_background(alpha: float = 0.7) -> void:
	var bg := ColorRect.new()
	bg.color = Color(UITheme.INK, alpha)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func centered_panel(min_size: Vector2) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	return box


func make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Audio.ui("ui_select")
		cb.call())
	b.focus_entered.connect(func(): Audio.ui("ui_move"))
	b.mouse_entered.connect(func(): b.grab_focus())
	return b


func can_close() -> bool:
	return true


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and can_close():
		get_viewport().set_input_as_handled()
		if level:
			level.close_overlay()
		else:
			queue_free()
