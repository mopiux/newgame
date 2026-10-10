class_name Pot
extends StaticBody2D
## Breakable jar / barrel / crate. Bolts, swings and flares break it; may
## hold embers or (rarely) a spark.

signal broken(pot: Pot)

var index := 0
var sheet := "pot_sewer"
var sprite: AnimatedSprite2D
var is_broken := false
var hp := 2


func _ready() -> void:
	add_to_group("breakables")
	collision_layer = Layers.WORLD | Layers.PROPS
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(12, 8)
	shape.shape = r
	shape.position = Vector2(0, -3)
	add_child(shape)
	sprite = SpriteLib.make_sprite(sheet, "idle")
	add_child(sprite)


func on_projectile_hit(p: Projectile) -> void:
	if p.team != "player":
		return
	hp -= 1
	Fx.flash(sprite)
	if hp <= 0:
		break_open(p.source)


func break_open(_by) -> void:
	if is_broken:
		return
	is_broken = true
	remove_from_group("breakables")
	sprite.play("broken")
	collision_layer = 0
	z_index = -2
	Fx.burst(get_parent(), global_position + Vector2(0, -6), "stone", 1.0)
	Audio.sfx("pot_break", -4.0, 0.15)
	broken.emit(self)
