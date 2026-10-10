class_name LampPost
extends Node2D
## Street lamp of the plaza. Relighting it with sparks unlocks a permanent
## upgrade - and makes the plaza visibly brighter.

var lamp: Dictionary = {}
var lit := false
var decorative := false
var big := false
var interact_range := 22.0
var sprite: AnimatedSprite2D
var light: LightEmitter


func _ready() -> void:
	sprite = SpriteLib.make_sprite("lighthouse" if big else "lamp_post", "lit" if lit else "unlit")
	add_child(sprite)
	light = LightEmitter.new()
	light.position = Vector2(0, -34 if big else -22)
	light.radius = 150.0 if big else 96.0
	light.energy = 1.0
	light.is_static = true
	light.priority = 70
	light.flicker = 0.03
	light.color = Color(1.0, 0.84, 0.6)
	light.enabled = lit
	add_child(light)
	if not decorative:
		add_to_group("interactables")


func can_interact(_p) -> bool:
	return not decorative


func prompt_text() -> String:
	var n := tr(str(lamp.get("name", "")))
	if lit:
		return n
	if lamp.get("requires_boss", "") != "" and not SaveManager.profile.bosses_defeated.has(lamp.requires_boss):
		return tr("PROMPT_LAMP_LOCKED") % n
	return tr("PROMPT_LAMP") % [n, int(lamp.get("cost", 0))]


func describe() -> String:
	return tr(str(lamp.get("desc", "")))


func interact(_player: Player) -> void:
	if lit:
		return
	var req := str(lamp.get("requires_boss", ""))
	if req != "" and not SaveManager.profile.bosses_defeated.has(req):
		Events.toast.emit(tr("TOAST_LAMP_LOCKED"), UITheme.CURSE)
		Audio.sfx("fizzle")
		return
	var cost := int(lamp.get("cost", 0))
	if SaveManager.profile.sparks < cost:
		Events.toast.emit(tr("TOAST_NOT_ENOUGH_SPARKS"), UITheme.CURSE)
		Audio.sfx("fizzle")
		return
	SaveManager.profile.sparks -= cost
	SaveManager.profile.lamps.append(str(lamp.id))
	SaveManager.save_profile()
	set_lit(true)
	Events.toast.emit(tr("TOAST_LAMP_LIT") % tr(str(lamp.get("name", ""))), UITheme.FLAME)
	Events.sparks_changed.emit(SaveManager.profile.sparks)


func set_lit(v: bool) -> void:
	lit = v
	sprite.play("lit" if v else "unlit")
	light.enabled = v
	if v:
		light.pulse(80.0, 1.0)
		Fx.burst(get_parent(), global_position + light.position, "embers", 2.5)
		Fx.shake(3.0, 0.3)
		Audio.sfx("lamp_lit", 0.0, 0.0)
