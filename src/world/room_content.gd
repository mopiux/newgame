class_name RoomContent
extends Node2D
## Places the type-specific content of a room (relic altars, the chandler's
## shop, event altars, the boss, secret caches, the descent hatch) and keeps
## its state in the room's persistent dictionary.

var room: Room
var data: Dictionary   # room.state["data"]
var _boss_spawned := false


func setup(r: Room) -> void:
	room = r
	if not room.state.has("data") or typeof(room.state.data) != TYPE_DICTIONARY:
		room.state["data"] = {}
	data = room.state.data
	match room.room_type:
		"start":
			_setup_start()
		"treasure":
			_setup_treasure()
		"shop":
			_setup_shop()
		"event":
			_setup_event()
		"secret":
			_setup_secret()
		"trial":
			_setup_trial()
		"echo":
			_setup_echo()
		"boss":
			if room.state.get("cleared", false):
				_spawn_boss_rewards(false)
		"elite":
			if room.state.get("cleared", false) and not data.get("elite_taken", false):
				spawn_elite_reward()


func center() -> Vector2:
	var r := room.layout.interior_rect()
	return Vector2(r.get_center()) * Room.T + Vector2(0, 8)


func _rng(tag: String) -> RandomNumberGenerator:
	return RunRng.make(int(room.info.get("seed", 0)), tag)


func on_enter() -> void:
	pass


# --- start ---------------------------------------------------------------------

func _setup_start() -> void:
	if room.depth != 1 or room.run.rooms_cleared > 0:
		return
	# chalk hints on the floor: the tutorial lives in the world
	var lines := [
		tr("HINT_MOVE") % [Settings.binding_label("move_up") + Settings.binding_label("move_left") + Settings.binding_label("move_down") + Settings.binding_label("move_right")],
		tr("HINT_SHOOT") % Settings.binding_label("shoot"),
		tr("HINT_MELEE") % Settings.binding_label("melee"),
		tr("HINT_DASH") % Settings.binding_label("dash"),
		tr("HINT_FLARE") % Settings.binding_label("flare"),
		tr("HINT_LIGHT") % Settings.binding_label("interact"),
	]
	var c := center()
	var y := c.y - 30.0
	var delay := 2.8
	for line in lines:
		var l := Label.new()
		l.text = line
		l.add_theme_font_override("font", UITheme.font_body())
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.79, 0.78, 0.82, 0.6))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size = Vector2(320, 14)
		l.position = Vector2(c.x - 160, y)
		# chalk writing: readable in the dark, appears once the title fades
		l.z_as_relative = false
		l.z_index = Layers.Z_EMISSIVE - 5
		l.modulate.a = 0.0
		add_child(l)
		var tw := l.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(l, "modulate:a", 1.0, 0.6)
		delay += 0.25
		y += 14.0


# --- treasure --------------------------------------------------------------------

func _setup_treasure() -> void:
	if room.state.get("loot_taken", false):
		_place_empty_pedestals(3)
		return
	if not data.has("offer"):
		data["offer"] = RelicPool.roll(room.run, _rng("treasure"), 3)
	_place_choice(data.offer, "loot_taken")


func _place_choice(ids: Array, flag: String, price_flame: bool = false) -> void:
	var c := center()
	var n := ids.size()
	var peds: Array = []
	for i in n:
		var p := Interactables.RelicPedestal.new()
		p.relic_id = ids[i]
		if price_flame:
			p.price_flame = RelicPool.price(ids[i])
		p.position = c + Vector2((i - (n - 1) * 0.5) * 48.0, 0)
		room.entities.add_child(p)
		peds.append(p)
	for p in peds:
		p.taken.connect(func(taken):
			room.state[flag] = true
			if not price_flame:
				for other in peds:
					if other != taken:
						other.extinguish())


func _place_empty_pedestals(n: int) -> void:
	var c := center()
	for i in n:
		var s := Sprite2D.new()
		s.texture = SpriteLib.texture("pedestal")
		s.centered = false
		s.offset = Vector2(-8, -16)
		s.position = c + Vector2((i - (n - 1) * 0.5) * 48.0, 0)
		room.entities.add_child(s)


