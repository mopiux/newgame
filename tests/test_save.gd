extends TestCase
## Persistence: atomic writes, checksum validation, backups, sanitising.

const PATH := "user://test_save.json"


func _cleanup() -> void:
	SaveManager.delete_file(PATH)


func test_roundtrip() -> void:
	_cleanup()
	var data := {"a": 1, "b": [1, 2, 3], "c": {"d": "x"}}
	check(SaveManager.write_json(PATH, data), "write succeeds")
	var back = SaveManager.read_json(PATH)
	# JSON numbers come back as floats; compare through a JSON round trip
	eq(JSON.stringify(back), JSON.stringify(JSON.parse_string(JSON.stringify(data))), "same content")
	_cleanup()


func test_corruption_falls_back_to_backup() -> void:
	_cleanup()
	SaveManager.write_json(PATH, {"v": 1})
	SaveManager.write_json(PATH, {"v": 2})   # previous good copy -> .bak
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var back = SaveManager.read_json(PATH)
	check(back != null, "backup used")
	eq(int(back.get("v", 0)), 1, "backup holds the previous version")
	# tampered payload (checksum mismatch) also rejected
	var f2 := FileAccess.open(PATH, FileAccess.WRITE)
	f2.store_string(JSON.stringify({"check": 1, "payload": "{\"v\": 3}"}))
	f2.close()
	back = SaveManager.read_json(PATH)
	eq(int(back.get("v", 0)), 1, "checksum mismatch rejected")
	_cleanup()
	eq(SaveManager.read_json(PATH), null, "missing file -> null")


func test_profile_sanitising() -> void:
	var p := SaveManager.sanitize_profile({
		"sparks": -50, "lamps": ["market", 5, "market", null], "ascension_unlocked": 99,
		"ascension_selected": 50, "stats": {"runs": "lots", "kills": 7, "play_time": -3.0},
		"selected_lantern": 42,
	})
	eq(p.sparks, 0, "negative sparks clamped")
	eq(p.lamps, ["market"], "lamps deduplicated and typed")
	eq(p.ascension_unlocked, 10, "ascension clamped")
	eq(p.ascension_selected, 10, "selected <= unlocked")
	eq(p.stats.runs, 0, "non-numeric stat reset")
	eq(p.stats.kills, 7, "valid stat kept")
	near(p.stats.play_time, 0.0, 0.001, "negative time clamped")
	eq(p.selected_lantern, "oil", "bad lantern reset")


func test_unlocks_follow_lamps() -> void:
	var saved := SaveManager.profile
	SaveManager.profile = SaveManager.default_profile()
	check(not SaveManager.lantern_unlocked("mirror"), "mirror locked by default")
	check(SaveManager.lantern_unlocked("oil"), "oil always available")
	eq(SaveManager.unlocked_relic_tiers(), [0], "only base relics")
	SaveManager.profile.lamps = ["workshop", "market"]
	check(SaveManager.lantern_unlocked("mirror"), "workshop lamp unlocks mirror")
	check(SaveManager.unlocked_relic_tiers().has(1), "market lamp unlocks tier 1")
	SaveManager.profile = saved


func test_settings_sanitise() -> void:
	eq(Settings._sanitize("audio", "music", 7.0), 1.0, "volume clamped")
	eq(Settings._sanitize("audio", "music", "loud"), 0.7, "bad type -> default")
	eq(Settings._sanitize("video", "fullscreen", 1), true, "int to bool")
	eq(Settings._sanitize("game", "language", "xx"), "", "unknown language")
