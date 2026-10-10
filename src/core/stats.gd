class_name Stats
extends RefCounted
## Numeric stat block with stacked modifiers:
##   final = (base + sum(add)) * product(mul)
## Modifiers are grouped by source (a relic id, a lantern, a curse) so they
## can be removed cleanly.

signal changed()

var base: Dictionary = {}
var _mods: Dictionary = {}   # source -> {stat -> [op, value]}
var _cache: Dictionary = {}


func _init(base_values: Dictionary = {}) -> void:
	base = base_values.duplicate()
	recompute()


func get_stat(key: String) -> float:
	return float(_cache.get(key, base.get(key, 0.0)))


func get_int(key: String) -> int:
	return int(round(get_stat(key)))


func set_base(key: String, value: float) -> void:
	base[key] = value
	recompute()


func add_source(source: String, mods: Dictionary) -> void:
	_mods[source] = mods.duplicate(true)
	recompute()


## Same source may be stacked by suffixing (#2, #3...).
func add_stacking(source: String, mods: Dictionary) -> String:
	var key := source
	var n := 1
	while _mods.has(key):
		n += 1
		key = "%s#%d" % [source, n]
	add_source(key, mods)
	return key


func remove_source(source: String) -> void:
	if _mods.erase(source):
		recompute()


func has_source(source: String) -> bool:
	return _mods.has(source)


func recompute() -> void:
	var adds := {}
	var muls := {}
	for src in _mods:
		var m: Dictionary = _mods[src]
		for stat in m:
			var mod: Array = m[stat]
			if mod[0] == "add":
				adds[stat] = float(adds.get(stat, 0.0)) + float(mod[1])
			elif mod[0] == "mul":
				muls[stat] = float(muls.get(stat, 1.0)) * float(mod[1])
	_cache.clear()
	var keys := {}
	for k in base:
		keys[k] = true
	for k in adds:
		keys[k] = true
	for k in muls:
		keys[k] = true
	for k in keys:
		_cache[k] = (float(base.get(k, 0.0)) + float(adds.get(k, 0.0))) * float(muls.get(k, 1.0))
	changed.emit()
