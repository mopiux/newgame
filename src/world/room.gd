class_name Room
extends Node2D
## A single room of a depth: background, collision, props, doors, enemy
## waves, room-type content (treasure, shop, event, boss, secret) and the
## flow field enemies use to walk around obstacles.

signal cleared(room: Room)
signal door_entered(dir: String)

const T := 16

var key := ""
var info: Dictionary = {}
var state: Dictionary = {}
var run: RunState
var depth := 1
var biome: Dictionary = {}
var layout: RoomLayout
var room_type := "combat"

var entities: Node2D
var doors: Dictionary = {}
var braziers: Array[Brazier] = []
var combat_active := false
var waves: Array = []
var _wave_delay := 0.0
var player: Player
var darkness: DarknessOverlay
var boss: Node = null

var _flow := PackedInt32Array()
var _flow_t := 0.0
var _flow_origin := Vector2i(-999, -999)
var _content: RoomContent


func build(run_state: RunState, room_key: String) -> void:
	run = run_state
	key = room_key
	depth = run.depth
	info = run.room_info(key)
	state = run.room_state(key)
	biome = Database.biome_for_depth(depth)
	room_type = str(info.get("type", "combat"))
	var rng := RunRng.make(int(info.get("seed", 0)), "layout")
	layout = RoomLayout.create(str(info.get("size", "std")), room_type, info.get("doors", []), info.get("secret_doors", []), rng)
	name = "Room_" + key.replace(",", "_").replace("-", "m")
	_build_background(rng)
	_build_collision()
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	_build_props(rng)
	_build_doors()
	darkness = DarknessOverlay.new()
	darkness.rect = Rect2(-T * 4, -T * 4, layout.width * T + T * 8, layout.height * T + T * 8)
	darkness.dark_color = Color(biome.get("dark_color", "#121024"))
	add_child(darkness)
	_content = RoomContent.new()
	_content.name = "Content"
	add_child(_content)
	_content.setup(self)


func pixel_size() -> Vector2:
	return Vector2(layout.width * T, layout.height * T)


func _build_background(rng: RandomNumberGenerator) -> void:
	var bg := Sprite2D.new()
	bg.name = "Background"
	bg.centered = false
	bg.texture = RoomArt.compose(layout, str(biome.get("tileset", "sewer")), rng)
	bg.z_as_relative = false
	bg.z_index = Layers.Z_FLOOR
	add_child(bg)


func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = Layers.WORLD
	add_child(body)
	# merge solid cells into horizontal runs, then stack identical runs
	var runs := {}
	for y in layout.height:
		var x := 0
		while x < layout.width:
			if _cell_blocks(x, y):
				var x0 := x
				while x < layout.width and _cell_blocks(x, y):
					x += 1
				var k := Vector2i(x0, x)
				if runs.has(k) and runs[k].y + runs[k].h == y:
					runs[k].h += 1
				else:
					if runs.has(k):
						_add_rect(body, runs[k])
					runs[k] = {"x0": x0, "x1": x, "y": y, "h": 1}
			else:
				x += 1
	for k in runs:
		_add_rect(body, runs[k])


func _cell_blocks(x: int, y: int) -> bool:
	# W and pillars are static walls; braziers/pots/secret walls have own bodies
	return layout.get_cell(x, y) in ["W", "#"]


func _add_rect(body: StaticBody2D, r: Dictionary) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2((r.x1 - r.x0) * T, r.h * T)
	shape.shape = rect
	shape.position = Vector2(r.x0 * T, r.y * T) + rect.size * 0.5
	body.add_child(shape)


