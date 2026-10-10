class_name RoomArt
## Composes a room's static background (floor, decals, wall faces and caps)
## into a single texture from the biome tileset. One draw call per room.

const T := 16
# tileset layout - see tools/art/sprites_world.py
const ROW_FLOOR := 0
const ROW_DECAL := 1
const ROW_FACE := 2
const ROW_TOP := 3

static var _tilesets := {}
static var _rims := {}


static func _tileset(name: String) -> Image:
	if not _tilesets.has(name):
		var tex: Texture2D = load("res://assets/gfx/tiles_%s.png" % name)
		var img: Image = tex.get_image() if tex else Image.create(128, 64, false, Image.FORMAT_RGBA8)
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		_tilesets[name] = img
	return _tilesets[name]


static func rim_color(name: String) -> Color:
	if _rims.is_empty():
		var path := "res://assets/gfx/tilesets.json"
		var data = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
		if typeof(data) == TYPE_DICTIONARY:
			for k in data:
				_rims[k] = Color(data[k].get("rim", "#6b6a86"))
	return _rims.get(name, Color("6b6a86"))


static func compose(layout: RoomLayout, tileset: String, rng: RandomNumberGenerator, decal_chance: float = 0.07) -> ImageTexture:
	var src := _tileset(tileset)
	var w := layout.width
	var h := layout.height
	var img := Image.create(w * T, h * T, false, Image.FORMAT_RGBA8)
	img.fill(Color("0b0a12"))
	var rim := rim_color(tileset)
	var shade := Color(0.043, 0.039, 0.071, 0.45)
	for y in h:
		for x in w:
			var c := layout.get_cell(x, y)
			var dst := Vector2i(x * T, y * T)
			if c in ["W", "S"]:
				var below_floor := y >= 1 and y < h - 1 and not layout.is_solid(x, y + 1) and layout.get_cell(x, y + 1) != "W"
				if c == "S":
					below_floor = y == 1
				if below_floor and y >= 1:
					var v := _pick_face(rng)
					img.blit_rect(src, Rect2i(v * T, ROW_FACE * T, T, T), dst)
				else:
					var tv := rng.randi_range(0, 3)
					img.blit_rect(src, Rect2i(tv * T, ROW_TOP * T, T, T), dst)
					_draw_rims(img, layout, x, y, rim)
			else:
				# floor under everything walkable or placed (pillars, braziers, pots)
				var fv := _pick_floor(rng)
				img.blit_rect(src, Rect2i(fv * T, ROW_FLOOR * T, T, T), dst)
				if c == "." and rng.randf() < decal_chance:
					var dv := rng.randi_range(0, 7)
					img.blend_rect(src, Rect2i(dv * T, ROW_DECAL * T, T, T), dst)
				if c == "D":
					_door_fade(img, layout, x, y)
	# soft shadow under the top wall face and along side walls
	for y in h:
		for x in w:
			if layout.is_solid(x, y) or layout.get_cell(x, y) == "W":
				continue
			if layout.get_cell(x, y - 1) == "W":
				_shade_rect(img, Rect2i(x * T, y * T, T, 4), shade)
				_shade_rect(img, Rect2i(x * T, y * T, T, 2), shade)
			if layout.get_cell(x - 1, y) == "W":
				_shade_rect(img, Rect2i(x * T, y * T, 2, T), shade)
			if layout.get_cell(x + 1, y) == "W":
				_shade_rect(img, Rect2i(x * T + T - 2, y * T, 2, T), shade)
	return ImageTexture.create_from_image(img)


static func _pick_floor(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	if r < 0.7:
		return rng.randi_range(0, 3)
	return rng.randi_range(4, 7)


static func _pick_face(rng: RandomNumberGenerator) -> int:
	var r := rng.randf()
	if r < 0.82:
		return rng.randi_range(0, 5)
	return rng.randi_range(6, 7)


static func _draw_rims(img: Image, layout: RoomLayout, x: int, y: int, rim: Color) -> void:
	var px := x * T
	var py := y * T
	var open := func(cx: int, cy: int) -> bool:
		var c := layout.get_cell(cx, cy)
		return c in [".", "D", "#", "B", "p"]
	if open.call(x, y + 1):
		img.fill_rect(Rect2i(px, py + T - 1, T, 1), rim)
	if open.call(x, y - 1):
		img.fill_rect(Rect2i(px, py, T, 1), rim)
	if open.call(x - 1, y):
		img.fill_rect(Rect2i(px, py, 1, T), rim)
	if open.call(x + 1, y):
		img.fill_rect(Rect2i(px + T - 1, py, 1, T), rim)


static func _shade_rect(img: Image, r: Rect2i, c: Color) -> void:
	for yy in range(r.position.y, r.end.y):
		for xx in range(r.position.x, r.end.x):
			img.set_pixel(xx, yy, img.get_pixel(xx, yy).blend(c))


static func _door_fade(img: Image, layout: RoomLayout, x: int, y: int) -> void:
	# fade door passages into darkness towards the outside edge
	var dark := Color("0b0a12")
	var px := x * T
	var py := y * T
	for i in T:
		var k := 0.0
		if y == 0:
			k = 1.0 - float(i) / T
			img.fill_rect(Rect2i(px, py + i, T, 1), img.get_pixel(px, py + i).lerp(dark, k))
		elif y == layout.height - 1:
			k = float(i) / T
			img.fill_rect(Rect2i(px, py + i, T, 1), img.get_pixel(px, py + i).lerp(dark, k))
		elif x == 0:
			k = 1.0 - float(i) / T
			img.fill_rect(Rect2i(px + i, py, 1, T), img.get_pixel(px + i, py).lerp(dark, k))
		elif x == layout.width - 1:
			k = float(i) / T
			img.fill_rect(Rect2i(px + i, py, 1, T), img.get_pixel(px + i, py).lerp(dark, k))
