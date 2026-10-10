class_name Door
extends Node2D
## Opening in a room wall. Locked doors show iron bars and block the way;
## open doors trigger the room transition when walked through.

signal entered(dir: String)

var dir := "n"
var cells: Array = []     # tile coords
var locked := false
var kind := "normal"      # normal | boss | treasure | shop | secret | elite
var blocker: StaticBody2D
var bars: Node2D
var _trigger_rect := Rect2()
var _cooldown := 0.6
var _bar_t := 0.0


func setup(direction: String, door_cells: Array, door_kind: String) -> void:
	dir = direction
	cells = door_cells
	kind = door_kind


func _ready() -> void:
	z_index = 2
	var tmin := Vector2(INF, INF)
	var tmax := Vector2(-INF, -INF)
	for c in cells:
		tmin = tmin.min(Vector2(c) * 16.0)
		tmax = tmax.max(Vector2(c) * 16.0 + Vector2(16, 16))
	var r := Rect2(tmin, tmax - tmin)
	match dir:
		"n":
			_trigger_rect = Rect2(r.position.x, r.position.y, r.size.x, 12)
		"s":
			_trigger_rect = Rect2(r.position.x, r.end.y - 6, r.size.x, 6)
		"w":
			_trigger_rect = Rect2(r.position.x, r.position.y, 6, r.size.y)
		"e":
			_trigger_rect = Rect2(r.end.x - 6, r.position.y, 6, r.size.y)
	blocker = StaticBody2D.new()
	blocker.collision_layer = Layers.WORLD
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	blocker.add_child(shape)
	add_child(blocker)
	bars = DoorBars.new()
	bars.rect = r
	bars.dir = dir
	bars.kind = kind
	add_child(bars)
	set_locked(locked, true)


func set_locked(v: bool, instant: bool = false) -> void:
	locked = v
	blocker.process_mode = Node.PROCESS_MODE_INHERIT if v else Node.PROCESS_MODE_DISABLED
	(blocker.get_child(0) as CollisionShape2D).set_deferred("disabled", not v)
	(bars as DoorBars).set_closed(v, instant)
	if not instant:
		Audio.sfx("door_close" if v else "door_open", -6.0, 0.05)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if locked or _cooldown > 0.0:
		return
	for p in get_tree().get_nodes_in_group("player"):
		if p is Player and p.state == Player.State.NORMAL and _trigger_rect.has_point(p.global_position):
			_cooldown = 1.0
			entered.emit(dir)


class DoorBars extends Node2D:
	var rect := Rect2()
	var dir := "n"
	var kind := "normal"
	var closed := 0.0   # 0 open .. 1 closed
	var _target := 0.0

	func set_closed(v: bool, instant: bool) -> void:
		_target = 1.0 if v else 0.0
		if instant:
			closed = _target
		queue_redraw()

	func _process(delta: float) -> void:
		if not is_equal_approx(closed, _target):
			closed = move_toward(closed, _target, delta * 6.0)
			queue_redraw()

	func _draw() -> void:
		var accent := Color("b8893e")
		match kind:
			"boss":
				accent = Color("d46aa6")
			"treasure":
				accent = Color("ffc85a")
			"shop":
				accent = Color("86a86a")
			"elite":
				accent = Color("d9622b")
			"secret":
				accent = Color("9fe0e6")
		# frame posts
		var dark := Color("0b0a12")
		if dir in ["n", "s"]:
			draw_rect(Rect2(rect.position.x - 2, rect.position.y, 2, rect.size.y), dark)
			draw_rect(Rect2(rect.end.x, rect.position.y, 2, rect.size.y), dark)
			draw_rect(Rect2(rect.position.x - 1, rect.position.y, 1, rect.size.y), accent)
			draw_rect(Rect2(rect.end.x, rect.position.y, 1, rect.size.y), accent)
		else:
			draw_rect(Rect2(rect.position.x, rect.position.y - 2, rect.size.x, 2), dark)
			draw_rect(Rect2(rect.position.x, rect.end.y, rect.size.x, 2), dark)
			draw_rect(Rect2(rect.position.x, rect.position.y - 1, rect.size.x, 1), accent)
			draw_rect(Rect2(rect.position.x, rect.end.y, rect.size.x, 1), accent)
		if closed <= 0.01:
			return
		var iron := Color("4a4766")
		var hi := Color("9493a8")
		if dir in ["n", "s"]:
			var h := rect.size.y * closed
			var y0 := rect.position.y if dir == "n" else rect.end.y - h
			var x := rect.position.x + 2.0
			while x < rect.end.x - 1:
				draw_rect(Rect2(x, y0, 2, h), iron)
				draw_rect(Rect2(x, y0, 1, h), hi)
				x += 5.0
			draw_rect(Rect2(rect.position.x, y0 + h - 3, rect.size.x, 2), accent)
		else:
			var w := rect.size.x * closed
			var x0 := rect.position.x if dir == "w" else rect.end.x - w
			var y := rect.position.y + 2.0
			while y < rect.end.y - 1:
				draw_rect(Rect2(x0, y, w, 2), iron)
				draw_rect(Rect2(x0, y, w, 1), hi)
				y += 5.0
			draw_rect(Rect2(x0 + (w - 3 if dir == "w" else 1), rect.position.y, 2, rect.size.y), accent)
