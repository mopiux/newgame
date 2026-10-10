extends Node
## Root node: hosts the active screen (menu, plaza, expedition) and the
## fade transition between them. Command-line flags for testing:
##   --start-run [seed]   jump straight into a new expedition
##   --hub                jump to the plaza
##   --bot                autopilot plays (see src/debug/autopilot.gd)
##   --tour DIR           screenshot every screen (see src/debug/screen_tour.gd)
##   --continue-check     end-to-end save / Continue check
##   --flow-check         end-to-end screen-flow check (see src/debug/flow_check.gd)


var screen_root: Node
var _fade: ColorRect
var _fade_layer: CanvasLayer
var _current: Node = null
var _pending: Node = null      # screen waiting for the fade-out to finish
var _busy := false


func _ready() -> void:
	screen_root = Node.new()
	screen_root.name = "Screen"
	add_child(screen_root)
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	_fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color("0b0a12")
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_layer.add_child(_fade)
	Game.main = self
	var args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if args.has("--flow-check"):
		var fc := FlowCheck.new()
		fc.name = "FlowCheck"
		add_child(fc)
		return
	if args.has("--continue-check"):
		var cc := ContinueCheck.new()
		cc.name = "ContinueCheck"
		add_child(cc)
		return
	if args.has("--tour"):
		var tour := ScreenTour.new()
		tour.name = "ScreenTour"
		var ti := args.find("--tour")
		tour.out_dir = args[ti + 1] if ti + 1 < args.size() else "user://tour"
		add_child(tour)
		return
	if args.has("--bot"):
		var bot := Autopilot.new()
		bot.name = "Autopilot"
		add_child(bot)
		if not args.has("--start-run"):
			Game.new_run(bot.bot_lantern, "BOT1", bot.bot_ascension)
			return
	if args.has("--start-run"):
		var i := args.find("--start-run")
		var seed_text := args[i + 1] if i + 1 < args.size() and not args[i + 1].begins_with("--") else ""
		Game.new_run("oil", seed_text, 0)
	elif args.has("--hub"):
		Game.goto_hub()
	else:
		Game.goto_menu()


func _exit_tree() -> void:
	UITheme.clear_cache()
	RoomArt.clear_cache()
	RelicIcons.clear_cache()


func show_screen(node: Node) -> void:
	if _busy:
		if _pending != null:
			# still fading out: the newest request replaces the queued screen,
			# so what is shown always matches Game.level / Game.run
			_pending.queue_free()
			_pending = node
		else:
			# already fading in: swap immediately
			_swap(node)
		return
	_busy = true
	_pending = node
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = false
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _current != null:
		tw.tween_property(_fade, "color:a", 1.0, 0.25)
	else:
		_fade.color.a = 1.0
	tw.tween_callback(func():
		var next := _pending
		_pending = null
		_swap(next))
	tw.tween_property(_fade, "color:a", 0.0, 0.35)
	tw.tween_callback(func():
		_busy = false
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE)


func _swap(node: Node) -> void:
	if _current and is_instance_valid(_current):
		_current.queue_free()
	_current = node
	screen_root.add_child(node)


## Quick fade used by in-level room transitions.
func flash_fade(midpoint: Callable, out_time: float = 0.12, in_time: float = 0.18) -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "color:a", 1.0, out_time)
	tw.tween_callback(midpoint)
	tw.tween_property(_fade, "color:a", 0.0, in_time)
