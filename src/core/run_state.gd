class_name RunState
extends RefCounted
## Everything about the current expedition. Serialisable so the run can be
## resumed ("Continuar") after quitting: floors are regenerated from the seed
## and the per-room state below is overlaid on top.

var seed_text: String = ""
var run_seed: int = 0
var depth: int = 1
var lantern_id: String = "oil"
var ascension: int = 0

var flame: float = 100.0
var relics: Array = []          # relic ids in pickup order (duplicates allowed for stackables)
var sparks: int = 0             # collected this run, banked on exit
var kills: int = 0
var rooms_cleared: int = 0
var time: float = 0.0
var revive_used: bool = false
var curses: Array = []           # event-applied modifiers: [{id, stats}]

var floor: Dictionary = {}       # DungeonGenerator output for the current depth
var rooms: Dictionary = {}       # key -> mutable room state
var current_room: String = ""
var entered_from: String = ""    # door direction the player came through
var seen_relics_run: Array = []  # offered this run (avoid repeats)

var stats: Stats


static func create(seed_text_in: String, lantern: String, asc: int) -> RunState:
	var r := RunState.new()
	r.seed_text = seed_text_in.strip_edges().to_upper()
	if r.seed_text == "":
		r.seed_text = RunRng.random_seed_text()
	r.run_seed = RunRng.seed_from_text(r.seed_text)
	r.lantern_id = lantern
	r.ascension = asc
	r.build_stats()
	r.flame = r.stats.get_stat("max_flame")
	return r


func build_stats() -> void:
	var base: Dictionary = Database.balance_value("player", {}).duplicate()
	stats = Stats.new(base)
	var lantern: Dictionary = Database.lanterns.get(lantern_id, {})
	if lantern.has("stats"):
		stats.add_source("lantern", lantern.stats)
	# permanent plaza upgrades
	for effect in SaveManager.unlocked_effects():
		var up: Dictionary = Database.balance_value("lamp_bonuses." + str(effect), {})
		if not up.is_empty():
			stats.add_source("lamp:" + str(effect), up)
	if ascension > 0:
		var asc_mods := {}
		for i in ascension:
			var lvl: Dictionary = Database.balance_value("ascension." + str(i + 1), {})
			for k in lvl.get("player", {}):
				asc_mods[k] = lvl.player[k]
		if not asc_mods.is_empty():
			stats.add_source("ascension", asc_mods)
	var i := 0
	for id in relics:
		var r: Dictionary = Database.relics.get(id, {})
		if r.has("stats"):
			stats.add_source("relic:%s:%d" % [id, i], r.stats)
		i += 1
	for c in curses:
		stats.add_source("curse:" + str(c.get("id", "?")), c.get("stats", {}))


func add_relic(id: String) -> void:
	relics.append(id)
	var r: Dictionary = Database.relics.get(id, {})
	var old_max := stats.get_stat("max_flame")
	if r.has("stats"):
		stats.add_source("relic:%s:%d" % [id, relics.size() - 1], r.stats)
	# max flame increases also fill the new capacity
	var gained := stats.get_stat("max_flame") - old_max
	if gained > 0.0:
		flame += gained
	flame = minf(flame, stats.get_stat("max_flame"))


func add_curse(id: String, mods: Dictionary) -> void:
	curses.append({"id": id + str(curses.size()), "stats": mods})
	stats.add_source("curse:" + id + str(curses.size() - 1), mods)
	flame = minf(flame, stats.get_stat("max_flame"))


func relic_count(id: String) -> int:
	return relics.count(id)


func has_relic(id: String) -> bool:
	return relics.has(id)


func room_state(key: String) -> Dictionary:
	if not rooms.has(key):
		rooms[key] = {"visited": false, "cleared": false, "lit": [], "pots": [], "loot_taken": false, "data": {}}
	return rooms[key]


func room_info(key: String) -> Dictionary:
	return floor.get("rooms", {}).get(key, {})


func generate_floor() -> void:
	var biome := Database.biome_for_depth(depth)
	floor = DungeonGenerator.generate(run_seed, depth, biome.get("layout", {}))
	rooms.clear()
	current_room = floor.get("start", "0,0")
	entered_from = ""
	room_state(current_room).visited = true


## JSON turns integers into floats; index lists must be ints again or
## Array.has(int) lookups (lit braziers, broken pots) silently fail.
static func _normalize_room_state(st: Dictionary) -> Dictionary:
	for key in ["lit", "pots"]:
		var fixed: Array = []
		for v in st.get(key, []):
			if typeof(v) in [TYPE_INT, TYPE_FLOAT]:
				fixed.append(int(v))
		st[key] = fixed
	for key in ["visited", "cleared", "loot_taken", "lit_bonus", "mimic_dead"]:
		if st.has(key):
			st[key] = bool(st[key])
	if typeof(st.get("data")) != TYPE_DICTIONARY:
		st["data"] = {}
	return st


func rng(tag: String) -> RandomNumberGenerator:
	return RunRng.make(run_seed, "d%d|%s" % [depth, tag])


func to_dict() -> Dictionary:
	return {
		"seed_text": seed_text, "depth": depth, "lantern": lantern_id, "ascension": ascension,
		"flame": flame, "relics": relics.duplicate(), "sparks": sparks, "kills": kills,
		"rooms_cleared": rooms_cleared, "time": time, "revive_used": revive_used,
		"curses": curses.duplicate(true), "rooms": rooms.duplicate(true),
		"current_room": current_room, "entered_from": entered_from,
		"seen_relics_run": seen_relics_run.duplicate(),
	}


static func from_dict(d: Dictionary) -> RunState:
	var r := RunState.new()
	r.seed_text = str(d.get("seed_text", ""))
	if r.seed_text == "":
		return null
	r.run_seed = RunRng.seed_from_text(r.seed_text)
	r.depth = clampi(int(d.get("depth", 1)), 1, maxi(1, Database.biomes.size()))
	r.lantern_id = str(d.get("lantern", "oil"))
	if not Database.lanterns.has(r.lantern_id):
		r.lantern_id = "oil"
	r.ascension = clampi(int(d.get("ascension", 0)), 0, 10)
	for id in d.get("relics", []):
		if Database.relics.has(str(id)):
			r.relics.append(str(id))
	for c in d.get("curses", []):
		if typeof(c) == TYPE_DICTIONARY:
			r.curses.append(c)
	r.sparks = maxi(0, int(d.get("sparks", 0)))
	r.kills = maxi(0, int(d.get("kills", 0)))
	r.rooms_cleared = maxi(0, int(d.get("rooms_cleared", 0)))
	r.time = maxf(0.0, float(d.get("time", 0.0)))
	r.revive_used = bool(d.get("revive_used", false))
	r.seen_relics_run = d.get("seen_relics_run", [])
	r.build_stats()
	var biome := Database.biome_for_depth(r.depth)
	r.floor = DungeonGenerator.generate(r.run_seed, r.depth, biome.get("layout", {}))
	var saved_rooms = d.get("rooms", {})
	if typeof(saved_rooms) == TYPE_DICTIONARY:
		for k in saved_rooms:
			if r.floor.rooms.has(k) and typeof(saved_rooms[k]) == TYPE_DICTIONARY:
				r.rooms[k] = _normalize_room_state(saved_rooms[k])
	r.current_room = str(d.get("current_room", r.floor.get("start", "0,0")))
	if not r.floor.rooms.has(r.current_room):
		r.current_room = r.floor.start
	r.entered_from = str(d.get("entered_from", ""))
	r.flame = clampf(float(d.get("flame", 1.0)), 1.0, r.stats.get_stat("max_flame"))
	return r
