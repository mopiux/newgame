extends TestCase
## Floor generation: validity rules and determinism over many seeds.

const SEEDS := 150


func _floor(seed_value: int, depth: int) -> Dictionary:
	var biome := Database.biome_for_depth(depth)
	return DungeonGenerator.generate(seed_value, depth, biome.get("layout", {}))


func test_floors_are_valid() -> void:
	for depth in [1, 2, 3]:
		for s in SEEDS:
			var f := _floor(s * 7919 + 13, depth)
			if not check(not f.is_empty(), "seed %d depth %d produced no floor" % [s, depth]):
				continue
			_validate(f, "seed %d depth %d" % [s, depth])


func _validate(f: Dictionary, label: String) -> void:
	var rooms: Dictionary = f.rooms
	var counts := {}
	for k in rooms:
		var t: String = rooms[k].type
		counts[t] = int(counts.get(t, 0)) + 1
	eq(counts.get("start", 0), 1, label + " start rooms")
	eq(counts.get("boss", 0), 1, label + " boss rooms")
	check(counts.get("treasure", 0) >= 1, label + " has treasure")
	check(counts.get("shop", 0) >= 1, label + " has shop")
	# reachability through normal doors (secret room excluded)
	var start := DungeonGenerator.parse_key(f.start)
	var seen := {start: 0}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		var info: Dictionary = rooms[DungeonGenerator.key(c)]
		for d in info.doors:
			var n: Vector2i = c + DungeonGenerator.DIRS[d]
			var nk := DungeonGenerator.key(n)
			check(rooms.has(nk), "%s door %s of %s leads nowhere" % [label, d, DungeonGenerator.key(c)])
			if not rooms.has(nk):
				continue
			# doors are symmetric
			var back: Array = rooms[nk].doors
			check(back.has(DungeonGenerator.OPPOSITE[d]), "%s door %s->%s not mirrored" % [label, DungeonGenerator.key(c), nk])
			if rooms[nk].type == "secret":
				check((info.secret_doors as Array).has(d), "%s secret room reached by a normal door" % label)
				continue
			if not seen.has(n):
				seen[n] = seen[c] + 1
				queue.append(n)
	for k in rooms:
		if rooms[k].type != "secret":
			check(seen.has(DungeonGenerator.parse_key(k)), "%s room %s unreachable" % [label, k])
	var boss := DungeonGenerator.parse_key(f.boss)
	eq(rooms[f.boss].doors.size(), 1, label + " boss is a dead end")
	check(int(seen.get(boss, 0)) >= 3, label + " boss too close to start")
	for k in rooms:
		if rooms[k].type in ["treasure", "shop", "trial"]:
			eq(rooms[k].doors.size(), 1, "%s %s is a dead end" % [label, rooms[k].type])
		if rooms[k].type == "secret":
			check(rooms[k].doors.size() >= 2, label + " secret touches >= 2 rooms")
			for d in rooms[k].doors:
				var n2: Vector2i = DungeonGenerator.parse_key(k) + DungeonGenerator.DIRS[d]
				var t2: String = rooms[DungeonGenerator.key(n2)].type
				check(t2 != "boss" and t2 != "start", label + " secret next to " + t2)


func test_special_rooms_appear() -> void:
	var trials := 0
	var darks := 0
	for s in 60:
		var f := _floor(s, 2)
		for k in f.rooms:
			if f.rooms[k].type == "trial":
				trials += 1
			if f.rooms[k].get("dark", false):
				darks += 1
				eq(f.rooms[k].type, "combat", "only combat rooms are dark")
	check(trials > 10, "brazier chambers appear (%d)" % trials)
	check(darks > 10, "lightless rooms appear (%d)" % darks)


func test_generation_is_deterministic() -> void:
	for s in [1, 42, 99999, 123456789]:
		for depth in [1, 2, 3]:
			var a := JSON.stringify(_floor(s, depth))
			var b := JSON.stringify(_floor(s, depth))
			eq(a, b, "seed %d depth %d differs between runs" % [s, depth])
	check(JSON.stringify(_floor(1, 1)) != JSON.stringify(_floor(2, 1)), "different seeds give different floors")


func test_seed_text_is_stable() -> void:
	eq(RunRng.seed_from_text("abc"), RunRng.seed_from_text(" ABC "), "seed text is case/space insensitive")
	check(RunRng.random_seed_text().length() == 6, "random seed has 6 characters")
	eq(RunRng.derive(5, "x"), RunRng.derive(5, "x"), "derive is pure")


func test_wave_builder() -> void:
	for depth in [1, 2, 3]:
		for s in 40:
			var rng := RunRng.make(s, "w")
			var waves := WaveBuilder.build(rng, depth, s % 5 == 0, s % 6, ["std", "wide", "tall", "big"][s % 4], 0)
			check(not waves.is_empty(), "no waves")
			for w in waves:
				check(not (w as Array).is_empty(), "empty wave")
				for e in w:
					check(Database.enemies.has(e.id), "unknown enemy " + str(e.id))
			if s % 5 == 0:
				var elites := 0
				for e in waves[waves.size() - 1]:
					if e.get("elite", false):
						elites += 1
				eq(elites, 1, "elite rooms have exactly one elite")


func test_minimap_shows_every_neighbour_of_a_visited_room() -> void:
	for i in 40:
		var r := RunState.create("MINI%d" % i, "oil", 0)
		r.generate_floor()
		var start := r.current_room
		var info: Dictionary = r.floor.rooms[start]
		var p := Vector2i(info.pos[0], info.pos[1])
		for d in info.doors:
			var nk := DungeonGenerator.key(p + DungeonGenerator.DIRS[d])
			check(HUD.Minimap.room_known(r, nk, false), "neighbour %s of the start room is drawn (seed %d)" % [nk, i])
		for k in r.floor.rooms:
			var room: Dictionary = r.floor.rooms[k]
			if room.type == "secret":
				check(not HUD.Minimap.room_known(r, k, true), "unvisited secret room stays hidden even when revealed")
			elif k != start and not (info.doors as Array).any(func(d): return DungeonGenerator.key(p + DungeonGenerator.DIRS[d]) == k):
				check(not HUD.Minimap.room_known(r, k, false), "far room %s hidden before the map is revealed" % k)
				check(HUD.Minimap.room_known(r, k, true), "far room %s shown once revealed" % k)
