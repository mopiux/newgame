extends Node
## Game flow: menu <-> plaza (hub) <-> expedition (level), run lifecycle,
## sparks banking and the small global queries gameplay code needs.

var main: Node = null
var run: RunState = null
var level: Node = null
var map_revealed_depth := 0
var _play_time_accum := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if run and level and not get_tree().paused:
		run.time += delta
	if not get_tree().paused:
		_play_time_accum += delta
		if _play_time_accum >= 10.0:
			SaveManager.profile.stats.play_time += _play_time_accum
			_play_time_accum = 0.0


# --- screens ---------------------------------------------------------------------

func goto_menu() -> void:
	level = null
	main.show_screen(MainMenu.new())


func goto_hub() -> void:
	level = null
	main.show_screen(Hub.new())


func goto_credits() -> void:
	main.show_screen(CreditsScreen.new())


func new_run(lantern: String, seed_text: String = "", ascension: int = 0) -> void:
	SaveManager.clear_run()
	run = RunState.create(seed_text, lantern, ascension)
	run.generate_floor()
	map_revealed_depth = 0
	SaveManager.profile.stats.runs += 1
	SaveManager.profile.selected_lantern = lantern
	SaveManager.save_profile()
	if SaveManager.unlocked_effects().has("start_relic"):
		var ids := RelicPool.roll(run, run.rng("start_relic"), 1, ["common"])
		if not ids.is_empty():
			run.add_relic(ids[0])
	_start_level()


func continue_run() -> bool:
	var data = SaveManager.load_run()
	if data == null:
		SaveManager.clear_run()
		return false
	var r := RunState.from_dict(data)
	if r == null or r.floor.is_empty():
		SaveManager.clear_run()
		return false
	run = r
	map_revealed_depth = run.depth if bool(data.get("map_revealed", false)) else 0
	_start_level()
	return true


func _start_level() -> void:
	level = Level.new()
	level.run = run
	main.show_screen(level)


func save_run_snapshot() -> void:
	if run == null or level == null:
		return
	# a snuffed-out lamplighter is never saved: the run is already lost
	if level.player and not level.player.is_alive():
		return
	var d := run.to_dict()
	d["map_revealed"] = map_revealed_depth == run.depth
	SaveManager.save_run(d)
	SaveManager.save_profile()


# --- run events ---------------------------------------------------------------------

func descend() -> void:
	if run == null or level == null:
		return
	run.depth += 1
	run.generate_floor()
	if run.has_relic("cartographer"):
		map_revealed_depth = run.depth
	SaveManager.profile.stats.best_depth = maxi(SaveManager.profile.stats.best_depth, run.depth)
	level.load_floor(true)


func finish_run(victory: bool) -> void:
	if run == null:
		return
	var p := SaveManager.profile
	p.sparks += run.sparks
	p.stats.sparks_total += run.sparks
	p.stats.kills += run.kills
	p.stats.best_depth = maxi(p.stats.best_depth, run.depth)
	if victory:
		p.stats.wins += 1
		p.ascension_unlocked = clampi(maxi(p.ascension_unlocked, run.ascension + 1), 0, 10)
	else:
		p.stats.deaths += 1
	p.tutorial_done = true
	SaveManager.clear_run()
	SaveManager.save_profile()
	var summary := {
		"victory": victory, "depth": run.depth, "time": run.time, "kills": run.kills,
		"rooms": run.rooms_cleared, "sparks": run.sparks, "relics": run.relics.duplicate(),
		"seed": run.seed_text, "ascension": run.ascension,
	}
	if main and main.has_node("Autopilot"):
		main.get_node("Autopilot").record(summary)
	if level:
		level.show_end(summary)
	run = null


func abandon_run() -> void:
	if run:
		finish_run(false)


func add_sparks(n: int) -> void:
	if run == null:
		return
	run.sparks = maxi(0, run.sparks + n)
	Events.sparks_changed.emit(run.sparks)


func grant_relic(id: String) -> void:
	if run == null or not Database.relics.has(id):
		return
	run.add_relic(id)
	SaveManager.mark_seen("relics", id)
	if level and level.player:
		level.player.relic_fx.refresh()
		Events.player_flame_changed.emit(run.flame, level.player.max_flame())
	Events.relic_gained.emit(id)
	Audio.sfx("relic", 0.0, 0.0)
	if id == "cartographer":
		reveal_map()


func reveal_map() -> void:
	if run:
		map_revealed_depth = run.depth
		Events.map_changed.emit()


func open_event(event_id: String, altar: Node) -> void:
	if level:
		level.show_event(event_id, altar)


func pick_event(rng: RandomNumberGenerator) -> String:
	var tiers := [0]
	if SaveManager.is_unlocked("events_2"):
		tiers.append(1)
	var ids: Array = []
	var weights: Array = []
	for id in Database.events:
		var e: Dictionary = Database.events[id]
		if not (int(e.get("tier", 0)) in tiers):
			continue
		var dmin := int(e.get("min_depth", 1))
		var dmax := int(e.get("max_depth", 9))
		if run and (run.depth < dmin or run.depth > dmax):
			continue
		ids.append(id)
	# sort for determinism, then build weights in the same order
	ids.sort()
	for id in ids:
		weights.append(float(Database.events[id].get("weight", 1.0)))
	if ids.is_empty():
		return Database.events.keys()[0] if not Database.events.is_empty() else ""
	return RunRng.weighted_pick(rng, ids, weights)


func in_combat() -> bool:
	return level != null and level.room != null and level.room.combat_active


## Product of the ascension multipliers for `key` up to the run's level.
func ascension_mult(key: String, asc: int = -1) -> float:
	var level_n := asc if asc >= 0 else (run.ascension if run else 0)
	var m := 1.0
	for i in level_n:
		var lvl: Dictionary = Database.balance_value("ascension.%d" % (i + 1), {})
		m *= float(lvl.get("mults", {}).get(key, 1.0))
	return m


func enemy_shot_speed_mult() -> float:
	var m := ascension_mult("enemy_shot_speed")
	if run and run.has_relic("hourglass"):
		m *= 0.75
	return m


func quit_game() -> void:
	if run and level:
		if level.player and not level.player.is_alive():
			finish_run(false)
		else:
			save_run_snapshot()
	SaveManager.profile.stats.play_time += _play_time_accum
	_play_time_accum = 0.0
	SaveManager.save_profile()
	Settings.save_settings()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
