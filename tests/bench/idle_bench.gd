extends Node
## Measures per-frame CPU cost of an idle expedition room, then disables
## systems one by one to find the expensive ones.
##   godot --headless --fixed-fps 60 --path . res://tests/bench/idle_bench.tscn

var _frames := 0
var _sum := 0.0
var _last_us := 0
var _stage := 0
var _labels := ["baseline", "no_hud", "no_darkness", "no_lights", "no_player"]


func _ready() -> void:
	SaveManager.profile = SaveManager.default_profile()
	Game.main = get_parent() if get_parent().has_method("show_screen") else null
	var r := RunState.create("BENCH", "oil", 0)
	r.generate_floor()
	Game.run = r
	var level := Level.new()
	level.run = r
	add_child(level)
	Game.level = level


func _process(_delta: float) -> void:
	# with --fixed-fps the engine runs flat out: wall time per frame = total cost
	var now := Time.get_ticks_usec()
	var dt := (now - _last_us) / 1000000.0
	_last_us = now
	_frames += 1
	if _frames < 30:
		return
	_sum += dt
	if _frames % 150 == 0:
		print("%-12s process_avg=%.3fms nodes=%d" % [_labels[_stage], _sum / 120.0 * 1000.0, Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
		_sum = 0.0
		_frames = 0
		_stage += 1
		var level: Level = Game.level
		match _stage:
			1:
				level.hud.queue_free()
			2:
				level.room.darkness.queue_free()
			3:
				for e in Lights.emitters.duplicate():
					e.queue_free()
			4:
				level.player.queue_free()
			5:
				get_tree().quit()
