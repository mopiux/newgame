class_name Brazier
extends StaticBody2D
## Lighting a brazier costs flame but changes the room: creatures in its
## light take extra damage, moths circle it and burn, and a fully lit room
## pays out a spark when cleared.

signal lit(brazier: Brazier)

var index := 0
var is_lit := false
var interact_range := 22.0
var sprite: AnimatedSprite2D
var light: LightEmitter
var cost := 8.0


func _ready() -> void:
	add_to_group("braziers")
	add_to_group("interactables")
	collision_layer = Layers.WORLD
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 5.0
	shape.shape = c
	add_child(shape)
	var shadow := Sprite2D.new()
	shadow.texture = SpriteLib.texture("shadow")
	shadow.position = Vector2(0, 1)
	add_child(shadow)
	sprite = SpriteLib.make_sprite("brazier", "lit" if is_lit else "unlit")
	add_child(sprite)
	light = LightEmitter.new()
	light.position = Vector2(0, -10)
	light.radius = float(Database.balance_value("brazier.radius", 84.0))
	light.energy = 1.0
	light.flicker = 0.05
	light.is_static = true
	light.priority = 80
	light.color = Color(1.0, 0.78, 0.5)
	light.enabled = is_lit
	add_child(light)
	cost = float(Database.balance_value("brazier.cost", 8.0))


func can_interact(_p) -> bool:
	return not is_lit


func prompt_text() -> String:
	return tr("PROMPT_LIGHT") % int(cost)


func interact(player: Player) -> void:
	if is_lit:
		return
	if player.run.flame <= cost + 1.0:
		Audio.sfx("fizzle", -4.0)
		Events.toast.emit(tr("TOAST_NOT_ENOUGH_FLAME"), UITheme.CURSE)
		return
	player.spend_flame(cost)
	ignite(true)


func ignite(paid: bool) -> void:
	if is_lit:
		return
	is_lit = true
	sprite.play("lit")
	light.enabled = true
	light.pulse(60.0, 0.6)
	remove_from_group("interactables")
	Fx.burst(get_parent(), global_position + Vector2(0, -12), "embers", 1.6)
	Audio.sfx("ignite", -2.0, 0.06)
	lit.emit(self)
	if not paid:
		Fx.burst(get_parent(), global_position + Vector2(0, -12), "sparks", 0.6)
