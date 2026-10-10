class_name Autopilot
extends Node
## Plays the game for automated tests (run with `-- --bot`). It fights,
## dodges, lights braziers, collects loot, explores the floor graph room by
## room, answers events and descends. It is not meant to be smart, only to
## exercise every system so crashes, soft-locks and balance outliers show up.
##
## Flags: --bot            enable autopilot
##        --bot-runs N     number of expeditions before quitting (default 1)
##        --bot-timeout S  abort a run after S seconds of game time (default 900)

var runs_left := 1
var run_timeout := 900.0
var results: Array = []

var _player: Player
var _goal_tile := Vector2i(-1, -1)
var _goal_dist := PackedInt32Array()
var _goal_room := ""
var _last_pos := Vector2.ZERO
var _stuck_t := 0.0
var _jiggle_t := 0.0
var _jiggle := Vector2.ZERO
var _strafe := 1.0
var _run_t := 0.0
var _room_t := 0.0
var _room_key := ""
var _ending := false
var _log_t := 0.0
var _last_move := Vector2.ZERO
var _target: Node = null
var _target_t := 0.0
var _given_up: Array = []


var shots_dir := ""
var _shot_queue: Array = []
var _shot_n := 0
var _shot_timer := 0.0
var _damage_by := {}
var _boss_t0 := {}
var _spent := {"shots": 0.0, "braziers": 0}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.player_damaged.connect(func(amount: float, source: Node):
		var k := "?"
		if is_instance_valid(source) and source is Enemy:
			k = (source as Enemy).id
		elif is_instance_valid(source) and source is Projectile:
			k = "shot"
		_damage_by[k] = float(_damage_by.get(k, 0.0)) + amount)
	Events.boss_started.connect(func(b: Node): _boss_t0[str(b.get("id"))] = _run_t)
	Events.boss_defeated.connect(func(b: Node):
		var id := str(b.get("id"))
		print("BOT_BOSS %s defeated in %.0fs flame=%.0f" % [id, _run_t - float(_boss_t0.get(id, _run_t)), Game.run.flame if Game.run else 0.0]))
	var args := OS.get_cmdline_user_args()
	var i := args.find("--bot-runs")
	if i >= 0 and i + 1 < args.size():
		runs_left = maxi(1, int(args[i + 1]))
	i = args.find("--bot-timeout")
	if i >= 0 and i + 1 < args.size():
		run_timeout = float(args[i + 1])
	if args.has("--perf-mode"):
		Settings.data.video.performance_mode = true
	if args.has("--no-fx"):
		Fx.disabled = true
	i = args.find("--shots")
	if i >= 0 and i + 1 < args.size():
		shots_dir = args[i + 1]
		DirAccess.make_dir_recursive_absolute(shots_dir)
	Events.room_entered.connect(func(r: Node):
		_shot_queue.append({"t": 2.5, "tag": "room_%s" % str(r.get("room_type"))}))
	Events.boss_started.connect(func(_b: Node):
		_shot_queue.append({"t": 3.0, "tag": "boss_a"})
		_shot_queue.append({"t": 12.0, "tag": "boss_b"}))


func _process(delta: float) -> void:
	_screenshots(delta)
	if not get_tree().paused:
		_sample_perf(delta)
	var level: Level = Game.level
	if level == null:
		if Game.main and Game.run == null and not _ending and runs_left > 0 and get_tree().current_scene != null:
			# in the plaza or menu: start the next expedition
			_start_next()
		return
	if level.player and level.player.bot != self:
		level.player.bot = self
		_player = level.player
		_run_t = 0.0
	if level._overlay is EventDialog:
		var d := level._overlay as EventDialog
		if not d._resolved:
			var e: Dictionary = Database.events.get(d.event_id, {})
			var opts: Array = e.get("options", [])
			for opt in opts:
				if EventSystem.can_choose(opt, level.run):
					d._choose(opt)
					break
		else:
			level.close_overlay()
		return
	if level._ended and not _ending:
		_ending = true
		var tw := create_tween()
		tw.tween_interval(1.0)
		tw.tween_callback(_after_run)
		return
	if not get_tree().paused:
		_log_t -= delta
		if _log_t <= 0.0 and Game.run and level.room and _player:
			_log_t = 20.0
			print("BOT_STATUS t=%.0f depth=%d room=%s type=%s cleared=%s enemies=%d flame=%.0f pos=%s focus=%s state=%d move=%s door=%s combat=%s" % [
				_run_t, Game.run.depth, level.room.key, level.room.room_type, str(level.room.state.get("cleared", false)),
				_enemies(level.room).size(), Game.run.flame, str((_player.global_position - level.room.global_position).round()),
				str(_player.focus_interactable), _player.state, str(_last_move), _next_door(level.room), str(level.room.combat_active)])
		_run_t += delta
		if _run_t > run_timeout and Game.run:
			print("BOT_TIMEOUT room=%s depth=%d" % [Game.run.current_room, Game.run.depth])
			Game.finish_run(false)


