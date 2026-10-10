class_name MapOverlay
extends Overlay
## Full-screen map of the current depth.


func _ready() -> void:
	dim_background(0.8)
	var title := UITheme.title_label(tr(str(Database.biome_for_depth(level.run.depth).get("name", ""))), 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 14
	add_child(title)
	var m := BigMap.new()
	m.run = level.run
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.offset_left = 60
	m.offset_right = -60
	m.offset_top = 56
	m.offset_bottom = -50
	add_child(m)
	var legend := UITheme.label(tr("MAP_LEGEND"), 12, UITheme.TEXT_DIM)
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	legend.offset_top = -40
	legend.offset_bottom = -24
	add_child(legend)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		get_viewport().set_input_as_handled()
		level.close_overlay()
		return
	super._unhandled_input(event)


class BigMap extends Control:
	var run: RunState

	func _draw() -> void:
		HUD.Minimap.draw_map(self, run, size, Vector2(22, 14), true)
