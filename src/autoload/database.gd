extends Node
## Loads and validates the JSON game data in res://data.
## Everything designers tune (stats, relics, enemies, events, unlocks)
## lives in those files; code only implements behaviours.

const DATA_DIR := "res://data/"

var lanterns: Dictionary = {}
var relics: Dictionary = {}
var enemies: Dictionary = {}
var biomes: Array = []
var events: Dictionary = {}
var lamps: Array = []
var balance: Dictionary = {}
var errors: PackedStringArray = []


func _ready() -> void:
	reload()


func reload() -> void:
	errors.clear()
	lanterns = _index(_load("lanterns.json", []), "lanterns")
	relics = _index(_load("relics.json", []), "relics")
	enemies = _index(_load("enemies.json", []), "enemies")
	events = _index(_load("events.json", []), "events")
	biomes = _load("biomes.json", [])
	lamps = _load("lamps.json", [])
	balance = _load("balance.json", {})
	_validate()
	for e in errors:
		push_error("Database: " + e)


func _load(file: String, fallback: Variant) -> Variant:
	var path := DATA_DIR + file
	if not FileAccess.file_exists(path):
		errors.append("missing data file " + path)
		return fallback
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		errors.append("%s:%d %s" % [path, json.get_error_line(), json.get_error_message()])
		return fallback
	if typeof(json.data) != typeof(fallback):
		errors.append("%s has unexpected root type" % path)
		return fallback
	return json.data


func _index(list: Array, label: String) -> Dictionary:
	var out := {}
	for entry in list:
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("id"):
			errors.append("%s entry without id: %s" % [label, str(entry).left(80)])
			continue
		if out.has(entry.id):
			errors.append("%s duplicate id %s" % [label, entry.id])
		out[entry.id] = entry
	return out


func _validate() -> void:
	for id in relics:
		var r: Dictionary = relics[id]
		for key in ["rarity", "icon"]:
			if not r.has(key):
				errors.append("relic %s missing %s" % [id, key])
		for stat in r.get("stats", {}):
			var mod = r.stats[stat]
			if typeof(mod) != TYPE_ARRAY or mod.size() != 2 or not (mod[0] in ["add", "mul"]):
				errors.append("relic %s bad stat modifier %s" % [id, stat])
	for id in enemies:
		var e: Dictionary = enemies[id]
		for key in ["hp", "behavior", "sprite"]:
			if not e.has(key):
				errors.append("enemy %s missing %s" % [id, key])
	for b in biomes:
		for id in b.get("enemies", []):
			if not enemies.has(id):
				errors.append("biome %s references unknown enemy %s" % [b.get("id", "?"), id])
	for id in events:
		if events[id].get("options", []).is_empty():
			errors.append("event %s has no options" % id)


func balance_value(path: String, fallback: Variant = null) -> Variant:
	var node: Variant = balance
	for part in path.split("."):
		if typeof(node) != TYPE_DICTIONARY or not node.has(part):
			return fallback
		node = node[part]
	return node


func biome_for_depth(depth: int) -> Dictionary:
	if biomes.is_empty():
		return {}
	return biomes[clampi(depth - 1, 0, biomes.size() - 1)]


func relic_ids_for_pool(unlocked_tiers: Array, exclude: Array = []) -> Array:
	var out: Array = []
	for id in relics:
		var r: Dictionary = relics[id]
		# JSON numbers are floats: compare as int or tiers never match
		if int(r.get("tier", 0)) in unlocked_tiers and not (id in exclude) and not r.get("no_pool", false):
			out.append(id)
	out.sort()
	return out
