extends Node
## Player preferences (audio, video, accessibility, language, controls).
## Persisted in user://settings.cfg; validated and clamped on load.

const PATH := "user://settings.cfg"

const DEFAULTS := {
	"audio": {"master": 0.8, "music": 0.7, "sfx": 0.8},
	"video": {
		"fullscreen": false,
		"vsync": true,
		"integer_scale": false,
		"performance_mode": false,
		"show_fps": false,
	},
	"access": {
		"shake": 1.0,
		"reduce_flashes": false,
		"damage_numbers": true,
		"aim_assist": true,
		"enemy_outlines": false,
	},
	"game": {"language": ""},
}

## Default bindings. Keyboard entries use physical keycodes so WASD keeps
## its position on AZERTY/QWERTZ keyboards.
const ACTIONS := {
	"move_up": [{"key": KEY_W}, {"key": KEY_UP}, {"axis": JOY_AXIS_LEFT_Y, "dir": -1}],
	"move_down": [{"key": KEY_S}, {"key": KEY_DOWN}, {"axis": JOY_AXIS_LEFT_Y, "dir": 1}],
	"move_left": [{"key": KEY_A}, {"key": KEY_LEFT}, {"axis": JOY_AXIS_LEFT_X, "dir": -1}],
	"move_right": [{"key": KEY_D}, {"key": KEY_RIGHT}, {"axis": JOY_AXIS_LEFT_X, "dir": 1}],
	"aim_up": [{"axis": JOY_AXIS_RIGHT_Y, "dir": -1}],
	"aim_down": [{"axis": JOY_AXIS_RIGHT_Y, "dir": 1}],
	"aim_left": [{"axis": JOY_AXIS_RIGHT_X, "dir": -1}],
	"aim_right": [{"axis": JOY_AXIS_RIGHT_X, "dir": 1}],
	"shoot": [{"mouse": MOUSE_BUTTON_LEFT}, {"axis": JOY_AXIS_TRIGGER_RIGHT, "dir": 1}, {"joy": JOY_BUTTON_RIGHT_SHOULDER}],
	"melee": [{"mouse": MOUSE_BUTTON_RIGHT}, {"joy": JOY_BUTTON_X}],
	"dash": [{"key": KEY_SPACE}, {"joy": JOY_BUTTON_A}, {"axis": JOY_AXIS_TRIGGER_LEFT, "dir": 1}],
	"flare": [{"key": KEY_Q}, {"joy": JOY_BUTTON_Y}],
	"interact": [{"key": KEY_E}, {"joy": JOY_BUTTON_B}],
	"map": [{"key": KEY_TAB}, {"joy": JOY_BUTTON_BACK}],
	"pause": [{"key": KEY_ESCAPE}, {"joy": JOY_BUTTON_START}],
}

## Actions the player may rebind from the options menu (keyboard/mouse slot).
const REBINDABLE := ["move_up", "move_down", "move_left", "move_right", "shoot", "melee", "dash", "flare", "interact", "map"]

var data: Dictionary = {}
var bindings: Dictionary = {}  # action -> Array[Dictionary] (keyboard/mouse overrides)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all()


func get_value(section: String, key: String) -> Variant:
	return data.get(section, {}).get(key, DEFAULTS[section][key])


func set_value(section: String, key: String, value: Variant) -> void:
	data[section][key] = _sanitize(section, key, value)
	apply_all()
	Events.settings_changed.emit()


func load_settings() -> void:
	data = DEFAULTS.duplicate(true)
	bindings = {}
	var cfg := ConfigFile.new()
	var err := cfg.load(PATH)
	if err == OK:
		for section in DEFAULTS:
			for key in DEFAULTS[section]:
				if cfg.has_section_key(section, key):
					data[section][key] = _sanitize(section, key, cfg.get_value(section, key))
		if cfg.has_section("input"):
			for action in cfg.get_section_keys("input"):
				var v = cfg.get_value("input", action)
				if action in REBINDABLE and typeof(v) == TYPE_ARRAY:
					var clean: Array = []
					for e in v:
						if typeof(e) == TYPE_DICTIONARY and (e.has("key") or e.has("mouse")):
							clean.append(e)
					if not clean.is_empty():
						bindings[action] = clean
	elif err != ERR_FILE_NOT_FOUND:
		push_warning("Settings: could not read %s (error %d), using defaults" % [PATH, err])
	if str(data.game.language) == "":
		data.game.language = _detect_language()
	_rebuild_input_map()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for section in data:
		for key in data[section]:
			cfg.set_value(section, key, data[section][key])
	for action in bindings:
		cfg.set_value("input", action, bindings[action])
	var err := cfg.save(PATH)
	if err != OK:
		push_error("Settings: could not save %s (error %d)" % [PATH, err])


