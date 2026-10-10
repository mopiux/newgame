class_name HubPauseMenu
extends Control
## Pause menu of the plaza.

var _options: OptionsMenu
var _options_btn: Button


func _ready() -> void:
	var box := HubPanels.base_panel(self, Vector2(200, 0))
	box.add_child(UITheme.title_label(tr("PAUSE_TITLE"), 26))
	var resume := _button(box, tr("PAUSE_RESUME"), func(): queue_free())
	_options_btn = _button(box, tr("MENU_OPTIONS"), func():
		_options = OptionsMenu.new()
		_options.closed.connect(func():
			_options = null
			_options_btn.grab_focus())
		add_child(_options))
	_button(box, tr("MENU_MAIN"), func(): Game.goto_menu())
	_button(box, tr("MENU_QUIT"), func(): Game.quit_game())
	resume.grab_focus.call_deferred()


func _button(box: VBoxContainer, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func():
		Audio.ui("ui_select")
		cb.call())
	b.mouse_entered.connect(func(): b.grab_focus())
	box.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if _options == null and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		queue_free()
