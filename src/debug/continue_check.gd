class_name ContinueCheck
extends Node
## End-to-end check of "Continue": plays a little, saves, reloads through
## Game.continue_run() and compares the restored expedition.
##   godot --headless --path . -- --continue-check

var _step := 0
var _t := 0.0
var _expect := {}
var _failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.new_run("oil", "CONTINUE", 0)


func _process(delta: float) -> void:
	_t += delta
	if _t < 1.0:
		return
	_t = 0.0
	var level: Level = Game.level
	match _step:
		0:
			# walk into a neighbouring combat room, then a treasure room if any
			var start := level.run.current_room
			var info: Dictionary = level.run.floor.rooms[start]
			var d: String = info.doors[0]
			var next: Vector2i = DungeonGenerator.parse_key(start) + DungeonGenerator.DIRS[d]
			level._enter_room(DungeonGenerator.key(next), DungeonGenerator.OPPOSITE[d])
		1:
			# light the first brazier of the room (if any) and take a relic
			if not level.room.braziers.is_empty():
				level.room.braziers[0].ignite(false)
			Game.grant_relic("lens")
			level.run.flame = 57.0
			level.run.sparks = 9
			_expect = {
				"room": level.run.current_room,
				"relics": level.run.relics.duplicate(),
				"flame": level.run.flame,
				"sparks": level.run.sparks,
				"lit": level.room.state.get("lit", []).duplicate(),
				"from": level.run.entered_from,
			}
			Game.save_run_snapshot()
			Game.goto_menu()
		2:
			if not SaveManager.has_run():
				_failures.append("no saved run after save_run_snapshot")
			if not Game.continue_run():
				_failures.append("continue_run() returned false")
		3:
			var lv: Level = Game.level
			if lv == null:
				_failures.append("no level after continue")
			else:
				_cmp("room", lv.run.current_room, _expect.room)
				_cmp("relics", lv.run.relics, _expect.relics)
				_cmp("flame", lv.run.flame, _expect.flame)
				_cmp("sparks", lv.run.sparks, _expect.sparks)
				_cmp("entered_from", lv.run.entered_from, _expect.from)
				var lit_now := []
				for b in lv.room.braziers:
					if b.is_lit:
						lit_now.append(b.index)
				for i in _expect.lit:
					if not lit_now.has(int(i)):
						_failures.append("brazier %d not lit after continue" % int(i))
				_cmp("stats rebuilt", lv.run.stats.get_stat("shot_damage") > 10.0, true)
			print("CONTINUE_OK" if _failures.is_empty() else "CONTINUE_FAIL " + "; ".join(_failures))
			SaveManager.clear_run()
			get_tree().quit(0 if _failures.is_empty() else 1)
	_step += 1


func _cmp(label: String, got: Variant, want: Variant) -> void:
	if str(got) != str(want):
		_failures.append("%s: expected %s, got %s" % [label, str(want), str(got)])