func _build_props(rng: RandomNumberGenerator) -> void:
	var tileset := str(biome.get("tileset", "sewer"))
	for y in layout.height:
		for x in layout.width:
			if layout.get_cell(x, y) == "#":
				var s := Sprite2D.new()
				s.texture = SpriteLib.texture("pillar_" + tileset)
				s.centered = false
				s.offset = Vector2(0, -24)
				s.position = Vector2(x * T, (y + 1) * T)
				entities.add_child(s)
	var lit: Array = state.get("lit", [])
	var mimic_slot := -1
	if room_type in ["combat", "treasure", "elite"] and not state.get("mimic_dead", false):
		var chance := float(biome.get("mimic_chance", 0.0))
		if layout.braziers.size() >= 2 and rng.randf() < chance:
			mimic_slot = rng.randi_range(0, layout.braziers.size() - 1)
	for i in layout.braziers.size():
		var c: Vector2i = layout.braziers[i]
		var pos := Vector2(c.x * T + 8, c.y * T + 13)
		if i == mimic_slot:
			var m := EnemyFactory.create("mimic", depth) as Mimic
			m.position = pos
			m.room = self
			m.tree_exited.connect(func(): if is_instance_valid(self) and m.dead: state["mimic_dead"] = true)
			entities.add_child(m)
			continue
		var b := Brazier.new()
		b.index = i
		b.is_lit = lit.has(i) or room_type == "start"
		b.position = pos
		b.lit.connect(_on_brazier_lit)
		entities.add_child(b)
		braziers.append(b)
	var broken: Array = state.get("pots", [])
	for i in layout.pots.size():
		if broken.has(i):
			continue
		var c2: Vector2i = layout.pots[i]
		var pot := Pot.new()
		pot.index = i
		pot.sheet = "pot_" + str(biome.get("pot", "sewer"))
		pot.position = Vector2(c2.x * T + 8, c2.y * T + 13)
		pot.broken.connect(_on_pot_broken)
		entities.add_child(pot)


func _build_doors() -> void:
	for d in layout.doors:
		var cells: Array = layout.doors[d]
		var is_secret := (info.get("secret_doors", []) as Array).has(d)
		var neighbor_key := _neighbor_key(d)
		var ninfo := run.room_info(neighbor_key)
		var kind := str(ninfo.get("type", "normal"))
		if kind in ["combat", "start", "event"]:
			kind = "normal"
		if bool(ninfo.get("dark", false)):
			kind = "dark"
		if is_secret:
			var opened: Array = state.get("secret_open", [])
			var r := _cells_rect(cells)
			if not opened.has(d):
				var w := SecretWall.new()
				w.setup(d, r)
				w.revealed.connect(_on_secret_revealed)
				add_child(w)
			kind = "secret"
		var door := Door.new()
		door.setup(d, cells, kind)
		door.entered.connect(func(dir): door_entered.emit(dir))
		door.locked = false
		add_child(door)
		doors[d] = door


func _cells_rect(cells: Array) -> Rect2:
	var tmin := Vector2(INF, INF)
	var tmax := Vector2(-INF, -INF)
	for c in cells:
		tmin = tmin.min(Vector2(c) * T)
		tmax = tmax.max(Vector2(c) * T + Vector2(T, T))
	return Rect2(tmin, tmax - tmin)


func _neighbor_key(d: String) -> String:
	var p: Vector2i = DungeonGenerator.parse_key(key) + DungeonGenerator.DIRS[d]
	return DungeonGenerator.key(p)


func _on_secret_revealed(dir: String) -> void:
	var opened: Array = state.get("secret_open", [])
	if not opened.has(dir):
		opened.append(dir)
	state["secret_open"] = opened
	Events.toast.emit(tr("TOAST_SECRET"), UITheme.SPECTRAL)


func is_dark() -> bool:
	return bool(info.get("dark", false))


func _on_brazier_lit(b: Brazier) -> void:
	var lit: Array = state.get("lit", [])
	if not lit.has(b.index):
		lit.append(b.index)
	state["lit"] = lit
	_content.on_brazier_lit(b)
	if player and is_instance_valid(player):
		player.relic_fx.on_brazier_lit(b)
	if all_braziers_lit() and braziers.size() > 0 and state.get("cleared", false) and not state.get("lit_bonus", false):
		_grant_lit_bonus()


func all_braziers_lit() -> bool:
	for b in braziers:
		if not b.is_lit:
			return false
	return true


func _grant_lit_bonus() -> void:
	state["lit_bonus"] = true
	if room_type in ["combat", "elite"]:
		var center := braziers[braziers.size() - 1].global_position + Vector2(0, -16)
		drop_spark(center)
		drop_embers(center, 2)
		Events.toast.emit(tr("TOAST_ALL_LIT"), UITheme.FLAME)


func _on_pot_broken(pot: Pot) -> void:
	var broken: Array = state.get("pots", [])
	broken.append(pot.index)
	state["pots"] = broken
	var r := randf()
	if r < float(Database.balance_value("drops.pot_spark", 0.06)):
		drop_spark(pot.global_position)
	elif r < float(Database.balance_value("drops.pot_ember", 0.6)):
		drop_embers(pot.global_position, randi_range(1, 2))


