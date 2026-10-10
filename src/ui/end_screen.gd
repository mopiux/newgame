class_name EndScreen
extends Overlay
## Results of an expedition (extinguished or victorious).

var summary: Dictionary = {}


func _ready() -> void:
	dim_background(0.0)
	var bg := get_child(0) as ColorRect
	var tw := create_tween()
	tw.tween_property(bg, "color:a", 0.85, 0.8)
	var victory: bool = summary.get("victory", false)
	var box := centered_panel(Vector2(320, 0))
	var title := UITheme.title_label(tr("END_VICTORY") if victory else tr("END_DEATH"), 34, UITheme.FLAME if victory else UITheme.CURSE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var flavor := UITheme.label(tr("END_VICTORY_TEXT") if victory else tr("END_DEATH_TEXT"), 12, UITheme.TEXT_DIM)
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.custom_minimum_size = Vector2(300, 0)
	box.add_child(flavor)
	box.add_child(HSeparator.new())
	var t := int(summary.get("time", 0.0))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	box.add_child(grid)
	var rows := [
		[tr("STAT_DEPTH"), str(summary.get("depth", 1))],
		[tr("STAT_TIME"), "%d:%02d" % [t / 60, t % 60]],
		[tr("STAT_KILLS"), str(summary.get("kills", 0))],
		[tr("STAT_ROOMS"), str(summary.get("rooms", 0))],
		[tr("STAT_RELICS"), str((summary.get("relics", []) as Array).size())],
		[tr("SEED"), str(summary.get("seed", ""))],
	]
	for r in rows:
		grid.add_child(UITheme.label(r[0], 12, UITheme.TEXT_DIM))
		grid.add_child(UITheme.label(r[1], 12))
	# the build of this expedition, as icons
	var relics: Array = summary.get("relics", [])
	if not relics.is_empty():
		var grid_r := GridContainer.new()
		grid_r.columns = 12
		grid_r.add_theme_constant_override("h_separation", 2)
		grid_r.add_theme_constant_override("v_separation", 2)
		for id in relics:
			var icon := TextureRect.new()
			icon.texture = RelicIcons.icon(str(id))
			icon.custom_minimum_size = Vector2(16, 16)
			icon.tooltip_text = tr(str(Database.relics.get(str(id), {}).get("name", id)))
			grid_r.add_child(icon)
		var cc := CenterContainer.new()
		cc.add_child(grid_r)
		box.add_child(cc)
	var sparks := UITheme.label(tr("END_SPARKS") % int(summary.get("sparks", 0)), 12, UITheme.SPECTRAL)
	sparks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sparks)
	if victory:
		var asc := UITheme.label(tr("END_ASCENSION_UNLOCK") % mini(10, int(summary.get("ascension", 0)) + 1), 12, UITheme.FLAME)
		asc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		asc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(asc)
	var b := make_button(tr("END_TO_PLAZA"), func(): Game.goto_hub())
	box.add_child(b)
	b.grab_focus.call_deferred()


func can_close() -> bool:
	return false
