class_name Interactables
## Small interactable objects placed by RoomContent. Each exposes
## can_interact(player), prompt_text() and interact(player).


## A relic floating over a stone pedestal. Pedestals in the same group are
## a choice: taking one extinguishes the others.
class RelicPedestal extends Node2D:
	signal taken(pedestal)

	var relic_id := ""
	var group_id := ""
	var price_flame := 0
	var price_sparks := 0
	var interact_range := 20.0
	var icon: Sprite2D
	var light: LightEmitter
	var _t := randf() * 10.0
	var label_hint := ""

	func _ready() -> void:
		add_to_group("interactables")
		var base := Sprite2D.new()
		base.texture = SpriteLib.texture("pedestal")
		base.centered = false
		base.offset = Vector2(-8, -16)
		add_child(base)
		icon = Sprite2D.new()
		icon.texture = RelicIcons.icon(relic_id)
		icon.position = Vector2(0, -24)
		icon.z_as_relative = false
		icon.z_index = Layers.Z_EMISSIVE
		add_child(icon)
		light = LightEmitter.new()
		light.position = Vector2(0, -22)
		light.radius = 34.0
		light.energy = 0.8
		light.color = RelicIcons.rarity_color(relic_id)
		add_child(light)
		if price_flame > 0 or price_sparks > 0:
			var lbl := Label.new()
			lbl.text = ("%d" % price_flame) if price_flame > 0 else ("%d" % price_sparks)
			lbl.add_theme_font_override("font", UITheme.font_small())
			lbl.add_theme_font_size_override("font_size", 8)
			lbl.add_theme_color_override("font_color", UITheme.FLAME if price_flame > 0 else UITheme.SPECTRAL)
			lbl.add_theme_color_override("font_outline_color", UITheme.INK)
			lbl.add_theme_constant_override("outline_size", 2)
			lbl.position = Vector2(-10, 2)
			lbl.size = Vector2(20, 10)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.z_as_relative = false
			lbl.z_index = Layers.Z_FX_TOP
			add_child(lbl)

	func _process(delta: float) -> void:
		_t += delta
		icon.position.y = -24.0 + sin(_t * 2.5) * 1.5

	func can_interact(_p) -> bool:
		return relic_id != ""

	func prompt_text() -> String:
		var r: Dictionary = Database.relics.get(relic_id, {})
		var t := tr(str(r.get("name", relic_id)))
		if price_flame > 0:
			return tr("PROMPT_BUY_FLAME") % [t, price_flame]
		if price_sparks > 0:
			return tr("PROMPT_BUY_SPARKS") % [t, price_sparks]
		return tr("PROMPT_TAKE") % t

	func describe() -> String:
		var r: Dictionary = Database.relics.get(relic_id, {})
		return tr(str(r.get("desc", "")))

	func interact(player: Player) -> void:
		if price_flame > 0 and player.run.flame <= price_flame + 1:
			Events.toast.emit(tr("TOAST_NOT_ENOUGH_FLAME"), UITheme.CURSE)
			Audio.sfx("fizzle")
			return
		if price_sparks > 0 and player.run.sparks < price_sparks:
			Events.toast.emit(tr("TOAST_NOT_ENOUGH_SPARKS"), UITheme.CURSE)
			Audio.sfx("fizzle")
			return
		if price_flame > 0:
			player.spend_flame(price_flame)
		if price_sparks > 0:
			Game.add_sparks(-price_sparks)
		var id := relic_id
		relic_id = ""
		Game.grant_relic(id)
		Fx.burst(get_parent(), global_position + Vector2(0, -24), "embers", 1.5)
		icon.visible = false
		light.enabled = false
		remove_from_group("interactables")
		taken.emit(self)

	func extinguish() -> void:
		relic_id = ""
		remove_from_group("interactables")
		var tw := create_tween()
		tw.tween_property(icon, "modulate:a", 0.0, 0.4)
		tw.parallel().tween_property(light, "energy", 0.0, 0.4)
		Fx.burst(get_parent(), global_position + Vector2(0, -24), "dust", 0.8)


