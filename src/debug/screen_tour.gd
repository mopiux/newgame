class_name ScreenTour
extends Node
## Visits every screen of the game and saves a screenshot of each one:
##   godot --path . -- --tour OUTPUT_DIR
## Used for visual review and as a smoke test of the whole UI.

var out_dir := ""
var _steps: Array = []
var _i := 0
var _wait := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out_dir)
	_steps = [
		["menu", 2.5, func(): Game.goto_menu()],
		["options", 1.0, func(): _open_options_from_menu()],
		["options_controls", 0.8, func(): _options_tab(3)],
		["plaza", 3.0, func():
			SaveManager.profile.sparks = 40
			SaveManager.profile.lamps = ["market", "fountain", "workshop"]
			Game.goto_hub()],
		["expedition_panel", 1.0, func(): _hub_interact("Well")],
		["codex", 1.0, func():
			_close_hub_panel()
			_hub_interact("NoticeBoard")],
		["run_start", 3.5, func():
			_close_hub_panel()
			Game.new_run("oil", "TOUR", 0)],
		["chalk_hints", 3.0, func(): pass],
		["pause", 1.0, func(): Game.level.open_pause()],
		["map", 1.0, func():
			Game.level.close_overlay()
			Game.level._open_overlay(MapOverlay.new())],
		["event", 1.0, func():
			Game.level.close_overlay()
			Game.level.show_event("black_altar", null)],
		["treasure_room", 2.0, func():
			Game.level.close_overlay()
			_jump_to_room_type("treasure")],
		["shop_room", 2.0, func(): _jump_to_room_type("shop")],
		["combat_room", 4.0, func(): _jump_to_room_type("combat")],
		["boss_room", 5.0, func():
			Game.run.flame = 100
			_jump_to_room_type("boss")],
		["boss_fight", 4.0, func(): pass],
		["crypt", 3.0, func():
			Game.run.depth = 1
			Game.descend()],
		["foundry", 4.0, func(): Game.descend()],
		["end_victory", 2.0, func(): Game.finish_run(true)],
	]


func _process(delta: float) -> void:
	if _i >= _steps.size():
		return
	_wait -= delta
	if _wait > 0.0:
		return
	if _i > 0:
		_capture(_steps[_i - 1][0])
	if _i >= _steps.size():
		return
	var step: Array = _steps[_i]
	print("TOUR %s" % step[0])
	step[2].call()
	_wait = step[1]
	_i += 1
	if _i >= _steps.size():
		var tw := create_tween()
		tw.tween_interval(_wait + 0.2)
		tw.tween_callback(func():
			_capture(_steps[_steps.size() - 1][0])
			print("TOUR_DONE")
			get_tree().quit())


func _capture(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [out_dir, _i, tag])


func _open_options_from_menu() -> void:
	for n in get_tree().root.find_children("*", "MainMenu", true, false):
		(n as MainMenu)._open_options()


func _options_tab(idx: int) -> void:
	for n in get_tree().root.find_children("*", "TabContainer", true, false):
		(n as TabContainer).current_tab = idx


func _hub_interact(kind: String) -> void:
	for h in get_tree().root.find_children("*", "Hub", true, false):
		var hub := h as Hub
		if kind == "Well":
			hub.open_panel(ExpeditionPanel.new())
		else:
			hub.open_panel(CodexPanel.new())


func _close_hub_panel() -> void:
	for h in get_tree().root.find_children("*", "Hub", true, false):
		var hub := h as Hub
		if hub._panel:
			hub._panel.queue_free()
	get_tree().paused = false


func _jump_to_room_type(t: String) -> void:
	var level: Level = Game.level
	for k in level.run.floor.rooms:
		if level.run.floor.rooms[k].type == t:
			level._enter_room(k, "s" if (level.run.floor.rooms[k].doors as Array).has("s") else str(level.run.floor.rooms[k].doors[0]))
			return