# --- shop ------------------------------------------------------------------------

func _setup_shop() -> void:
	var c := center()
	var keeper := SpriteLib.make_sprite("cerero", "idle")
	keeper.position = c + Vector2(0, -34)
	room.entities.add_child(keeper)
	var kl := LightEmitter.new()
	kl.position = c + Vector2(0, -40)
	kl.radius = 70.0
	kl.is_static = true
	kl.color = Color(1.0, 0.85, 0.6)
	room.add_child(kl)
	if not data.has("relics"):
		var extra := 1 if SaveManager.is_unlocked("shop_extra") else 0
		data["relics"] = RelicPool.roll(room.run, _rng("shop"), 2 + extra)
		data["goods"] = ["oil", "wick"] if _rng("goods").randf() < 0.6 else ["oil", "map"]
		data["bought"] = []
	var bought: Array = data.bought
	var items: Array = data.relics
	var all_n: int = items.size() + (data.goods as Array).size()
	var idx := 0
	for id in items:
		if not bought.has(id):
			var p := Interactables.RelicPedestal.new()
			p.relic_id = id
			p.price_flame = int(RelicPool.price(id) * Game.ascension_mult("prices"))
			p.position = c + Vector2((idx - (all_n - 1) * 0.5) * 40.0, 16)
			p.taken.connect(func(_t): bought.append(id))
			room.entities.add_child(p)
		idx += 1
	for g in data.goods:
		if not bought.has(g):
			var s := Interactables.ShopGood.new()
			s.good_id = g
			s.price_sparks = int(Database.balance_value("shop.%s" % g, 3))
			s.position = c + Vector2((idx - (all_n - 1) * 0.5) * 40.0, 16)
			s.bought.connect(func(_t): bought.append(g))
			room.entities.add_child(s)
		idx += 1


# --- events ---------------------------------------------------------------------

func _setup_event() -> void:
	if not data.has("event"):
		data["event"] = Game.pick_event(_rng("event"))
	var a := Interactables.EventAltar.new()
	a.event_id = data.event
	a.done = data.get("done", false)
	a.position = center()
	a.used.connect(func(_a): data["done"] = true)
	room.entities.add_child(a)


# --- secret --------------------------------------------------------------------

func _setup_secret() -> void:
	if not data.get("cache_taken", false):
		data["cache_taken"] = true
		var rng := _rng("secret")
		var c := center()
		var n := rng.randi_range(3, 5)
		Game.add_sparks(n)
		Events.toast.emit(tr("TOAST_SECRET_CACHE") % n, UITheme.SPECTRAL)
		Fx.burst(room.entities, c, "cold", 3.0)
		room.drop_embers(room.global_position + c, 4)
	if room.state.get("loot_taken", false):
		_place_empty_pedestals(1)
		return
	if not data.has("offer"):
		data["offer"] = RelicPool.roll(room.run, _rng("secret_relic"), 1, ["rare", "legendary"])
	_place_choice(data.offer, "loot_taken")


# --- brazier trial ------------------------------------------------------------
# Four unlit braziers around a sealed reliquary: light them all (paying flame)
# and it opens with a rare relic. A pure decision: power now vs. flame now.

var _reliquary: Sprite2D


func _setup_trial() -> void:
	_reliquary = Sprite2D.new()
	_reliquary.centered = false
	_reliquary.offset = Vector2(-12, -20)
	_reliquary.position = center()
	room.entities.add_child(_reliquary)
	var body := StaticBody2D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(20, 8)
	cs.shape = r
	cs.position = Vector2(0, -3)
	body.add_child(cs)
	_reliquary.add_child(body)
	if data.get("trial_done", false):
		_reliquary.texture = SpriteLib.texture("reliquary_open")
		if not room.state.get("loot_taken", false):
			_trial_reward()
	else:
		_reliquary.texture = SpriteLib.texture("reliquary")