func _sanitize(section: String, key: String, value: Variant) -> Variant:
	var def = DEFAULTS[section][key]
	match typeof(def):
		TYPE_BOOL:
			return bool(value) if typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] else def
		TYPE_FLOAT:
			if typeof(value) in [TYPE_INT, TYPE_FLOAT]:
				return clampf(float(value), 0.0, 1.0)
			return def
		TYPE_STRING:
			if key == "language":
				return value if value in ["es", "en", ""] else ""
			return str(value)
	return def


func _detect_language() -> String:
	var loc := OS.get_locale_language()
	return "es" if loc == "es" else ("en" if loc != "" else "es")


func apply_all() -> void:
	TranslationServer.set_locale(str(data.game.language))
	Events.language_changed.emit()
	var root := get_tree().root if is_inside_tree() else null
	if DisplayServer.get_name() != "headless":
		var fs: bool = data.video.fullscreen
		var mode := DisplayServer.window_get_mode()
		if fs and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not fs and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data.video.vsync else DisplayServer.VSYNC_DISABLED)
	if root:
		root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if data.video.integer_scale else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	if has_node("/root/Audio"):
		get_node("/root/Audio").apply_volumes()


# --- Input ------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# F11 or Alt+Enter toggles fullscreen anywhere
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
			set_value("video", "fullscreen", not bool(get_value("video", "fullscreen")))
			save_settings()
			get_viewport().set_input_as_handled()


func _rebuild_input_map() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action, 0.25)
		var defs: Array = ACTIONS[action]
		var kbm: Array = bindings.get(action, [])
		for d in defs:
			var is_kbm: bool = d.has("key") or d.has("mouse")
			if is_kbm and not kbm.is_empty():
				continue
			InputMap.action_add_event(action, make_event(d))
		for d in kbm:
			InputMap.action_add_event(action, make_event(d))


static func make_event(d: Dictionary) -> InputEvent:
	if d.has("key"):
		var k := InputEventKey.new()
		k.physical_keycode = int(d.key)
		return k
	if d.has("mouse"):
		var m := InputEventMouseButton.new()
		m.button_index = int(d.mouse)
		return m
	if d.has("joy"):
		var j := InputEventJoypadButton.new()
		j.button_index = int(d.joy)
		return j
	var a := InputEventJoypadMotion.new()
	a.axis = int(d.axis)
	a.axis_value = float(d.dir)
	return a


static func event_to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return {"key": code}
	if ev is InputEventMouseButton:
		return {"mouse": ev.button_index}
	return {}


func rebind(action: String, ev: InputEvent) -> bool:
	var d := event_to_dict(ev)
	if d.is_empty() or not (action in REBINDABLE):
		return false
	# free the key from any other action so two actions never share it
	for other in REBINDABLE:
		if other != action and bindings.get(other, []).has(d):
			bindings[other].erase(d)
			if bindings[other].is_empty():
				bindings.erase(other)
	bindings[action] = [d]
	_rebuild_input_map()
	save_settings()
	return true


func reset_bindings() -> void:
	bindings.clear()
	_rebuild_input_map()
	save_settings()


func binding_label(action: String) -> String:
	var list: Array = bindings.get(action, [])
	if list.is_empty():
		for d in ACTIONS.get(action, []):
			if d.has("key") or d.has("mouse"):
				list = [d]
				break
	if list.is_empty():
		return "-"
	var d: Dictionary = list[0]
	if d.has("key"):
		var code := int(d.key)
		if DisplayServer.get_name() not in ["headless", "dummy"]:
			code = DisplayServer.keyboard_get_keycode_from_physical(code)
		var key_name := OS.get_keycode_string(code)
		var loc_key := "KEYNAME_" + key_name.to_upper().replace(" ", "_")
		var localized := tr(loc_key)
		return localized if localized != loc_key else key_name
	match int(d.mouse):
		MOUSE_BUTTON_LEFT:
			return tr("KEY_MOUSE_LEFT")
		MOUSE_BUTTON_RIGHT:
			return tr("KEY_MOUSE_RIGHT")
		MOUSE_BUTTON_MIDDLE:
			return tr("KEY_MOUSE_MIDDLE")
	return "M%d" % int(d.mouse)
