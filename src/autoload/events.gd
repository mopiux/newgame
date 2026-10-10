extends Node
## Global signal bus. Only cross-cutting notifications live here; direct
## parent/child communication uses regular signals or calls.

@warning_ignore_start("unused_signal")
# combat / feedback
signal enemy_killed(enemy: Node2D, info: Dictionary)
signal player_damaged(amount: float, source: Node)
signal player_flame_changed(current: float, maximum: float)
signal player_died()
signal screen_shake(strength: float, duration: float)
signal hit_stop(duration: float)
signal damage_number(world_pos: Vector2, amount: float, kind: String)

# run flow
signal room_entered(room: Node)
signal room_cleared(room: Node)
signal relic_gained(relic_id: String)
signal sparks_changed(amount: int)
signal boss_started(boss: Node)
signal boss_health_changed(ratio: float)
signal boss_defeated(boss: Node)
signal toast(text: String, color: Color)
signal map_changed()

# meta
signal settings_changed()
signal language_changed()
@warning_ignore_restore("unused_signal")
