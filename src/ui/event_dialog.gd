class_name EventDialog
extends Overlay
## Narrative encounter: text plus 2-3 choices with visible costs.

var event_id := ""
var altar: Node
var _box: VBoxContainer
var _resolved := false


func _ready() -> void:
	dim_background(0.6)
	var e: Dictionary = Database.events.get(event_id, {})
	_box = centered_panel(Vector2(340, 0))
	_box.add_child(UITheme.title_label(tr(str(e.get("title", event_id))), 24))
	var text := UITheme.label(tr(str(e.get("text", ""))), 12)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(320, 0)
	_box.add_child(text)
	_box.add_child(HSeparator.new())
	var first: Button = null
	var options: Array = e.get("options", [])
	for i in options.size():
		var opt: Dictionary = options[i]
		var b := make_button(tr(str(opt.get("text", "?"))), func(): _choose(opt))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(320, 0)
		if not EventSystem.can_choose(opt, level.run):
			b.disabled = true
			b.tooltip_text = tr("EVENT_CANT_AFFORD")
		_box.add_child(b)
		if first == null and not b.disabled:
			first = b
	if first:
		first.grab_focus.call_deferred()


func can_close() -> bool:
	# leaving without choosing is allowed: the altar stays usable
	return not _resolved


func _choose(opt: Dictionary) -> void:
	if _resolved:
		return
	_resolved = true
	var result_key := EventSystem.apply(opt, level.run, level.player, level.room)
	if altar and is_instance_valid(altar) and altar.has_method("finish"):
		altar.finish()
	for c in _box.get_children():
		c.queue_free()
	var t := UITheme.label(tr(result_key) if result_key != "" else tr("EVENT_DONE"), 12)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(320, 0)
	_box.add_child(t)
	var ok := make_button(tr("CONTINUE"), func(): level.close_overlay())
	_box.add_child(ok)
	ok.grab_focus.call_deferred()
	Game.save_run_snapshot()
