class_name RoomLayout
## Generates the tile grid of a single room (walls, doors, obstacles, props).
##
## Grid chars: 'W' wall, '.' floor, '#' pillar, 'B' brazier, 'p' pot,
##             'D' door cell (floor in an opening), 'S' secret wall (breakable).
## Row 0 is the wall cap, row 1 the visible wall face, last row the bottom wall.
## Every layout is validated with a flood fill: all doors, braziers and
## at least 85% of free floor must be connected.

const SIZES := {
	"std": Vector2i(26, 14),
	"wide": Vector2i(36, 14),
	"tall": Vector2i(26, 18),
	"big": Vector2i(36, 18),
	"boss": Vector2i(32, 18),
}
const STYLES := ["open", "pillars4", "grid", "center", "scatter", "lanes", "ring", "corners"]

var width: int
var height: int
var cells: Array = []        # Array[PackedByteArray]? kept as Array of Strings for clarity
var doors: Dictionary = {}   # dir -> Array[Vector2i] door cells
var door_spawn: Dictionary = {}  # dir -> Vector2 (tile coords where the player appears)
var braziers: Array[Vector2i] = []
var pots: Array[Vector2i] = []
var style: String = "open"


static func create(size_id: String, room_type: String, door_dirs: Array, secret_dirs: Array, rng: RandomNumberGenerator) -> RoomLayout:
	for attempt in 30:
		var l := RoomLayout.new()
		l._build(size_id, room_type, door_dirs, secret_dirs, rng, attempt)
		if l.validate():
			return l
	# guaranteed-valid fallback: no obstacles
	var safe := RoomLayout.new()
	safe._build(size_id, "plain", door_dirs, secret_dirs, rng, 99)
	return safe


func get_cell(x: int, y: int) -> String:
	if y < 0 or y >= height or x < 0 or x >= width:
		return "W"
	return cells[y][x]


func set_cell(x: int, y: int, c: String) -> void:
	if y < 0 or y >= height or x < 0 or x >= width:
		return
	var row: String = cells[y]
	cells[y] = row.substr(0, x) + c + row.substr(x + 1)


func is_floor(x: int, y: int) -> bool:
	return get_cell(x, y) in [".", "D"]


func is_solid(x: int, y: int) -> bool:
	return get_cell(x, y) in ["W", "#", "B", "S"]


func interior_rect() -> Rect2i:
	return Rect2i(1, 2, width - 2, height - 3)


func _build(size_id: String, room_type: String, door_dirs: Array, secret_dirs: Array, rng: RandomNumberGenerator, attempt: int) -> void:
	var inner: Vector2i = SIZES.get(size_id, SIZES.std)
	width = inner.x + 2
	height = inner.y + 3
	cells.clear()
	for y in height:
		var row := ""
		for x in width:
			var wall := x == 0 or x == width - 1 or y <= 1 or y == height - 1
			row += "W" if wall else "."
		cells.append(row)
	_cut_doors(door_dirs, false)
	_cut_doors(secret_dirs, true)
	match room_type:
		"combat", "elite":
			style = STYLES[rng.randi_range(0, STYLES.size() - 1)] if attempt < 25 else "open"
			_obstacles(style, rng)
			_place_braziers(rng, rng.randi_range(1, 3) if size_id == "std" else rng.randi_range(2, 4))
			_place_pots(rng, rng.randi_range(0, 4))
		"boss", "trial":
			style = room_type
			# four braziers near the corners: lighting them is part of every fight
			var r := interior_rect()
			for c in [Vector2i(r.position.x + 3, r.position.y + 2), Vector2i(r.end.x - 4, r.position.y + 2),
					Vector2i(r.position.x + 3, r.end.y - 3), Vector2i(r.end.x - 4, r.end.y - 3)]:
				set_cell(c.x, c.y, "B")
				braziers.append(c)
		"start":
			style = "start"
			var cx := width / 2
			var cy := height / 2 + 1
			set_cell(cx - 4, cy - 2, "B")
			braziers.append(Vector2i(cx - 4, cy - 2))
			set_cell(cx + 3, cy - 2, "B")
			braziers.append(Vector2i(cx + 3, cy - 2))
		"treasure", "shop", "event", "secret":
			style = room_type
			var r2 := interior_rect()
			for c in [Vector2i(r2.position.x + 2, r2.position.y + 1), Vector2i(r2.end.x - 3, r2.position.y + 1)]:
				set_cell(c.x, c.y, "B")
				braziers.append(c)
			if room_type != "shop":
				_place_pots(rng, rng.randi_range(1, 3))
		_:
			style = "plain"


func _cut_doors(dirs: Array, secret: bool) -> void:
	var cx := width / 2
	var cy := 2 + (height - 3) / 2
	for d in dirs:
		var list: Array[Vector2i] = []
		match d:
			"n":
				list = [Vector2i(cx - 1, 0), Vector2i(cx, 0), Vector2i(cx - 1, 1), Vector2i(cx, 1)]
				door_spawn[d] = Vector2(cx, 2.6)
			"s":
				list = [Vector2i(cx - 1, height - 1), Vector2i(cx, height - 1)]
				door_spawn[d] = Vector2(cx, height - 1.6)
			"w":
				list = [Vector2i(0, cy - 1), Vector2i(0, cy)]
				door_spawn[d] = Vector2(1.6, cy)
			"e":
				list = [Vector2i(width - 1, cy - 1), Vector2i(width - 1, cy)]
				door_spawn[d] = Vector2(width - 1.6, cy)
		for c in list:
			set_cell(c.x, c.y, "S" if secret else "D")
		doors[d] = list


