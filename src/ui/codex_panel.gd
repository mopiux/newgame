class_name CodexPanel
extends Control
## Notice board: records, relic codex and bestiary.


func _ready() -> void:
	var box := HubPanels.base_panel(self, Vector2(520, 300))
	box.add_child(UITheme.title_label(tr("CODEX_TITLE"), 24))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(500, 240)
	tabs.add_theme_stylebox_override("panel", UITheme.box(Color(UITheme.NIGHT, 0.6), UITheme.BRASS_DARK, 1, 6))
	tabs.add_theme_stylebox_override("tab_selected", UITheme.box(UITheme.PANEL_LIGHT, UITheme.BRASS, 1, 3))
	tabs.add_theme_stylebox_override("tab_unselected", UITheme.box(UITheme.NIGHT, UITheme.BRASS_DARK, 1, 3))
	tabs.add_theme_stylebox_override("tab_hovered", UITheme.box(UITheme.PANEL, UITheme.BRASS, 1, 3))
	tabs.add_theme_color_override("font_selected_color", UITheme.FLAME)
	tabs.add_theme_color_override("font_unselected_color", UITheme.TEXT_DIM)
	box.add_child(tabs)
	_stats_page(tabs)
	_relics_page(tabs)
	_bestiary_page(tabs)
	var back := Button.new()
	back.text = tr("BACK")
	back.pressed.connect(func():
		Audio.ui("ui_back")
		queue_free())
	box.add_child(back)
	back.grab_focus.call_deferred()


func _scroll(tabs: TabContainer, title: String) -> VBoxContainer:
	var s := ScrollContainer.new()
	s.name = title
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(s)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	s.add_child(v)
	return v


func _stats_page(tabs: TabContainer) -> void:
	var v := _scroll(tabs, tr("CODEX_STATS"))
	var st: Dictionary = SaveManager.profile.stats
	var t := int(st.play_time)
	var rows := [
		[tr("STAT_RUNS"), str(st.runs)], [tr("STAT_WINS"), str(st.wins)],
		[tr("STAT_DEATHS"), str(st.deaths)], [tr("STAT_BEST_DEPTH"), str(st.best_depth)],
		[tr("STAT_KILLS"), str(st.kills)], [tr("STAT_SPARKS_TOTAL"), str(st.sparks_total)],
		[tr("STAT_PLAYTIME"), "%dh %02dm" % [t / 3600, (t / 60) % 60]],
		[tr("STAT_LAMPS"), "%d / %d" % [SaveManager.profile.lamps.size(), Database.lamps.size()]],
		[tr("STAT_ASCENSION"), str(SaveManager.profile.ascension_unlocked)],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	v.add_child(grid)
	for r in rows:
		grid.add_child(UITheme.label(r[0], 12, UITheme.TEXT_DIM))
		grid.add_child(UITheme.label(r[1], 12))


func _relics_page(tabs: TabContainer) -> void:
	var v := _scroll(tabs, tr("CODEX_RELICS"))
	var seen: Array = SaveManager.profile.seen_relics
	v.add_child(UITheme.label(tr("CODEX_FOUND") % [seen.size(), Database.relics.size()], 12, UITheme.TEXT_DIM))
	var ids: Array = Database.relics.keys()
	ids.sort()
	for id in ids:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var icon := TextureRect.new()
		icon.texture = RelicIcons.icon(id)
		icon.custom_minimum_size = Vector2(16, 16)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		var known := seen.has(id)
		if not known:
			icon.modulate = Color(0, 0, 0, 0.8)
		row.add_child(icon)
		var r: Dictionary = Database.relics[id]
		var txt := UITheme.label((tr(str(r.get("name", id))) + " - " + tr(str(r.get("desc", "")))) if known else "? ? ?", 12, RelicIcons.rarity_color(id) if known else UITheme.TEXT_DIM)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt)
		v.add_child(row)


func _bestiary_page(tabs: TabContainer) -> void:
	var v := _scroll(tabs, tr("CODEX_BESTIARY"))
	var seen: Array = SaveManager.profile.seen_enemies
	var ids: Array = Database.enemies.keys()
	ids.sort_custom(func(a, b): return int(Database.enemies[a].get("order", 0)) < int(Database.enemies[b].get("order", 0)))
	for id in ids:
		var e: Dictionary = Database.enemies[id]
		var known := seen.has(id)
		var txt := UITheme.label((tr(str(e.get("name", id))) + " - " + tr(str(e.get("lore", "")))) if known else "? ? ?", 12, UITheme.TEXT if known else UITheme.TEXT_DIM)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(txt)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		queue_free()
