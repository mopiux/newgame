class_name WaveBuilder
## Turns a room's danger budget into enemy waves drawn from the depth's pool.


static func build(rng: RandomNumberGenerator, depth: int, elite: bool, dist: int, size: String, ascension: int) -> Array:
	var biome := Database.biome_for_depth(depth)
	var b: Dictionary = Database.balance_value("rooms", {})
	var budget := float(b.get("budget_base", 6.0)) + float(b.get("budget_per_depth", 3.0)) * (depth - 1)
	budget += float(b.get("budget_per_dist", 0.6)) * mini(dist, 6)
	budget *= float(b.get("size_mult", {}).get(size, 1.0))
	budget *= Game.ascension_mult("budget", ascension)
	if elite:
		budget *= float(b.get("elite_budget_mult", 1.4))
	var pool: Array = biome.get("enemies", ["moth"])
	var weights: Array = biome.get("weights", [])
	if weights.size() != pool.size():
		weights = []
		for i in pool.size():
			weights.append(1.0)
	var wave_count := 1
	if budget >= float(b.get("two_waves_at", 9.0)):
		wave_count = 2
	if budget >= float(b.get("three_waves_at", 17.0)):
		wave_count = 3
	var waves: Array = []
	var remaining := budget
	for w in wave_count:
		var share := remaining / float(wave_count - w)
		if w == 0 and wave_count > 1:
			share *= 1.15
		var wave: Array = []
		var spent := 0.0
		var stationary := 0
		var guard := 0
		while spent < share - 0.5 and guard < 40:
			guard += 1
			var id: String = RunRng.weighted_pick(rng, pool, weights)
			var e: Dictionary = Database.enemies.get(id, {})
			var cost := float(e.get("cost", 1.0))
			if cost > share - spent + 1.0:
				continue
			var beh := str(e.get("behavior", ""))
			if beh in ["nest", "eye"]:
				if stationary >= 1:
					continue
				stationary += 1
			wave.append({"id": id})
			spent += cost
		if wave.is_empty():
			wave.append({"id": pool[0]})
			spent += 1.0
		remaining -= spent
		waves.append(wave)
	if elite:
		# the strongest creature of the last wave becomes "Ardiente"
		var last: Array = waves[waves.size() - 1]
		var best := 0
		var best_cost := -1.0
		for i in last.size():
			var c := float(Database.enemies.get(last[i].id, {}).get("cost", 1.0))
			if c > best_cost:
				best_cost = c
				best = i
		last[best]["elite"] = true
	return waves
