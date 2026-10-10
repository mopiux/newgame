class_name RelicPool
## Rolls relic offers from the unlocked pool, weighted by rarity, avoiding
## relics already owned (unless stackable) or offered earlier in the run.

const RARITY_WEIGHTS := {"common": 60.0, "rare": 28.0, "legendary": 7.0, "cursed": 10.0}
const PRICES := {"common": 14, "rare": 22, "legendary": 32, "cursed": 8}


static func roll(run: RunState, rng: RandomNumberGenerator, count: int, rarities: Array = [], exclude: Array = []) -> Array:
	var tiers := SaveManager.unlocked_relic_tiers()
	var pool := Database.relic_ids_for_pool(tiers)
	var candidates: Array = []
	var weights: Array = []
	for id in pool:
		var r: Dictionary = Database.relics[id]
		if exclude.has(id):
			continue
		if run.has_relic(id) and not r.get("stackable", false):
			continue
		if run.seen_relics_run.has(id) and not r.get("stackable", false):
			continue
		var rar := str(r.get("rarity", "common"))
		if not rarities.is_empty() and not rarities.has(rar):
			continue
		candidates.append(id)
		weights.append(RARITY_WEIGHTS.get(rar, 10.0))
	var out: Array = []
	for i in count:
		if candidates.is_empty():
			break
		var pick: String = RunRng.weighted_pick(rng, candidates, weights)
		var idx := candidates.find(pick)
		candidates.remove_at(idx)
		weights.remove_at(idx)
		out.append(pick)
	# never come back empty-handed: fall back to stackable basics
	while out.size() < count:
		var fallback: Array = ["braided_wick", "tallow", "lens"]
		var f: String = fallback[out.size() % fallback.size()]
		if Database.relics.has(f) and not out.has(f):
			out.append(f)
		else:
			break
	for id in out:
		if not run.seen_relics_run.has(id):
			run.seen_relics_run.append(id)
	return out


static func price(id: String) -> int:
	var r: Dictionary = Database.relics.get(id, {})
	return int(r.get("price", PRICES.get(str(r.get("rarity", "common")), 15)))
