extends TestCase
## Room layouts: every generated room must be traversable.


func test_layouts_validate() -> void:
	var types := ["combat", "elite", "treasure", "shop", "event", "secret", "start", "boss"]
	var all_dirs := [["n"], ["s", "e"], ["n", "s", "e", "w"], ["w", "e"], ["s"]]
	var n := 0
	for size in RoomLayout.SIZES:
		for t in types:
			for dirs in all_dirs:
				for s in 6:
					var rng := RunRng.make(s * 31 + n, "layout-test")
					var l := RoomLayout.create(size, t, dirs, [], rng)
					n += 1
					check(l.validate(), "%s %s %s seed %d invalid" % [size, t, str(dirs), s])
					for d in dirs:
						check(l.doors.has(d), "missing door %s" % d)
						check(l.door_spawn.has(d), "missing door spawn %s" % d)
					if t == "boss":
						eq(l.braziers.size(), 4, "boss room braziers")
	check(n > 500, "enough layouts tested (%d)" % n)


func test_secret_walls_are_cut() -> void:
	var rng := RunRng.make(3, "s")
	var l := RoomLayout.create("std", "combat", ["n"], ["e"], rng)
	for c in l.doors["e"]:
		eq(l.get_cell(c.x, c.y), "S", "secret door cells are breakable walls")
	check(l.is_solid(l.doors["e"][0].x, l.doors["e"][0].y), "secret wall blocks until revealed")


func test_layout_dimensions() -> void:
	for size in RoomLayout.SIZES:
		var l := RoomLayout.create(size, "combat", ["n", "s"], [], RunRng.make(1, size))
		var inner: Vector2i = RoomLayout.SIZES[size]
		eq(l.width, inner.x + 2, size + " width")
		eq(l.height, inner.y + 3, size + " height")
		# every room fits on the 640x360 screen
		check(l.width * 16 <= 640 and l.height * 16 <= 360, size + " fits the screen")


func test_real_floor_rooms_have_all_doors() -> void:
	for s in 40:
		for depth in [1, 2, 3]:
			var biome := Database.biome_for_depth(depth)
			var f := DungeonGenerator.generate(s * 101 + 7, depth, biome.get("layout", {}))
			for k in f.rooms:
				var info: Dictionary = f.rooms[k]
				var rng := RunRng.make(int(info.seed), "layout")
				var l := RoomLayout.create(str(info.size), str(info.type), info.doors, info.secret_doors, rng)
				for d in info.doors:
					check(l.door_spawn.has(d), "seed %d depth %d room %s (%s) missing door %s; spawns %s" % [s, depth, k, info.type, d, str(l.door_spawn.keys())])
				for d in info.secret_doors:
					check(l.door_spawn.has(d), "room %s missing secret door %s" % [k, d])
