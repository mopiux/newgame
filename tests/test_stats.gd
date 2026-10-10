extends TestCase
## Stat modifiers, relic stacking and run-state serialisation.


func test_add_and_mul_stack() -> void:
	var s := Stats.new({"damage": 10.0, "speed": 100.0})
	near(s.get_stat("damage"), 10.0)
	s.add_source("a", {"damage": ["add", 5]})
	near(s.get_stat("damage"), 15.0, 0.001, "add")
	s.add_source("b", {"damage": ["mul", 2.0]})
	near(s.get_stat("damage"), 30.0, 0.001, "(10+5)*2")
	s.add_stacking("b", {"damage": ["mul", 2.0]})
	near(s.get_stat("damage"), 60.0, 0.001, "stacked mul")
	s.remove_source("a")
	near(s.get_stat("damage"), 40.0, 0.001, "remove add")
	near(s.get_stat("speed"), 100.0, 0.001, "untouched stat")
	near(s.get_stat("missing"), 0.0, 0.001, "unknown stat is 0")


func test_relics_apply_to_run() -> void:
	var r := RunState.create("STATS", "oil", 0)
	var base_max := r.stats.get_stat("max_flame")
	r.add_relic("braided_wick")
	near(r.stats.get_stat("max_flame"), base_max + 20.0, 0.001, "braided wick +20")
	near(r.flame, base_max + 20.0, 0.001, "max flame gain also fills")
	r.add_relic("braided_wick")
	near(r.stats.get_stat("max_flame"), base_max + 40.0, 0.001, "stackable relic stacks")
	r.add_relic("black_candle")
	near(r.stats.get_stat("max_flame"), base_max + 15.0, 0.001, "cursed relic lowers max")
	check(r.flame <= r.stats.get_stat("max_flame"), "flame clamped to new max")
	eq(r.relic_count("braided_wick"), 2)


func test_lanterns_modify_stats() -> void:
	var oil := RunState.create("L", "oil", 0)
	var ember := RunState.create("L", "ember", 0)
	check(ember.stats.get_int("shot_count") == oil.stats.get_int("shot_count") + 2, "hand brazier fires 3")
	var mirror := RunState.create("L", "mirror", 0)
	eq(mirror.stats.get_int("bounce"), 1, "mirror lamp bounces")


func test_ascension_multipliers() -> void:
	eq(Game.ascension_mult("enemy_hp", 0), 1.0, "no ascension")
	check(Game.ascension_mult("enemy_hp", 1) > 1.0, "night 1 raises creature health")
	check(Game.ascension_mult("enemy_hp", 10) > Game.ascension_mult("enemy_hp", 1), "higher nights are harder")
	var r := RunState.create("A", "oil", 10)
	check(r.stats.get_stat("max_flame") < RunState.create("A", "oil", 0).stats.get_stat("max_flame"), "night 10 lowers max flame")


func test_run_state_roundtrip() -> void:
	var r := RunState.create("ROUNDTRIP", "mirror", 2)
	r.generate_floor()
	r.add_relic("lens")
	r.add_relic("prism")
	r.sparks = 7
	r.flame = 42.5
	r.kills = 12
	var key: String = r.floor.rooms.keys()[1]
	r.room_state(key).cleared = true
	r.room_state(key).lit = [0, 1]
	r.current_room = key
	r.entered_from = "n"
	var d := r.to_dict()
	var json := JSON.stringify(d)
	var back := RunState.from_dict(JSON.parse_string(json))
	check(back != null, "deserialises")
	eq(back.seed_text, "ROUNDTRIP")
	eq(back.lantern_id, "mirror")
	eq(back.ascension, 2)
	eq(back.relics, ["lens", "prism"])
	eq(back.sparks, 7)
	near(back.flame, 42.5)
	eq(back.current_room, key)
	eq(back.entered_from, "n")
	check(back.rooms[key].cleared, "room state kept")
	check(back.rooms[key].lit.has(0) and back.rooms[key].lit.has(1), "lit brazier indices survive JSON as ints")
	eq(JSON.stringify(back.floor), JSON.stringify(r.floor), "floor regenerated identically from seed")
	near(back.stats.get_stat("shot_damage"), r.stats.get_stat("shot_damage"), 0.001, "stats rebuilt from relics")


func test_run_state_rejects_garbage() -> void:
	eq(RunState.from_dict({}), null, "empty snapshot rejected")
	var r := RunState.from_dict({"seed_text": "X", "depth": 99, "lantern": "nope", "relics": ["lens", "not_a_relic"], "flame": -5})
	check(r != null, "repairs bad values")
	eq(r.depth, Database.biomes.size(), "depth clamped")
	eq(r.lantern_id, "oil", "unknown lantern falls back")
	eq(r.relics, ["lens"], "unknown relics dropped")
	check(r.flame >= 1.0, "flame clamped to >= 1")
