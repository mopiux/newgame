extends TestCase
## Data integrity: every id, sprite, icon and text referenced exists.


func test_database_loads_cleanly() -> void:
	eq(Database.errors.size(), 0, "database errors: " + str(Database.errors))
	check(Database.relics.size() >= 30, "relic count")
	check(Database.enemies.size() >= 12, "enemy count")
	eq(Database.biomes.size(), 3, "three depths")


func _translated(key: String) -> bool:
	var ok := true
	for loc in ["es", "en"]:
		TranslationServer.set_locale(loc)
		if TranslationServer.translate(key) == key:
			ok = false
	return ok


func test_texts_exist_in_both_languages() -> void:
	var keys: Array = []
	for id in Database.relics:
		keys.append(Database.relics[id].name)
		keys.append(Database.relics[id].desc)
	for id in Database.enemies:
		keys.append(Database.enemies[id].name)
		keys.append(Database.enemies[id].get("lore", ""))
	for id in Database.lanterns:
		keys.append(Database.lanterns[id].name)
		keys.append(Database.lanterns[id].desc)
	for l in Database.lamps:
		keys.append(l.name)
		keys.append(l.desc)
	for b in Database.biomes:
		keys.append(b.name)
	for id in Database.events:
		var e: Dictionary = Database.events[id]
		keys.append(e.title)
		keys.append(e.text)
		for o in e.options:
			keys.append(o.text)
			if o.has("result"):
				keys.append(o.result)
			if o.has("gamble"):
				keys.append(o.gamble.win_text)
				keys.append(o.gamble.lose_text)
	for i in range(1, 11):
		keys.append(Database.balance_value("ascension.%d.desc" % i, ""))
	for k in keys:
		check(k != "" and _translated(k), "missing translation for '%s'" % k)
	TranslationServer.set_locale(str(Settings.get_value("game", "language")))


func test_relic_icons_and_rarities() -> void:
	var used := {}
	for id in Database.relics:
		var r: Dictionary = Database.relics[id]
		var icon := int(r.icon)
		check(icon >= 0 and icon < 40, "%s icon in range" % id)
		check(not used.has(icon), "%s icon %d reused" % [id, icon])
		used[icon] = true
		check(r.rarity in ["common", "rare", "legendary", "cursed"], "%s rarity" % id)
		check(int(r.get("tier", 0)) in [0, 1, 2], "%s tier" % id)
		for stat in r.get("stats", {}):
			check(Database.balance.player.has(stat), "%s modifies unknown stat %s" % [id, stat])


func test_sprites_exist() -> void:
	for id in Database.enemies:
		check(SpriteLib.has_sheet(str(Database.enemies[id].sprite)), "sprite sheet for " + id)
		var sf := SpriteLib.frames(str(Database.enemies[id].sprite))
		var anim := str(Database.enemies[id].get("anim", ""))
		if anim != "":
			check(sf.has_animation(anim), "%s has animation %s" % [id, anim])
	for sheet in ["player", "lantern", "brazier", "bolt", "orb", "ember", "spark", "lamp_post", "lighthouse", "cerero", "impact"]:
		check(SpriteLib.has_sheet(sheet), "sheet " + sheet)
	for img in ["shadow", "pedestal", "altar", "hatch", "hatch_final", "well", "notice_board", "relic_icons", "tiles_sewer", "tiles_crypt", "tiles_foundry", "tiles_plaza"]:
		check(SpriteLib.texture(img) != null, "texture " + img)
	for b in Database.biomes:
		check(SpriteLib.texture("pillar_" + str(b.tileset)) != null, "pillar for " + str(b.tileset))
		check(SpriteLib.has_sheet("pot_" + str(b.pot)), "pot for " + str(b.pot))
	# animations used by code
	var p := SpriteLib.frames("player")
	for a in ["idle_down", "idle_up", "idle_side", "run_down", "run_side", "hurt_side", "dash_side", "dead"]:
		check(p.has_animation(a), "player anim " + a)
	for pair in [["golem", "windup"], ["golem", "charge"], ["golem", "dazed"], ["eye", "closed"], ["eye", "charge"],
			["mimic", "awake"], ["snuffer", "attack"], ["shade", "lunge"], ["slug", "crawl_small"],
			["moth_mother", "cast"], ["great_snuffer", "slam"], ["great_snuffer", "raise"], ["penumbra", "cast"]]:
		check(SpriteLib.frames(pair[0]).has_animation(pair[1]), "%s anim %s" % pair)


func test_unlock_effects_are_known() -> void:
	var known := ["relic_tier_1", "relic_tier_2", "max_flame_15", "lantern_mirror", "lantern_ember", "lantern_pilgrim",
		"events_2", "start_relic", "shop_extra", "ember_bonus", "lighthouse"]
	var ids := {}
	for l in Database.lamps:
		check(str(l.unlock) in known, "lamp %s has known unlock %s" % [l.id, l.unlock])
		check(not ids.has(l.id), "duplicate lamp " + str(l.id))
		ids[l.id] = true
		var pos: Array = l.pos
		check(pos[0] > 1 and pos[0] < 37 and pos[1] > 1 and pos[1] < 20, "lamp %s inside the plaza" % l.id)
	for id in Database.lanterns:
		var u := str(Database.lanterns[id].get("unlock", ""))
		check(u == "" or u in known, "lantern %s unlock" % id)


func test_event_effects_are_known() -> void:
	var known := ["flame", "flame_full", "max_flame", "stat", "sparks", "relic", "remove_relic", "embers", "spawn", "reveal_map"]
	for id in Database.events:
		for o in Database.events[id].options:
			var effects: Array = o.get("effects", [])
			if o.has("gamble"):
				effects = o.gamble.win + o.gamble.lose
			for e in effects:
				check(str(e.type) in known, "event %s effect %s" % [id, e.type])
				if e.type == "spawn":
					check(Database.enemies.has(str(e.id)), "event %s spawns unknown %s" % [id, e.id])
