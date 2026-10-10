class_name Level
extends Node2D
## An expedition in progress: owns the player, the current room, the camera,
## the HUD and the in-run overlays (pause, map, events, results).

var run: RunState
var player: Player
var room: Room
var camera: GameCamera
var hud: HUD
var world: Node2D
var _transitioning := false
var _overlay: Control = null
var _ui_layer: CanvasLayer
var _ended := false


func _ready() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	camera = GameCamera.new()
	add_child(camera)
	camera.make_current()
	player = Player.new()
	player.setup(run)
	hud = HUD.new()
	hud.level = self
	add_child(hud)
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 20
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)
	Events.player_died.connect(_on_player_died)
	load_floor(false)


func _exit_tree() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Lights.ambient = 0.0


func load_floor(with_fade: bool) -> void:
	var biome := Database.biome_for_depth(run.depth)
	var go := func():
		_enter_room(run.current_room, run.entered_from)
		hud.show_depth_banner(run.depth)
		Audio.music(str(biome.get("music", "")))
		Audio.ambience(str(biome.get("ambience", "")))
		Events.map_changed.emit()
	if with_fade:
		Audio.sfx("descend", 0.0, 0.0)
		Game.main.flash_fade(go, 0.6, 0.8)
	else:
		go.call()


func _enter_room(key: String, from_dir: String) -> void:
	if room and is_instance_valid(room):
		if player.get_parent() == room.entities:
			room.entities.remove_child(player)
		world.remove_child(room)
		room.queue_free()
	for p in get_tree().get_nodes_in_group("enemy_shots"):
		p.queue_free()
	run.current_room = key
	run.entered_from = from_dir
	room = Room.new()
	room.build(run, key)
	world.add_child(room)
	room.door_entered.connect(_on_door_entered)
	room.cleared.connect(func(_r): Game.save_run_snapshot())
	room.enter(player, from_dir)
	camera.focus(room.global_position + room.pixel_size() * 0.5 + Vector2(0, -4))
	player.reset_cooldowns()
	Game.save_run_snapshot()
	Events.map_changed.emit()


func _on_door_entered(dir: String) -> void:
	if _transitioning or _ended:
		return
	var next: Vector2i = DungeonGenerator.parse_key(run.current_room) + DungeonGenerator.DIRS[dir]
	var key := DungeonGenerator.key(next)
	if not run.floor.rooms.has(key):
		return
	_transitioning = true
	player.lock(true)
	Audio.sfx("door_pass", -6.0, 0.05)
	Game.main.flash_fade(func():
		_enter_room(key, DungeonGenerator.OPPOSITE[dir])
		player.lock(false)
		_transitioning = false)


func _unhandled_input(event: InputEvent) -> void:
	if _ended:
		return
	if event.is_action_pressed("pause"):
		if _overlay == null:
			open_pause()
		elif _overlay is PauseMenu or _overlay is MapOverlay:
			close_overlay()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map") and (_overlay == null or _overlay is MapOverlay):
		if _overlay == null:
			_open_overlay(MapOverlay.new())
		else:
			close_overlay()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# losing focus pauses the expedition (but never mid-transition)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _overlay == null and not _ended and not _transitioning and is_inside_tree() and player and player.bot == null:
		if DisplayServer.get_name() != "headless":
			open_pause()


func open_pause() -> void:
	_open_overlay(PauseMenu.new())


func _open_overlay(c: Control) -> void:
	if _overlay:
		_overlay.queue_free()
	_overlay = c
	if c.has_method("set_level"):
		c.set_level(self)
	_ui_layer.add_child(c)
	get_tree().paused = true
	hud.set_crosshair(false)


func close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	get_tree().paused = false
	hud.set_crosshair(true)


func show_event(event_id: String, altar: Node) -> void:
	var d := EventDialog.new()
	d.event_id = event_id
	d.altar = altar
	_open_overlay(d)


func _on_player_died() -> void:
	if _ended:
		return
	Game.finish_run(false)


func show_end(summary: Dictionary) -> void:
	_ended = true
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	var s := EndScreen.new()
	s.summary = summary
	_ui_layer.add_child(s)
	hud.set_crosshair(false)
	get_tree().paused = true
	Audio.music("victory" if summary.victory else "defeat")