## A consumable on the chandler's counter (oil refill, new wick...).
class ShopGood extends Node2D:
	signal bought(good)

	var good_id := ""
	var price_sparks := 0
	var interact_range := 20.0
	var sold := false
	var icon: Sprite2D

	func _ready() -> void:
		add_to_group("interactables")
		var base := Sprite2D.new()
		base.texture = SpriteLib.texture("pedestal")
		base.centered = false
		base.offset = Vector2(-8, -16)
		add_child(base)
		icon = Sprite2D.new()
		icon.texture = RelicIcons.good_icon(good_id)
		icon.position = Vector2(0, -24)
		icon.z_as_relative = false
		icon.z_index = Layers.Z_EMISSIVE
		add_child(icon)
		var lbl := Label.new()
		lbl.text = str(price_sparks)
		lbl.add_theme_font_override("font", UITheme.font_small())
		lbl.add_theme_font_size_override("font_size", 8)
		lbl.add_theme_color_override("font_color", UITheme.SPECTRAL)
		lbl.add_theme_color_override("font_outline_color", UITheme.INK)
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.position = Vector2(-10, 2)
		lbl.size = Vector2(20, 10)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.z_as_relative = false
		lbl.z_index = Layers.Z_FX_TOP
		add_child(lbl)

	func can_interact(_p) -> bool:
		return not sold

	func prompt_text() -> String:
		return tr("PROMPT_BUY_SPARKS") % [tr("GOOD_%s" % good_id.to_upper()), price_sparks]

	func describe() -> String:
		return tr("GOOD_%s_DESC" % good_id.to_upper())

	func interact(player: Player) -> void:
		if player.run.sparks < price_sparks:
			Events.toast.emit(tr("TOAST_NOT_ENOUGH_SPARKS"), UITheme.CURSE)
			Audio.sfx("fizzle")
			return
		Game.add_sparks(-price_sparks)
		match good_id:
			"oil":
				player.add_flame(45.0)
			"wick":
				player.run.add_curse("wick", {"max_flame": ["add", 12]})
				player.add_flame(12.0)
			"map":
				Game.reveal_map()
		sold = true
		icon.visible = false
		remove_from_group("interactables")
		Audio.sfx("buy")
		bought.emit(self)


## Altar that opens an event dialog.
class EventAltar extends Node2D:
	var event_id := ""
	var done := false
	var interact_range := 22.0
	var sprite: Sprite2D
	var light: LightEmitter
	signal used(altar)

	func _ready() -> void:
		add_to_group("interactables")
		sprite = Sprite2D.new()
		sprite.texture = SpriteLib.texture("altar")
		sprite.centered = false
		sprite.offset = Vector2(-12, -24)
		add_child(sprite)
		light = LightEmitter.new()
		light.position = Vector2(0, -14)
		light.radius = 44.0
		light.energy = 0.7
		light.color = Color(0.85, 0.6, 1.0)
		light.enabled = not done
		add_child(light)
		if done:
			remove_from_group("interactables")
			sprite.modulate = Color(0.6, 0.6, 0.7)

	func can_interact(_p) -> bool:
		return not done

	func prompt_text() -> String:
		return tr("PROMPT_EXAMINE")

	func interact(_player: Player) -> void:
		Game.open_event(event_id, self)

	func finish() -> void:
		done = true
		remove_from_group("interactables")
		sprite.modulate = Color(0.6, 0.6, 0.7)
		light.enabled = false
		used.emit(self)


## Trapdoor leading to the next depth (or the surface after the last boss).
class Hatch extends Node2D:
	var final := false
	var interact_range := 24.0
	var _t := 0.0
	var light: LightEmitter

	func _ready() -> void:
		add_to_group("interactables")
		var s := Sprite2D.new()
		s.texture = SpriteLib.texture("hatch_final" if final else "hatch")
		s.centered = true
		add_child(s)
		light = LightEmitter.new()
		light.radius = 56.0
		light.energy = 0.9
		light.is_static = true
		light.color = Color(1.0, 0.85, 0.55) if final else Color(0.65, 0.9, 1.0)
		add_child(light)
		Fx.burst(get_parent(), global_position, "cold" if not final else "embers", 2.0)

	func can_interact(_p) -> bool:
		return true

	func prompt_text() -> String:
		return tr("PROMPT_ASCEND") if final else tr("PROMPT_DESCEND")

	func interact(_player: Player) -> void:
		remove_from_group("interactables")
		if final:
			Game.finish_run(true)
		else:
			Game.descend()
