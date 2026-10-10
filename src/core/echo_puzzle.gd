class_name EchoPuzzle
## Rules of the «Cámara de los ecos»: braziers stand on a ring and stoking
## one toggles it and its two neighbours. With five braziers every state has
## exactly one solution (the toggle matrix of a 5-cycle is invertible over
## GF(2)), so the room can never be left unsolvable.

const SIZE := 5


static func press(state: Array, i: int) -> Array:
	var out := state.duplicate()
	for j in [i - 1, i, i + 1]:
		var k := posmod(j, out.size())
		out[k] = 1 - int(out[k])
	return out


static func solved(state: Array) -> bool:
	for v in state:
		if int(v) == 0:
			return false
	return true


## Scrambles the solved ring with 2-3 distinct presses: always solvable, in
## at most that many moves, and never already solved.
static func scramble(rng: RandomNumberGenerator) -> Array:
	var state := []
	for i in SIZE:
		state.append(1)
	var order := range(SIZE)
	RunRng.shuffle(rng, order)
	for i in rng.randi_range(2, 3):
		state = press(state, order[i])
	return state


## Braziers to stoke to light the whole ring (fewest moves). Empty when the
## state is already solved; null if no solution exists.
static func solve(state: Array) -> Variant:
	var n := state.size()
	var best: Variant = null
	for mask in 1 << n:
		var s := state.duplicate()
		var picks := []
		for i in n:
			if mask & (1 << i):
				s = press(s, i)
				picks.append(i)
		if solved(s) and (best == null or picks.size() < (best as Array).size()):
			best = picks
	return best
