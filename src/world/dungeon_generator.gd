class_name DungeonGenerator
## Builds the room graph of one depth. Pure data, deterministic per seed.
##
## Rules that make a layout valid (checked by tests/test_generation.gd):
## * every room is reachable from the start;
## * there is exactly one boss room, a dead end at distance >= 3;
## * treasure and shop rooms exist and are dead ends;
## * the secret room touches >= 2 rooms and never the start or the boss.

const DIRS := {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}
const OPPOSITE := {"n": "s", "s": "n", "e": "w", "w": "e"}
const LIMIT := 5


static func key(p: Vector2i) -> String:
	return "%d,%d" % [p.x, p.y]


static func parse_key(k: String) -> Vector2i:
	var parts := k.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))


static func generate(run_seed: int, depth: int, cfg: Dictionary) -> Dictionary:
	for attempt in 80:
		var rng := RunRng.make(run_seed, "floor-%d-%d" % [depth, attempt])
		var result := _try(rng, depth, cfg)
		if not result.is_empty():
			result["attempts"] = attempt + 1
			return result
	push_error("DungeonGenerator: no valid layout for seed %d depth %d" % [run_seed, depth])
	return {}


static func _neighbors(cells: Dictionary, p: Vector2i) -> Array:
	var out := []
	for d in DIRS:
		if cells.has(p + DIRS[d]):
			out.append(d)
	return out


static func _try(rng: RandomNumberGenerator, depth: int, cfg: Dictionary) -> Dictionary:
	var target := rng.randi_range(int(cfg.get("rooms_min", 9)), int(cfg.get("rooms_max", 12)))
	var cells := {Vector2i.ZERO: true}
	var order: Array[Vector2i] = [Vector2i.ZERO]
	var guard := 0
	while cells.size() < target and guard < 2000:
		guard += 1
		# bias towards recently added rooms to grow branches outward
		var idx := order.size() - 1 - mini(int(abs(rng.randfn(0.0, 3.0))), order.size() - 1)
		var from: Vector2i = order[idx]
		var dir: String = DIRS.keys()[rng.randi_range(0, 3)]
		var cand: Vector2i = from + DIRS[dir]
		if cells.has(cand) or abs(cand.x) > LIMIT or abs(cand.y) > LIMIT:
			continue
		if _neighbors(cells, cand).size() > 1:
			continue
		# avoid crowding the start room
		if cand.length_squared() == 1 and _neighbors(cells, Vector2i.ZERO).size() >= 3:
			continue
		cells[cand] = true
		order.append(cand)
	if cells.size() < target:
		return {}

	var dist := _distances(cells, Vector2i.ZERO)
	var dead_ends: Array[Vector2i] = []
	for p in cells:
		if p != Vector2i.ZERO and _neighbors(cells, p).size() == 1:
			dead_ends.append(p)
	if dead_ends.size() < 3:
		return {}
	dead_ends.sort_custom(func(a, b): return dist[a] > dist[b] or (dist[a] == dist[b] and key(a) < key(b)))
	var boss: Vector2i = dead_ends[0]
	if dist[boss] < 3:
		return {}

	var types := {}
	for p in cells:
		types[p] = "combat"
	types[Vector2i.ZERO] = "start"
	types[boss] = "boss"
	var rest := dead_ends.slice(1)
	RunRng.shuffle(rng, rest)
	types[rest[0]] = "treasure"
	types[rest[1]] = "shop"
	# the second special is a brazier trial or an echo chamber (light puzzle)
	var specials := ["event", "trial" if rng.randf() < 0.5 else "echo", "elite", "event"]
	for i in range(2, rest.size()):
		types[rest[i]] = specials[(i - 2) % specials.size()]
	# an extra event somewhere along the main path on larger floors
	var path_rooms: Array = []
	for p in cells:
		if types[p] == "combat" and dist[p] >= 2:
			path_rooms.append(p)
	path_rooms.sort_custom(func(a, b): return key(a) < key(b))
	if path_rooms.size() >= 5 and rng.randf() < float(cfg.get("extra_event_chance", 0.6)):
		types[path_rooms[rng.randi_range(0, path_rooms.size() - 1)]] = "event"
	# the start room is never adjacent to an elite room
	for d in DIRS:
		var n: Vector2i = Vector2i.ZERO + DIRS[d]
		if types.get(n, "") == "elite":
			types[n] = "combat"

	# secret room: empty cell touching >= 2 rooms (prefer more), not start/boss
	var secret := Vector2i(999, 999)
	var best_score := -1
	for p in cells:
		for d in DIRS:
			var c: Vector2i = p + DIRS[d]
			if cells.has(c) or abs(c.x) > LIMIT + 1 or abs(c.y) > LIMIT + 1:
				continue
			var ns := _neighbors(cells, c)
			var bad := false
			for nd in ns:
				var t: String = types[c + DIRS[nd]]
				if t == "boss" or t == "start":
					bad = true
			if bad or ns.size() < 2:
				continue
			var score := ns.size() * 100 + rng.randi_range(0, 50)
			if score > best_score:
				best_score = score
				secret = c

	var sizes: Dictionary = cfg.get("combat_sizes", {"std": 5, "wide": 2, "tall": 2, "big": 2})
	var rooms := {}
	for p in cells:
		var t: String = types[p]
		var size := "std"
		if t == "boss":
			size = "boss"
		elif t == "combat" or t == "elite":
			size = RunRng.weighted_pick(rng, sizes.keys(), sizes.values())
		var doors: Array = _neighbors(cells, p)
		# some combat rooms swallow light: less radius, guaranteed spark
		var dark: bool = t == "combat" and int(dist[p]) >= 2 and rng.randf() < float(cfg.get("dark_chance", 0.15))
		rooms[key(p)] = {
			"pos": [p.x, p.y], "type": t, "size": size,
			"doors": doors, "secret_doors": [],
			"dist": dist[p], "seed": rng.randi(), "dark": dark,
		}
	if best_score >= 0:
		var sd := []
		for d in DIRS:
			var n: Vector2i = secret + DIRS[d]
			if cells.has(n):
				sd.append(d)
				rooms[key(n)].secret_doors.append(OPPOSITE[d])
		rooms[key(secret)] = {
			"pos": [secret.x, secret.y], "type": "secret", "size": "std",
			"doors": sd, "secret_doors": [], "dist": 99, "seed": rng.randi(),
		}
	return {"rooms": rooms, "start": key(Vector2i.ZERO), "boss": key(boss), "secret": key(secret) if best_score >= 0 else ""}


static func _distances(cells: Dictionary, from: Vector2i) -> Dictionary:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for d in DIRS:
			var n: Vector2i = p + DIRS[d]
			if cells.has(n) and not dist.has(n):
				dist[n] = dist[p] + 1
				queue.append(n)
	return dist
