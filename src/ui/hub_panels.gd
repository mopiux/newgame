class_name HubPanels
## Namespace file for the plaza's modal panels (see classes below).


static func base_panel(owner: Control, min_size: Vector2) -> VBoxContainer:
	owner.process_mode = Node.PROCESS_MODE_ALWAYS
	owner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.theme = UITheme.get_theme()
	var bg := ColorRect.new()
	bg.color = Color(UITheme.INK, 0.75)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	owner.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	return box
