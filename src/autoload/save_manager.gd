extends Node
## Persistent data: the profile (meta-progression) and the snapshot of a run
## in progress. Files are JSON wrapped with a checksum, written atomically
## (tmp file + rename) with a .bak copy of the previous good version.

const VERSION := 1

var profile_path := "user://profile.json"
var run_path := "user://run.json"
var profile: Dictionary = {}
var last_load_warning: String = ""


func _ready() -> void:
	# automated play (bot, screen tour, tests) never touches the real profile
	var args := OS.get_cmdline_user_args()
	var name := ""
	if args.has("--profile") and args.find("--profile") + 1 < args.size():
		name = args[args.find("--profile") + 1]
	elif args.has("--bot") or args.has("--tour"):
		name = "test"
	if name != "":
		profile_path = "user://profile_%s.json" % name.validate_filename()
		run_path = "user://run_%s.json" % name.validate_filename()
	load_profile()


static func default_profile() -> Dictionary:
	return {
		"version": VERSION,
		"sparks": 0,
		"lamps": [],
		"selected_lantern": "oil",
		"seen_relics": [],
		"seen_enemies": [],
		"bosses_defeated": [],
		"ascension_unlocked": 0,
		"ascension_selected": 0,
		"tutorial_done": false,
		"stats": {
			"runs": 0, "wins": 0, "deaths": 0, "best_depth": 0,
			"kills": 0, "play_time": 0.0, "sparks_total": 0,
		},
	}


# --- generic IO ---------------------------------------------------------------

func write_json(path: String, payload: Dictionary) -> bool:
	var body := JSON.stringify(payload)
	var wrapped := JSON.stringify({"check": body.hash(), "payload": body})
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(wrapped)
	f.close()
	if FileAccess.file_exists(path):
		var bak := path + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(path, bak)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("SaveManager: rename failed for %s (%s)" % [path, error_string(err)])
		return false
	return true


## Returns the payload dictionary, or null if missing/corrupt.
func read_json(path: String) -> Variant:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var text := FileAccess.get_file_as_string(candidate)
		var outer = JSON.parse_string(text)
		if typeof(outer) != TYPE_DICTIONARY or not outer.has("payload") or not outer.has("check"):
			last_load_warning = "corrupt file " + candidate
			push_warning("SaveManager: " + last_load_warning)
			continue
		var body: String = str(outer.payload)
		if int(outer.check) != body.hash():
			last_load_warning = "checksum mismatch in " + candidate
			push_warning("SaveManager: " + last_load_warning)
			continue
		var inner = JSON.parse_string(body)
		if typeof(inner) == TYPE_DICTIONARY:
			return inner
	return null


func delete_file(path: String) -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


# --- profile -----------------------------------------------------------------

func load_profile() -> void:
	last_load_warning = ""
	var data = read_json(profile_path)
	profile = sanitize_profile(data if data != null else {})


func save_profile() -> bool:
	return write_json(profile_path, profile)


func reset_profile() -> void:
	profile = default_profile()
	delete_file(profile_path)
	delete_file(run_path)
	save_profile()


static func sanitize_profile(src: Dictionary) -> Dictionary:
	var p := default_profile()
	p.sparks = maxi(0, int(src.get("sparks", 0)))
	for key in ["lamps", "seen_relics", "seen_enemies", "bosses_defeated"]:
		var v = src.get(key, [])
		if typeof(v) == TYPE_ARRAY:
			for item in v:
				if typeof(item) == TYPE_STRING and not p[key].has(item):
					p[key].append(item)
	var lantern = src.get("selected_lantern", "oil")
	p.selected_lantern = lantern if typeof(lantern) == TYPE_STRING else "oil"
	p.ascension_unlocked = clampi(int(src.get("ascension_unlocked", 0)), 0, 10)
	p.ascension_selected = clampi(int(src.get("ascension_selected", 0)), 0, p.ascension_unlocked)
	p.tutorial_done = bool(src.get("tutorial_done", false))
	var st = src.get("stats", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k in p.stats:
			if st.has(k) and typeof(st[k]) in [TYPE_INT, TYPE_FLOAT]:
				p.stats[k] = maxf(0.0, float(st[k])) if k == "play_time" else maxi(0, int(st[k]))
	return p


# --- unlock queries ---------------------------------------------------------

func has_lamp(id: String) -> bool:
	return profile.lamps.has(id)


func unlocked_effects() -> Array:
	var out: Array = []
	for lamp in Database.lamps:
		if profile.lamps.has(lamp.get("id", "")):
			out.append(lamp.get("unlock", ""))
	return out


func is_unlocked(effect: String) -> bool:
	return effect == "" or unlocked_effects().has(effect)


func unlocked_relic_tiers() -> Array:
	var tiers := [0]
	for e in unlocked_effects():
		if str(e).begins_with("relic_tier_"):
			tiers.append(int(str(e).trim_prefix("relic_tier_")))
	return tiers


func lantern_unlocked(id: String) -> bool:
	var l: Dictionary = Database.lanterns.get(id, {})
	if l.is_empty():
		return false
	return is_unlocked(l.get("unlock", ""))


func mark_seen(kind: String, id: String) -> void:
	var key := "seen_" + kind
	if profile.has(key) and not profile[key].has(id):
		profile[key].append(id)


# --- run snapshot -------------------------------------------------------------

func has_run() -> bool:
	return read_json(run_path) != null


func save_run(snapshot: Dictionary) -> bool:
	snapshot["version"] = VERSION
	return write_json(run_path, snapshot)


func load_run() -> Variant:
	var data = read_json(run_path)
	if data == null or int(data.get("version", 0)) != VERSION:
		return null
	return data


func clear_run() -> void:
	delete_file(run_path)