var _perf_t := 0.0
var _last_frame_us := 0
var _bot_us := 0
var _frame_samples: Array[float] = []
var _fps_samples: Array[float] = []
var _perf := {"frames": 0, "proc_sum": 0.0, "phys_sum": 0.0, "proc_max": 0.0, "phys_max": 0.0, "nodes_max": 0, "shots_max": 0, "enemies_max": 0}


## Game cost per frame = wall time between frames (engine runs flat out with
## --fixed-fps) minus the time the autopilot itself spent deciding.
func _sample_perf(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_frame_us > 0:
		var ms := (now - _last_frame_us - _bot_us) / 1000.0
		_frame_samples.append(ms)
		_perf.frames += 1
		_perf.proc_sum += ms
		_perf.proc_max = maxf(_perf.proc_max, ms)
	_last_frame_us = now
	_bot_us = 0
	_perf_t += _delta
	if _perf_t < 0.25:
		return
	_perf_t = 0.0
	_fps_samples.append(Engine.get_frames_per_second())
	_perf.nodes_max = maxi(_perf.nodes_max, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	_perf.shots_max = maxi(_perf.shots_max, get_tree().get_nodes_in_group("enemy_shots").size() + get_tree().get_nodes_in_group("player_shots").size())
	_perf.enemies_max = maxi(_perf.enemies_max, get_tree().get_nodes_in_group("enemies").size())


func perf_report() -> String:
	var n := maxi(1, int(_perf.frames))
	var sorted := _frame_samples.duplicate()
	sorted.sort()
	var p99: float = sorted[int(sorted.size() * 0.99)] if not sorted.is_empty() else 0.0
	var p50: float = sorted[int(sorted.size() * 0.5)] if not sorted.is_empty() else 0.0
	var fps_avg := 0.0
	var fps_min := 9999.0
	for f in _fps_samples.slice(8):
		fps_avg += f
		fps_min = minf(fps_min, f)
	fps_avg /= maxf(1.0, _fps_samples.size() - 8)
	return "BOT_PERF fps_avg=%.1f fps_min=%.0f frames=%d frame_avg=%.2fms p50=%.2fms p99=%.2fms max=%.2fms nodes_max=%d projectiles_max=%d enemies_max=%d" % [
		fps_avg, fps_min, n, _perf.proc_sum / n, p50, p99, _perf.proc_max, _perf.nodes_max, _perf.shots_max, _perf.enemies_max]


func _screenshots(delta: float) -> void:
	if shots_dir == "" or DisplayServer.get_name() == "headless":
		return
	_shot_timer += delta
	if _shot_timer > 15.0:
		_shot_timer = 0.0
		_shot_queue.append({"t": 0.0, "tag": "periodic"})
	for q in _shot_queue:
		q.t -= delta
	var ready := _shot_queue.filter(func(q): return q.t <= 0.0)
	_shot_queue = _shot_queue.filter(func(q): return q.t > 0.0)
	for q in ready:
		_shot_n += 1
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%03d_%s.png" % [shots_dir, _shot_n, q.tag])


func _start_next() -> void:
	_ending = true
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		_ending = false
		Game.new_run("oil", "BOT%d" % (randi() % 100000), 0))


func _after_run() -> void:
	runs_left -= 1
	if runs_left <= 0:
		print(perf_report())
		print("BOT_DONE runs=%d" % results.size())
		get_tree().quit(0)
		return
	_ending = false
	get_tree().paused = false
	Game.goto_hub()


func record(summary: Dictionary) -> void:
	results.append(summary)
	var parts := []
	for k in _damage_by:
		parts.append("%s=%.0f" % [k, _damage_by[k]])
	print("BOT_DAMAGE " + " ".join(parts))
	_damage_by.clear()
	print("BOT_RESULT victory=%s depth=%d time=%.0f kills=%d rooms=%d sparks=%d relics=%d seed=%s" % [
		str(summary.victory), summary.depth, summary.time, summary.kills, summary.rooms,
		summary.sparks, (summary.relics as Array).size(), summary.seed])


# --- control ---------------------------------------------------------------------

func get_input(p: Player) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var res := _decide(p)
	_bot_us += Time.get_ticks_usec() - t0
	return res


func _decide(p: Player) -> Dictionary:
	var out := {"move": Vector2.ZERO, "shoot": false, "melee": false, "dash": false, "flare": false, "interact": false}
	var level: Level = Game.level
	if level == null or level.room == null:
		return out
	var room := level.room
	if room.key != _room_key:
		_room_key = room.key
		_room_t = 0.0
		_goal_tile = Vector2i(-1, -1)
		_given_up.clear()
	_room_t += get_physics_process_delta_time()
	var enemies := _enemies(room)
	var flame_ratio := p.flame_ratio()
	if not enemies.is_empty():
		var e: Enemy = _nearest(p.global_position, enemies)
		var to := e.global_position + Vector2(0, -4) - p.global_position
		var d := to.length()
		p.aim_dir = to.normalized()
		var los := room.has_line_of_sight(p.global_position + Vector2(0, -6), e.global_position + Vector2(0, -4))
		out.shoot = los and p.run.flame > p.stats.get_stat("shot_cost") + 6.0
		# a guardian that shrugs off bolts: light braziers instead of wasting flame
		var boss := _boss(enemies)
		if boss and boss._damage_taken_mult({}) < 0.5:
			out.shoot = false
			var unlit := _nearest_unlit_brazier(room, p.global_position)
			if unlit and p.run.flame > 16.0:
				if p.focus_interactable == unlit:
					out.interact = true
				out.move = _path_to(room, unlit.global_position + Vector2(0, 8))
				out.move = _unstick(p, out.move)
				_last_move = out.move
				return out
		if d < 34.0:
			out.melee = true
		var move := Vector2.ZERO
		if d > 125.0 or not los:
			move = _path_to(room, e.global_position)
		elif d < 60.0:
			move = -to.normalized()
		if randf() < 0.01:
			_strafe = -_strafe
		move += Vector2(-to.y, to.x).normalized() * _strafe * 0.8
		# dodge incoming orbs
		for s in p.get_tree().get_nodes_in_group("enemy_shots"):
			var rel: Vector2 = p.global_position - s.global_position
			if rel.length() < 34.0 and (s as Projectile).velocity.dot(rel) > 0.0:
				if rel.length() < 22.0:
					out.melee = true
					p.aim_dir = -rel.normalized()
				else:
					out.dash = true
					move = Vector2(-rel.y, rel.x).normalized()
				break
		# low on flame: grab nearby embers like a person would
		if flame_ratio < 0.5:
			var best_e: Node2D = null
			var best_d := 90.0
			for k in p.get_tree().get_nodes_in_group("pickups"):
				var dd: float = k.global_position.distance_to(p.global_position)
				if dd < best_d and room.is_ancestor_of(k):
					best_d = dd
					best_e = k
			if best_e and d > 40.0:
				move = (best_e.global_position - p.global_position).normalized() + move * 0.3
		var close := 0
		for o in enemies:
			if o.global_position.distance_to(p.global_position) < 85.0:
				close += 1
		if close >= 3 and flame_ratio > 0.4:
			out.flare = true
		out.move = move.normalized()
	else:
		out.move = _explore(p, room)
		if p.focus_interactable and _wants(p.focus_interactable):
			out.interact = true
	# lighting braziers in combat when safe and rich in flame
	if p.focus_interactable is Brazier and flame_ratio > 0.55:
		out.interact = true
	out.move = _unstick(p, out.move)
	_last_move = out.move
	return out


func _boss(enemies: Array) -> Boss:
	for e in enemies:
		if e is Boss:
			return e
	return null


func _nearest_unlit_brazier(room: Room, pos: Vector2) -> Brazier:
	var best: Brazier = null
	var bd := INF
	for b in room.braziers:
		if not b.is_lit and b.global_position.distance_to(pos) < bd:
			bd = b.global_position.distance_to(pos)
			best = b
	return best


func _wants(n: Node) -> bool:
	if n is Brazier:
		var r: Room = Game.level.room if Game.level else null
		if r and r.room_type == "trial":
			return _player.run.flame > 50.0
		return _player.flame_ratio() > 0.45
	if n is Interactables.RelicPedestal:
		var ped := n as Interactables.RelicPedestal
		return ped.price_flame == 0 or _player.run.flame > ped.price_flame + 40
	if n is Interactables.ShopGood:
		return _player.run.sparks >= (n as Interactables.ShopGood).price_sparks + 4
	if n is Interactables.EventAltar or n is Interactables.Hatch:
		return true
	return false


func _enemies(room: Room) -> Array:
	var out := []
	for e in room.get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.room == room and e.is_hittable():
			out.append(e)
	return out


func _nearest(pos: Vector2, list: Array) -> Node2D:
	var best: Node2D = null
	var bd := INF
	for n in list:
		var d: float = pos.distance_to(n.global_position)
		if d < bd:
			bd = d
			best = n
	return best


func _explore(p: Player, room: Room) -> Vector2:
	# 1) loot on the floor
	var picks := []
	for k in p.get_tree().get_nodes_in_group("pickups"):
		if k.get_parent() and room.is_ancestor_of(k):
			picks.append(k)
	if not picks.is_empty() and _room_t < 20.0:
		return _path_to(room, _nearest(p.global_position, picks).global_position)
	# 2) wanted interactables in this room
	var wanted := []
	for n in p.get_tree().get_nodes_in_group("interactables"):
		if room.is_ancestor_of(n) and n.can_interact(p) and _wants(n):
			if n is Interactables.Hatch and not _floor_done(room):
				continue
			wanted.append(n)
	wanted = wanted.filter(func(n): return not _given_up.has(n))
	if not wanted.is_empty():
		var t: Node2D = _nearest(p.global_position, wanted)
		if t != _target:
			_target = t
			_target_t = 0.0
		_target_t += get_physics_process_delta_time()
		if _target_t > 12.0:
			_given_up.append(t)
		return _path_to(room, t.global_position + Vector2(0, 6))
	# 3) secret walls: shoot them when known
	for w in p.get_tree().get_nodes_in_group("secret_walls"):
		if room.is_ancestor_of(w) and not w.is_open:
			p.aim_dir = (w.rect.get_center() + room.global_position - p.global_position).normalized()
	# 4) next room
	var dir := _next_door(room)
	if dir == "":
		return Vector2.ZERO
	if not room.layout.door_spawn.has(dir):
		print("BOT_DEBUG missing door %s in %s type=%s doors=%s spawns=%s" % [dir, room.key, room.room_type, str(room.info.get("doors")), str(room.layout.door_spawn.keys())])
		return Vector2.ZERO
	var spawn: Vector2 = room.layout.door_spawn[dir] * Room.T
	var outward: Vector2 = DungeonGenerator.DIRS[dir]
	return _path_to(room, room.global_position + spawn + Vector2(outward) * 40.0)


func _floor_done(_room: Room) -> bool:
	return true


func _next_door(room: Room) -> String:
	var run := room.run
	var start := DungeonGenerator.parse_key(room.key)
	var rooms: Dictionary = run.floor.rooms
	# BFS over open connections, looking for the closest unvisited room;
	# the boss room is only chosen when nothing else is left
	var prev := {start: null}
	var queue: Array[Vector2i] = [start]
	var found := Vector2i(999, 999)
	var boss := Vector2i(999, 999)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		var k := DungeonGenerator.key(c)
		var info: Dictionary = rooms.get(k, {})
		var st: Dictionary = run.rooms.get(k, {})
		if c != start and not st.get("visited", false):
			if info.get("type", "") == "boss":
				if boss.x == 999:
					boss = c
			else:
				found = c
				break
		for d in info.get("doors", []):
			if (info.get("secret_doors", []) as Array).has(d) and not run.rooms.get(k, {}).get("secret_open", []).has(d):
				continue
			var n: Vector2i = c + DungeonGenerator.DIRS[d]
			if not prev.has(n) and rooms.has(DungeonGenerator.key(n)):
				prev[n] = c
				queue.append(n)
	if found.x == 999:
		found = boss
	if found.x == 999:
		# everything visited: go back to the boss room (hatch)
		found = DungeonGenerator.parse_key(run.floor.boss)
		if found == start or not prev.has(found):
			return ""
	var step := found
	while prev.get(step) != null and prev[step] != start:
		step = prev[step]
	var delta := step - start
	for d in DungeonGenerator.DIRS:
		if DungeonGenerator.DIRS[d] == delta:
			return d
	return ""


func _path_to(room: Room, world_target: Vector2) -> Vector2:
	var p := _player
	var target_tile := room.world_to_tile(world_target)
	target_tile.x = clampi(target_tile.x, 0, room.layout.width - 1)
	target_tile.y = clampi(target_tile.y, 0, room.layout.height - 1)
	if room.has_line_of_sight(p.global_position, world_target):
		return (world_target - p.global_position).normalized()
	if target_tile != _goal_tile or _goal_room != room.key:
		_goal_tile = target_tile
		_goal_room = room.key
		_goal_dist = _bfs(room, target_tile)
	var t := room.world_to_tile(p.global_position)
	var w := room.layout.width
	var best := Vector2i(-1, -1)
	var here := _goal_dist[t.y * w + t.x] if t.x >= 0 and t.y >= 0 and t.x < w and t.y < room.layout.height else -1
	var best_d := here if here >= 0 else 1 << 30
	for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q: Vector2i = t + n
		if q.x < 0 or q.y < 0 or q.x >= w or q.y >= room.layout.height:
			continue
		var dd := _goal_dist[q.y * w + q.x]
		if dd >= 0 and dd < best_d:
			best_d = dd
			best = q
	if best.x < 0:
		return (world_target - p.global_position).normalized()
	return (room.global_position + Vector2(best.x * 16 + 8, best.y * 16 + 10) - p.global_position).normalized()


func _bfs(room: Room, from: Vector2i) -> PackedInt32Array:
	var w := room.layout.width
	var h := room.layout.height
	var dist := PackedInt32Array()
	dist.resize(w * h)
	dist.fill(-1)
	if from.x < 0 or from.y < 0 or from.x >= w or from.y >= h:
		return dist
	dist[from.y * w + from.x] = 0
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + n
			if q.x < 0 or q.y < 0 or q.x >= w or q.y >= h or dist[q.y * w + q.x] != -1:
				continue
			if room.layout.get_cell(q.x, q.y) in [".", "D"]:
				dist[q.y * w + q.x] = dist[c.y * w + c.x] + 1
				queue.append(q)
	return dist


func _unstick(p: Player, move: Vector2) -> Vector2:
	var dt := get_physics_process_delta_time()
	if _jiggle_t > 0.0:
		_jiggle_t -= dt
		return _jiggle
	if move.length() > 0.1 and p.global_position.distance_to(_last_pos) < 0.3:
		_stuck_t += dt
	else:
		_stuck_t = 0.0
	_last_pos = p.global_position
	if _stuck_t > 0.8:
		_stuck_t = 0.0
		_jiggle_t = 0.4
		_jiggle = move.rotated(randf_range(PI * 0.4, PI * 0.6) * (1.0 if randf() < 0.5 else -1.0))
		_goal_tile = Vector2i(-1, -1)
		return _jiggle
	return move
