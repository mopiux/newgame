class_name RelicIcons
## Icon lookup for relics and shop goods (16x16 cells in relic_icons.png).

const COLS := 8
const GOODS := {"oil": 40, "wick": 41, "map": 42}

static var _cache := {}


static func clear_cache() -> void:
	_cache.clear()


static func _cell(index: int) -> Texture2D:
	if _cache.has(index):
		return _cache[index]
	var atlas := SpriteLib.texture("relic_icons")
	var at := AtlasTexture.new()
	at.atlas = atlas
	at.region = Rect2((index % COLS) * 16, (index / COLS) * 16, 16, 16)
	_cache[index] = at
	return at


static func icon(relic_id: String) -> Texture2D:
	var r: Dictionary = Database.relics.get(relic_id, {})
	return _cell(int(r.get("icon", 0)))


static func good_icon(good_id: String) -> Texture2D:
	return _cell(int(GOODS.get(good_id, 40)))


static func rarity_color(relic_id: String) -> Color:
	var r: Dictionary = Database.relics.get(relic_id, {})
	match str(r.get("rarity", "common")):
		"rare":
			return Color(0.6, 0.85, 1.0)
		"legendary":
			return Color(1.0, 0.85, 0.4)
		"cursed":
			return Color(0.9, 0.45, 0.8)
	return Color(1.0, 0.8, 0.6)


static func rarity_name(relic_id: String) -> String:
	var r: Dictionary = Database.relics.get(relic_id, {})
	return "RARITY_" + str(r.get("rarity", "common")).to_upper()
