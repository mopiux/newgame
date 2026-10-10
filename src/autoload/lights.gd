extends Node
## Registry of LightEmitters. The darkness shader and gameplay queries
## (is this shade visible? is this enemy standing in brazier light?) use the
## same falloff so what the player sees is what the game computes.

var emitters: Array[LightEmitter] = []
var ambient: float = 0.0
var max_lights: int = 48


func register(e: LightEmitter) -> void:
	if not emitters.has(e):
		emitters.append(e)


func unregister(e: LightEmitter) -> void:
	emitters.erase(e)


static func falloff(dist: float, radius: float) -> float:
	if radius <= 0.0:
		return 0.0
	var a := clampf(1.0 - dist / radius, 0.0, 1.0)
	return a * a * (3.0 - 2.0 * a)


## Total light at a world position (0 = dark, ~1 = fully lit).
func light_at(pos: Vector2, include_negative: bool = true) -> float:
	var total := ambient
	for e in emitters:
		if not e.enabled or e.current_radius <= 0.0:
			continue
		if e.energy < 0.0 and not include_negative:
			continue
		total += falloff(pos.distance_to(e.global_position), e.current_radius) * e.current_energy
	return clampf(total, 0.0, 1.5)


## Light only from braziers and other "static" sources (used for the
## brazier-light damage bonus and the mothers' attraction).
func static_light_at(pos: Vector2) -> float:
	var total := 0.0
	for e in emitters:
		if e.enabled and e.is_static:
			total += falloff(pos.distance_to(e.global_position), e.current_radius) * e.current_energy
	return total


## Returns the strongest positive static light source near pos (or null).
func brightest_static_near(pos: Vector2, max_dist: float) -> LightEmitter:
	var best: LightEmitter = null
	var best_d := max_dist
	for e in emitters:
		if e.enabled and e.is_static and e.energy > 0.0:
			var d := pos.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
	return best


## Emitters affecting the given view rect, most important first.
func collect(view: Rect2, limit: int) -> Array[LightEmitter]:
	var out: Array[LightEmitter] = []
	var center := view.get_center()
	for e in emitters:
		if not e.enabled or e.current_radius <= 0.0:
			continue
		var r := e.current_radius
		var p := e.global_position
		if p.x + r < view.position.x or p.x - r > view.end.x or p.y + r < view.position.y or p.y - r > view.end.y:
			continue
		out.append(e)
	if out.size() > limit:
		out.sort_custom(func(a: LightEmitter, b: LightEmitter) -> bool:
			if a.priority != b.priority:
				return a.priority > b.priority
			return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
		out.resize(limit)
	return out