# --- entering / combat ---------------------------------------------------------

func enter(p: Player, from_dir: String) -> void:
	player = p
	if p.get_parent():
		p.get_parent().remove_child(p)
	entities.add_child(p)
	var spawn := Vector2(layout.width * T * 0.5, layout.height * T * 0.55)
	if from_dir != "" and layout.door_spawn.has(from_dir):
		var s: Vector2 = layout.door_spawn[from_dir]
		spawn = s * T
	p.global_position = global_position + spawn
	p.velocity = Vector2.ZERO
	Lights.ambient = float(biome.get("ambient", 0.0))
	if is_dark():
		Lights.ambient -= 0.3
		if not state.get("cleared", false):
			Events.toast.emit(tr("TOAST_DARK_ROOM"), UITheme.CURSE)
	state["visited"] = true
	_content.on_enter()
	if room_type in ["combat", "elite"] and not state.get("cleared", false):
		_start_combat()
	elif room_type == "boss" and not state.get("cleared", false):
		_content.start_boss()
	elif state.has("pending_waves"):
		# a fight started by an event was interrupted (save & quit): resume it
		waves = (state.pending_waves as Array).duplicate(true)
		combat_active = true
		_wave_delay = 0.8
		_set_doors_locked(true)
	Events.room_entered.emit(self)


func _start_combat() -> void:
	var rng := RunRng.make(int(info.get("seed", 0)), "waves")
	waves = WaveBuilder.build(rng, depth, room_type == "elite", int(info.get("dist", 1)), str(info.get("size", "std")), run.ascension)
	combat_active = true
	_wave_delay = 0.6
	_set_doors_locked(true)


func on_ambush() -> void:
	# a mimic woke up: lock the room until it's dealt with
	combat_active = true
	_set_doors_locked(true)


func start_boss_fight(b: Node) -> void:
	boss = b
	combat_active = true
	_set_doors_locked(true)


func _set_doors_locked(v: bool) -> void:
	for d in doors:
		doors[d].set_locked(v)


func _physics_process(delta: float) -> void:
	_update_flow(delta)
	if not combat_active:
		return
	if _wave_delay > 0.0:
		_wave_delay -= delta
		if _wave_delay <= 0.0 and not waves.is_empty():
			_spawn_wave(waves.pop_front())
		return
	if alive_enemies() == 0:
		if not waves.is_empty():
			_wave_delay = 0.8
		elif boss == null or not is_instance_valid(boss) or boss.get("dead"):
			_on_cleared()


func alive_enemies() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.dead and e.room == self:
			n += 1
	return n


func _spawn_wave(wave: Array) -> void:
	var rng := RunRng.make(int(info.get("seed", 0)) + waves.size(), "spawn")
	for entry in wave:
		var e := EnemyFactory.create(str(entry.id), depth, bool(entry.get("elite", false)))
		if e is Mimic:
			(e as Mimic).dormant = false
		var stationary := str(Database.enemies.get(entry.id, {}).get("behavior", "")) in ["nest", "eye"]
		e.position = random_floor_point(rng, player.global_position - global_position if player else Vector2.ZERO, 80.0 if not stationary else 110.0, stationary)
		add_enemy(e)
	Audio.sfx("wave", -6.0, 0.0)


func add_enemy(e: Enemy) -> void:
	e.room = self
	entities.add_child(e)


func _on_cleared() -> void:
	combat_active = false
	_set_doors_locked(false)
	state.erase("pending_waves")
	if state.get("cleared", false):
		# re-cleared (e.g. a mimic woke up later): no second payout
		for p in get_tree().get_nodes_in_group("pickups"):
			p.magnet = true
		return
	state["cleared"] = true
	run.rooms_cleared += 1
	var center := player.global_position if player else global_position + pixel_size() * 0.5
	if room_type in ["combat", "elite"]:
		drop_embers(center + Vector2(0, -20), int(Database.balance_value("rooms.clear_embers", 2)) + (2 if room_type == "elite" else 0))
		if room_type == "elite":
			_content.spawn_elite_reward()
		if is_dark():
			drop_spark(center + Vector2(0, -24), 2)
		if all_braziers_lit() and braziers.size() > 0 and not state.get("lit_bonus", false):
			_grant_lit_bonus()
	for p in get_tree().get_nodes_in_group("pickups"):
		p.magnet = true
	Audio.sfx("room_clear", -2.0, 0.0)
	Events.room_cleared.emit(self)
	cleared.emit(self)


