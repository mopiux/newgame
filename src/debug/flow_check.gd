class_name FlowCheck
extends Node
## End-to-end check of screen flows that unit tests cannot reach: rapid
## double presses during the screen fade, starting an expedition from the
## well panel, locked lanterns and menu focus after Options. Fails on any
## engine or script error logged while it runs.
##   godot --headless --path . -- --flow-check

var _step := 0
var _t := 0.0
var _runs_before := 0
var _failures: Array[String] = []
var _catcher: ErrorCatcher


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_catcher = ErrorCatcher.install()
	SaveManager.reset_profile()
	Game.goto_menu()


func _process(delta: float) -> void:
	_t += delta
	if _t < 1.2:
		return
	_t = 0.0
	match _step:
		0:
			# double press of Start while the fade is running
			_runs_before = int(SaveManager.profile.stats.runs)
			Game.new_run("oil", "FLOWA", 0)
			Game.new_run("oil", "FLOWB", 0)
		1:
			_check(Game.level != null and Game.level.is_inside_tree(), "level shown after double start")
			_check(Game.main._current == Game.level, "screen shown is Game.level")
			_check(Game.level != null and Game.level.run == Game.run, "level plays Game.run")
			_check(int(SaveManager.profile.stats.runs) == _runs_before + 1, "double start counted once")
			# leave for the plaza and, mid-fade, ask for another expedition
			Game.goto_hub()
			Game.new_run("oil", "FLOWC", 0)
		2:
			_check(Game.main._current == Game.level, "latest request wins (expedition)")
			# back to the plaza: open the well panel there
			Game.goto_hub()
		3:
			var hub := Game.main._current as Hub
			if not _check(hub != null and Game.level == null, "plaza shown"):
				_finish()
				return
			var panel := ExpeditionPanel.new()
			hub.open_panel(panel)
		4:
			var hub := Game.main._current as Hub
			var panel := hub._panel as ExpeditionPanel
			if not _check(panel != null, "expedition panel open"):
				_finish()
				return
			for b in panel._lantern_box.get_children():
				var btn := b as Button
				if btn.disabled:
					_check(btn.focus_mode == Control.FOCUS_NONE, "locked lantern cannot take focus")
				else:
					btn.grab_focus()
			_check(panel._lantern == "oil", "focus alone does not change the lantern")
			# start straight from the panel: the plaza is freed with it open
			panel._go()
		5:
			_check(Game.level != null and Game.level.is_inside_tree(), "expedition started from the panel")
			_check(Game.run != null and Game.run.lantern_id == "oil", "only an unlocked lantern is used")
			_check(not get_tree().paused, "not paused after leaving the plaza")
			Game.level.open_pause()
		6:
			var pause := Game.level._overlay as PauseMenu
			if not _check(pause != null, "pause menu open"):
				_finish()
				return
			pause._open_options()
			pause._options._close()
			_check(get_viewport().gui_get_focus_owner() == pause._options_btn, "focus returns to Options after closing it")
			pause._confirm_abandon()
		7:
			var pause := Game.level._overlay as PauseMenu
			var box: PauseMenu.ConfirmBox = null
			for c in pause.get_children():
				if c is PauseMenu.ConfirmBox:
					box = c
			if _check(box != null, "confirm box open"):
				box._cancel()
				_check(get_viewport().gui_get_focus_owner() == pause._options_btn, "focus returns after cancelling a confirm box")
			Game.level.close_overlay()
		8:
			_finish()
			return
	_step += 1


func _check(cond: bool, label: String) -> bool:
	if not cond:
		_failures.append(label)
	return cond


func _finish() -> void:
	if _catcher.count() > 0:
		_failures.append("%d errors logged: %s" % [_catcher.count(), _catcher.summary()])
	print("FLOW_OK" if _failures.is_empty() else "FLOW_FAIL " + "; ".join(_failures))
	SaveManager.clear_run()
	set_process(false)
	get_tree().quit(0 if _failures.is_empty() else 1)
