class_name Boss
extends Enemy
## Guardian of a depth. Adds phases, a health bar, an intro and a dramatic
## death. Subclasses implement _choose_attack() / _attack_process().

signal defeated()

var phase := 1
var phase_thresholds: Array = [0.5]
var attack := ""
var attack_t := 0.0
var idle_t := 1.2
var display_name := ""
var _ember_acc := 0.0


func setup(enemy_id: String, depth: int, _is_elite: bool = false) -> void:
	super.setup(enemy_id, depth, false)
	embers = 0
	display_name = str(data.get("name", enemy_id))


func _ready() -> void:
	super._ready()
	add_to_group("bosses")
	spawning = 1.2
	Audio.music(str(data.get("music", "boss")))


func _ai(delta: float) -> void:
	if attack == "":
		idle_t -= delta
		_idle_move(delta)
		if idle_t <= 0.0:
			attack = _choose_attack()
			attack_t = 0.0
			_begin_attack(attack)
	else:
		attack_t += delta
		if _attack_process(attack, delta):
			attack = ""
			idle_t = _idle_time()


func _idle_time() -> float:
	return (1.3 if phase == 1 else 0.8) * float(Game.ascension_mult("boss_tempo"))


func _idle_move(_delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 200.0 * _delta)


func _choose_attack() -> String:
	return ""


func _begin_attack(_a: String) -> void:
	pass


## Returns true when the attack is over.
func _attack_process(_a: String, _delta: float) -> bool:
	return true


func _apply_damage(dmg: float, kind: String, info) -> void:
	super._apply_damage(dmg, kind, info)
	# guardians shed embers as they are wounded: accurate fire pays for itself
	_ember_acc += dmg
	var step := max_hp * float(data.get("ember_every", 0.04))
	while _ember_acc >= step and room and not dead:
		_ember_acc -= step
		room.drop_embers(global_position + Vector2(0, -body_height * 0.5), 1)
	Events.boss_health_changed.emit(clampf(hp / max_hp, 0.0, 1.0))
	var ratio := hp / max_hp
	while phase - 1 < phase_thresholds.size() and ratio <= float(phase_thresholds[phase - 1]) and not dead:
		phase += 1
		_on_phase(phase)


func _on_phase(_p: int) -> void:
	Fx.shake(6.0, 0.4)
	Audio.sfx("boss_phase", 0.0, 0.0)
	telegraph(0.6)


func die(info: Dictionary) -> void:
	if dead:
		return
	SaveManager.mark_seen("enemies", id)
	var defeated_list: Array = SaveManager.profile.bosses_defeated
	if not defeated_list.has(id):
		defeated_list.append(id)
	Fx.hit_stop(0.25)
	Fx.shake(10.0, 0.8)
	for i in 4:
		Fx.burst(get_parent(), global_position + Vector2(randf_range(-16, 16), randf_range(-24, 0)), "embers", 2.0)
	Audio.sfx("boss_die", 0.0, 0.0)
	# clear remaining minions and projectiles
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and e is Enemy and e.room == room:
			e.die({})
	for p in get_tree().get_nodes_in_group("enemy_shots"):
		p.deflect(null)
	super.die(info)
	Audio.music(str(room.biome.get("music", "")) if room else "")
	defeated.emit()


## Fires n orbs evenly around, rotated by offset.
func ring(n: int, spd: float, dmg: float, offset: float = 0.0, sheet: String = "orb") -> void:
	for i in n:
		shoot_at(Vector2.RIGHT.rotated(offset + TAU * i / n), spd, dmg, sheet)


func fan(dir: Vector2, n: int, spread: float, spd: float, dmg: float, sheet: String = "orb") -> void:
	for i in n:
		var off := (i - (n - 1) * 0.5) * spread
		shoot_at(dir.rotated(off), spd, dmg, sheet)


func arena_center() -> Vector2:
	if room:
		return room.global_position + Vector2(room.layout.interior_rect().get_center()) * Room.T
	return global_position