# --- drops / hazards ----------------------------------------------------------

func drop_embers(world_pos: Vector2, count: int, reach_bonus: float = 0.0) -> void:
	var val := float(Database.balance_value("drops.ember_value", 3.0))
	for i in count:
		var p := Pickup.ember(world_pos - global_position, val)
		p.reach_bonus = reach_bonus
		entities.add_child.call_deferred(p)


func drop_spark(world_pos: Vector2, value: int = 1) -> void:
	var p := Pickup.spark(world_pos - global_position, value)
	entities.add_child.call_deferred(p)


func add_wax(world_pos: Vector2, radius: float) -> void:
	var count := 0
	for c in entities.get_children():
		if c is WaxPuddle:
			count += 1
	if count > 24:
		return
	var w := WaxPuddle.new()
	w.radius = radius
	w.position = world_pos - global_position
	entities.add_child(w)


# --- navigation -----------------------------------------------------------

func _walkable(x: int, y: int) -> bool:
	return layout.get_cell(x, y) in [".", "D"]


func world_to_tile(world_pos: Vector2) -> Vector2i:
	var l := world_pos - global_position
	return Vector2i(int(floor(l.x / T)), int(floor(l.y / T)))


func _update_flow(delta: float) -> void:
	_flow_t -= delta
	if player == null or _flow_t > 0.0:
		return
	_flow_t = 0.2
	var origin := world_to_tile(player.global_position)
	if origin == _flow_origin and not _flow.is_empty():
		return
	_flow_origin = origin
	var w := layout.width
	var h := layout.height
	_flow.resize(w * h)
	_flow.fill(-1)
	if origin.x < 0 or origin.y < 0 or origin.x >= w or origin.y >= h:
		return
	var queue: Array[Vector2i] = [origin]
	_flow[origin.y * w + origin.x] = 0
	var head := 0
	while head < queue.size():
		var p := queue[head]
		head += 1
		var dist := _flow[p.y * w + p.x]
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + n
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h:
				continue
			if _flow[q.y * w + q.x] != -1 or not _walkable(q.x, q.y):
				continue
			_flow[q.y * w + q.x] = dist + 1
			queue.append(q)


func flow_dir(world_pos: Vector2) -> Vector2:
	if _flow.is_empty():
		return Vector2.ZERO
	var t := world_to_tile(world_pos)
	var w := layout.width
	if t.x < 0 or t.y < 0 or t.x >= w or t.y >= layout.height:
		return Vector2.ZERO
	var here := _flow[t.y * w + t.x]
	var best := Vector2i(-1, -1)
	var best_d := here if here >= 0 else 1 << 30
	for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = t + n
		if q.x < 0 or q.y < 0 or q.x >= w or q.y >= layout.height:
			continue
		var d := _flow[q.y * w + q.x]
		if d >= 0 and d < best_d:
			best_d = d
			best = q
	if best.x < 0:
		return Vector2.ZERO
	var target := global_position + Vector2(best.x * T + 8, best.y * T + 8)
	return (target - world_pos).normalized()


func has_line_of_sight(a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, Layers.WORLD)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func random_floor_point(rng: RandomNumberGenerator, avoid_local: Vector2, min_dist: float, avoid_edges: bool = false) -> Vector2:
	var r := layout.interior_rect()
	for i in 60:
		var x := rng.randi_range(r.position.x + (2 if avoid_edges else 0), r.end.x - 1 - (2 if avoid_edges else 0))
		var y := rng.randi_range(r.position.y + (1 if avoid_edges else 0), r.end.y - 1 - (1 if avoid_edges else 0))
		if layout.get_cell(x, y) != "." or layout._in_door_zone(x, y):
			continue
		var p := Vector2(x * T + 8, y * T + 12)
		if p.distance_to(avoid_local) >= min_dist:
			return p
	return Vector2(r.get_center()) * T


func random_point_near(world_center: Vector2, rmin: float, rmax: float) -> Vector2:
	for i in 30:
		var a := randf() * TAU
		var d := randf_range(rmin, rmax)
		var p := world_center + Vector2(cos(a), sin(a)) * d
		var t := world_to_tile(p)
		if layout.get_cell(t.x, t.y) == "." and not layout._in_door_zone(t.x, t.y):
			return p
	return world_center + Vector2(rmin, 0).rotated(randf() * TAU) * 0.5