func _in_door_zone(x: int, y: int) -> bool:
	for d in door_spawn:
		var s: Vector2 = door_spawn[d]
		if absf(x + 0.5 - s.x) < 3.5 and absf(y + 0.5 - s.y) < 3.5:
			return true
	return false


func _try_block(x: int, y: int, c: String = "#") -> void:
	var r := interior_rect()
	if x < r.position.x or y < r.position.y or x >= r.end.x or y >= r.end.y:
		return
	if _in_door_zone(x, y) or get_cell(x, y) != ".":
		return
	set_cell(x, y, c)


func _mirror_block(x: int, y: int) -> void:
	# 4-way symmetric placement around the room centre
	var r := interior_rect()
	var mx := r.position.x + r.end.x - 1 - x
	var my := r.position.y + r.end.y - 1 - y
	_try_block(x, y)
	_try_block(mx, y)
	_try_block(x, my)
	_try_block(mx, my)


func _obstacles(kind: String, rng: RandomNumberGenerator) -> void:
	var r := interior_rect()
	var w := r.size.x
	var h := r.size.y
	var x0 := r.position.x
	var y0 := r.position.y
	match kind:
		"pillars4":
			var px := x0 + w / 4 - 1
			var py := y0 + h / 4
			for dx in 2:
				for dy in 2:
					_mirror_block(px + dx, py + dy)
		"grid":
			var step := rng.randi_range(4, 6)
			for y in range(y0 + 2, y0 + h / 2, step - 1):
				for x in range(x0 + 2, x0 + w / 2, step):
					_mirror_block(x, y)
		"center":
			var bw := rng.randi_range(2, 4)
			var bh := rng.randi_range(1, 2)
			for dx in bw:
				for dy in bh:
					_mirror_block(x0 + w / 2 - bw + dx, y0 + h / 2 - bh + dy)
		"scatter":
			for i in rng.randi_range(4, 7):
				_mirror_block(x0 + rng.randi_range(1, w / 2 - 1), y0 + rng.randi_range(1, h / 2 - 1))
		"lanes":
			var ly := y0 + h / 3
			for x in range(x0 + 3, x0 + w / 2 - 2):
				_mirror_block(x, ly)
		"ring":
			var rx := x0 + w / 4
			var ry := y0 + h / 4
			for x in range(rx, x0 + w / 2 - 1):
				_mirror_block(x, ry)
			for y in range(ry, y0 + h / 2 - 1):
				_mirror_block(rx, y)
		"corners":
			for dx in 3:
				_mirror_block(x0 + 1 + dx, y0 + 1)
			for dy in 2:
				_mirror_block(x0 + 1, y0 + 2 + dy)
		_:
			pass


func _free_floor_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var r := interior_rect()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if get_cell(x, y) == "." and not _in_door_zone(x, y):
				out.append(Vector2i(x, y))
	return out


func _place_braziers(rng: RandomNumberGenerator, count: int) -> void:
	var free := _free_floor_cells()
	RunRng.shuffle(rng, free)
	var r := interior_rect()
	for c in free:
		if braziers.size() >= count:
			break
		# keep braziers off the very edge and apart from each other
		if c.x <= r.position.x or c.x >= r.end.x - 1 or c.y <= r.position.y or c.y >= r.end.y - 1:
			continue
		var ok := true
		for b in braziers:
			if absi(b.x - c.x) + absi(b.y - c.y) < 7:
				ok = false
		if ok:
			set_cell(c.x, c.y, "B")
			braziers.append(c)


func _place_pots(rng: RandomNumberGenerator, count: int) -> void:
	var r := interior_rect()
	var candidates: Array[Vector2i] = []
	for c in _free_floor_cells():
		if c.x == r.position.x or c.x == r.end.x - 1 or c.y == r.position.y or c.y == r.end.y - 1:
			candidates.append(c)
	RunRng.shuffle(rng, candidates)
	for i in mini(count, candidates.size()):
		var c := candidates[i]
		set_cell(c.x, c.y, "p")
		pots.append(c)


func validate() -> bool:
	# flood fill from the first door (or the centre) over walkable cells
	var start := Vector2i(width / 2, height / 2)
	for d in door_spawn:
		var s: Vector2 = door_spawn[d]
		start = Vector2i(int(s.x), int(s.y))
		break
	if not _walkable(start.x, start.y):
		return false
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + n
			if not seen.has(q) and _walkable(q.x, q.y):
				seen[q] = true
				queue.append(q)
	for d in door_spawn:
		var s2: Vector2 = door_spawn[d]
		if not seen.has(Vector2i(int(s2.x), int(s2.y))):
			return false
	for b in braziers:
		var touch := false
		for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if seen.has(b + n):
				touch = true
		if not touch:
			return false
	var free := 0
	var r := interior_rect()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if get_cell(x, y) in [".", "p"]:
				free += 1
	var reached := 0
	for p in seen:
		if r.has_point(p):
			reached += 1
	return free > 0 and float(reached) / float(free) >= 0.85


func _walkable(x: int, y: int) -> bool:
	return get_cell(x, y) in [".", "D", "p"]
