class_name RunRng
## Deterministic seed derivation. Every random decision of a run is drawn
## from a generator derived from (run seed, purpose tag), so a seed always
## produces the same floors, rooms and loot regardless of play order.


static func derive(run_seed: int, tag: String) -> int:
	var h := ("%d|%s" % [run_seed, tag]).hash()
	return h & 0x7fffffff


static func make(run_seed: int, tag: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = derive(run_seed, tag)
	return rng


## Seeds shown to players are short words-ish codes (A-Z, 2-9).
const SEED_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"


static func random_seed_text() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var s := ""
	for i in 6:
		s += SEED_ALPHABET[rng.randi_range(0, SEED_ALPHABET.length() - 1)]
	return s


static func seed_from_text(text: String) -> int:
	var clean := text.strip_edges().to_upper()
	if clean == "":
		clean = random_seed_text()
	return clean.hash() & 0x7fffffff


static func weighted_pick(rng: RandomNumberGenerator, items: Array, weights: Array) -> Variant:
	var total := 0.0
	for w in weights:
		total += float(w)
	if items.is_empty() or total <= 0.0:
		return null
	var r := rng.randf() * total
	for i in items.size():
		r -= float(weights[i])
		if r <= 0.0:
			return items[i]
	return items[items.size() - 1]


static func shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = arr[i]
		arr[i] = arr[j]
		arr[j] = t
