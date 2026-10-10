class_name Nest
extends Enemy
## Moth nest: immobile, keeps hatching ash moths until destroyed.

var _spawn_t := 2.0
var _children: Array = []


func _ai(delta: float) -> void:
	velocity = Vector2.ZERO
	_spawn_t -= delta
	_children = _children.filter(func(c): return is_instance_valid(c) and not c.dead)
	if _spawn_t <= 0.0 and room:
		_spawn_t = float(data.get("spawn_interval", 4.0))
		if _children.size() < int(data.get("max_children", 3)):
			var m := Moth.new()
			m.setup("moth", room.depth, false)
			m.embers = 0   # nest-born moths don't feed the lamplighter
			m.spawning = 0.4
			m.position = global_position + Vector2(randf_range(-6, 6), -8)
			room.add_enemy(m)
			_children.append(m)
			Audio.sfx("nest_pulse", -8.0)