func on_brazier_lit(_b: Brazier) -> void:
	if room.room_type != "trial" or data.get("trial_done", false):
		return
	if room.all_braziers_lit():
		data["trial_done"] = true
		_reliquary.texture = SpriteLib.texture("reliquary_open")
		Fx.burst(room.entities, _reliquary.position + Vector2(0, -12), "embers", 3.0)
		Fx.shake(3.0, 0.3)
		Audio.sfx("secret", -2.0, 0.0)
		Events.toast.emit(tr("TOAST_TRIAL_DONE"), UITheme.FLAME)
		_trial_reward()
	else:
		var lit := 0
		for b in room.braziers:
			if b.is_lit:
				lit += 1
		Events.toast.emit(tr("TOAST_TRIAL") % [lit, room.braziers.size()], UITheme.BRASS_LIGHT)


func _trial_reward() -> void:
	if not data.has("offer"):
		data["offer"] = RelicPool.roll(room.run, _rng("trial"), 1, ["rare", "legendary"])
	var p := Interactables.RelicPedestal.new()
	p.relic_id = data.offer[0] if not (data.offer as Array).is_empty() else "lens"
	p.position = center() + Vector2(0, 30)
	p.taken.connect(func(_t): room.state["loot_taken"] = true)
	room.entities.add_child(p)


# --- echo chamber -------------------------------------------------------------
# Five braziers on a ring around a sealed reliquary. Stoking one (2 flame)
# toggles it and both neighbours; light all five and the reliquary opens.
# Chalk lines on the floor show which braziers answer each other.

var echoes: Array[EchoBrazier] = []


func _setup_echo() -> void:
	_reliquary = Sprite2D.new()
	_reliquary.centered = false
	_reliquary.offset = Vector2(-12, -20)
	_reliquary.position = center()
	room.entities.add_child(_reliquary)
	var body := StaticBody2D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(20, 8)
	cs.shape = r
	cs.position = Vector2(0, -3)
	body.add_child(cs)
	_reliquary.add_child(body)
	var glow := LightEmitter.new()
	glow.position = Vector2(0, -14)
	glow.radius = 30.0
	glow.energy = 0.5
	glow.color = EchoBrazier.LIGHT_COLOR
	_reliquary.add_child(glow)
	if not data.has("echo"):
		data["echo"] = EchoPuzzle.scramble(_rng("echo"))
	var state := echo_state()
	var done := bool(data.get("echo_done", false))
	var points := room.layout.echo_positions()
	var chalk := EchoChalk.new()
	chalk.points = points
	add_child(chalk)
	for i in points.size():
		var b := EchoBrazier.new()
		b.index = i
		b.is_lit = state[i] == 1
		b.locked = done
		b.position = points[i]
		b.stoked.connect(_on_echo_stoked)
		room.entities.add_child(b)
		echoes.append(b)
	if done:
		_reliquary.texture = SpriteLib.texture("reliquary_open")
		if not room.state.get("loot_taken", false):
			_echo_reward()
	else:
		_reliquary.texture = SpriteLib.texture("reliquary")
		_chalk_line(tr("HINT_ECHO"), center() + Vector2(0, 58))


## Current ring as 0/1 ints (JSON may have turned them into floats).
func echo_state() -> Array:
	var out := []
	for v in data.get("echo", []):
		out.append(1 if int(v) == 1 else 0)
	while out.size() < EchoPuzzle.SIZE:
		out.append(0)
	return out


func _on_echo_stoked(b: EchoBrazier) -> void:
	if data.get("echo_done", false):
		return
	var state := EchoPuzzle.press(echo_state(), b.index)
	data["echo"] = state
	for e in echoes:
		e.set_lit(state[e.index] == 1, true)
	if EchoPuzzle.solved(state):
		data["echo_done"] = true
		for e in echoes:
			e.locked = true
		_reliquary.texture = SpriteLib.texture("reliquary_open")
		Fx.burst(room.entities, _reliquary.position + Vector2(0, -12), "cold", 3.0)
		Fx.shake(3.0, 0.3)
		Audio.sfx("secret", -2.0, 0.0)
		Events.toast.emit(tr("TOAST_ECHO_DONE"), UITheme.SPECTRAL)
		_echo_reward()


