class_name Slug
extends Enemy
## Wax slug: slow, tanky, leaves sticky wax that slows the lamplighter.
## Splits into two small slugs when it dies (once).

var small := false
var _trail_t := 0.0


func _on_ready() -> void:
	if small:
		sprite.play("crawl_small")
		hit_radius = 4.0
		body_height = 6.0


func _ai(delta: float) -> void:
	var dir := path_dir()
	# crawl in pulses that match the animation
	var pulse := 0.55 + 0.45 * absf(sin(ai_time * 4.0))
	velocity = dir * speed * pulse
	_trail_t -= delta
	if _trail_t <= 0.0 and room:
		_trail_t = 0.7 if not small else 1.2
		room.add_wax(global_position, 9.0 if not small else 6.0)


func _on_death(_info: Dictionary) -> void:
	if small or room == null:
		return
	for i in 2:
		var s := Slug.new()
		s.small = true
		s.setup("slug", room.depth, false)
		s.max_hp *= 0.35
		s.hp = s.max_hp
		s.embers = 1
		s.speed *= 1.35
		s.contact_damage *= 0.7
		s.spawning = 0.15
		s.position = global_position + Vector2(i * 10 - 5, 0)
		room.add_enemy(s)
