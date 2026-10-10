class_name EchoBrazier
extends StaticBody2D
## Brazier of the «Cámara de los ecos». Stoking it costs a little flame and
## toggles it and both neighbours on the ring (rules in EchoPuzzle). Not in
## the "braziers" group: the flare, relics and creatures ignore it.

signal stoked(brazier: EchoBrazier)

const LIGHT_COLOR := Color(0.72, 0.9, 1.0)

var index := 0
var is_lit := false
var locked := false
var cost := 2.0
var interact_range := 22.0
var sprite: AnimatedSprite2D
var light: LightEmitter
var _cd := 0.0


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("echo_braziers")
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
	light.flicker = 0.05
	light.is_static = true
	light.priority = 70
	light.color = LIGHT_COLOR
	add_child(light)
	_apply_light()


func _process(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)


func can_interact(_p) -> bool:
	return not locked and _cd <= 0.0


func prompt_text() -> String:
	return tr("PROMPT_ECHO") % int(cost)


func describe() -> String:
	return tr("HINT_ECHO")


func interact(player: Player) -> void:
	if not can_interact(player):
		return
	if player.run.flame <= cost + 1.0:
		Audio.sfx("fizzle", -4.0)
		Events.toast.emit(tr("TOAST_NOT_ENOUGH_FLAME"), UITheme.CURSE)
		return
	player.spend_flame(cost)
	_cd = 0.3
	stoked.emit(self)


func set_lit(on: bool, animate: bool) -> void:
	if on == is_lit:
		return
	is_lit = on
	sprite.play("lit" if on else "unlit")
	_apply_light()
	if not animate:
		return
	if on:
		light.pulse(30.0, 0.4)
		Fx.burst(get_parent(), global_position + Vector2(0, -12), "cold", 0.8)
		Audio.sfx("ignite", -8.0, 0.1)
	else:
		Fx.burst(get_parent(), global_position + Vector2(0, -12), "wisps", 0.5)
		Audio.sfx("fizzle", -8.0, 0.1)


## Lit: a full cold flame. Unlit: a pilot glow, so the whole ring stays
## readable in the dark.
func _apply_light() -> void:
	light.radius = 58.0 if is_lit else 20.0
	light.energy = 0.9 if is_lit else 0.45