func _echo_reward() -> void:
	if not data.has("offer"):
		data["offer"] = RelicPool.roll(room.run, _rng("echo_relic"), 1, ["rare"])
	var p := Interactables.RelicPedestal.new()
	p.relic_id = data.offer[0] if not (data.offer as Array).is_empty() else "lens"
	p.position = center() + Vector2(0, 30)
	p.taken.connect(func(_t): room.state["loot_taken"] = true)
	room.entities.add_child(p)


func _chalk_line(text: String, pos: Vector2) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UITheme.font_body())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.79, 0.86, 0.9, 0.6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(320, 14)
	l.position = Vector2(pos.x - 160, pos.y)
	l.z_as_relative = false
	l.z_index = Layers.Z_EMISSIVE - 5
	l.modulate.a = 0.0
	add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(l, "modulate:a", 1.0, 0.6)


## Dotted chalk ring linking each echo brazier with its two neighbours.
class EchoChalk extends Node2D:
	var points: Array[Vector2] = []

	func _ready() -> void:
		# faint chalk above the darkness, like the hints: the ring must read
		z_as_relative = false
		z_index = Layers.Z_EMISSIVE - 6

	func _draw() -> void:
		var col := Color(0.79, 0.86, 0.92, 0.3)
		for i in points.size():
			var a: Vector2 = points[i] + Vector2(0, -2)
			var b: Vector2 = points[(i + 1) % points.size()] + Vector2(0, -2)
			var n := int(a.distance_to(b) / 6.0)
			for k in range(1, n):
				var p := a.lerp(b, float(k) / n).round()
				draw_rect(Rect2(p, Vector2(2, 1)), col)


# --- elite ---------------------------------------------------------------------

var _elite_spawned := false


func spawn_elite_reward() -> void:
	if data.get("elite_taken", false) or _elite_spawned:
		return
	_elite_spawned = true
	if not data.has("elite_offer"):
		data["elite_offer"] = RelicPool.roll(room.run, _rng("elite"), 1, ["rare", "common"])
	var p := Interactables.RelicPedestal.new()
	p.relic_id = data.elite_offer[0] if not data.elite_offer.is_empty() else "braided_wick"
	p.position = center()
	p.taken.connect(func(_t): data["elite_taken"] = true)
	room.entities.add_child(p)


# --- boss --------------------------------------------------------------------

func start_boss() -> void:
	if _boss_spawned:
		return
	_boss_spawned = true
	var boss_id := str(room.biome.get("boss", "moth_mother"))
	var b := BossFactory.create(boss_id, room.depth)
	b.position = center() + Vector2(0, -30)
	b.room = room
	room.start_boss_fight(b)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_callback(func():
		room.add_enemy(b)
		Events.boss_started.emit(b))
	b.defeated.connect(func(): _on_boss_defeated(b))


func _on_boss_defeated(b: Node) -> void:
	room.boss = null
	Events.boss_defeated.emit(b)
	var sparks := int(room.biome.get("boss_sparks", 8))
	var c: Vector2 = b.global_position
	for i in sparks:
		room.drop_spark(c + Vector2(randf_range(-20, 20), randf_range(-12, 12)))
	room.drop_embers(c, 8)
	_spawn_boss_rewards(true)


func _spawn_boss_rewards(fresh: bool) -> void:
	var c := center()
	var final := room.depth >= Database.biomes.size()
	if not room.state.get("loot_taken", false):
		if not data.has("offer"):
			data["offer"] = RelicPool.roll(room.run, _rng("boss_relic"), 2, ["rare", "legendary"])
		var ids: Array = data.offer
		var n := ids.size()
		var peds: Array = []
		for i in n:
			var p := Interactables.RelicPedestal.new()
			p.relic_id = ids[i]
			p.position = c + Vector2((i - (n - 1) * 0.5) * 56.0, -20)
			room.entities.add_child(p)
			peds.append(p)
		for p in peds:
			p.taken.connect(func(taken):
				room.state["loot_taken"] = true
				for other in peds:
					if other != taken:
						other.extinguish())
	var h := Interactables.Hatch.new()
	h.final = final
	h.position = c + Vector2(0, 36)
	if fresh:
		var tw := create_tween()
		tw.tween_interval(1.2)
		tw.tween_callback(func(): room.entities.add_child(h))
	else:
		room.entities.add_child(h)
