class_name ErrorCatcher
extends Logger
## Collects engine and script errors (Godot 4.5 Logger API) so automated
## checks can fail on them instead of only printing them. Warnings are ignored.

var errors: PackedStringArray = []
var _mutex := Mutex.new()


static func install() -> ErrorCatcher:
	var c := ErrorCatcher.new()
	OS.add_logger(c)
	return c


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_mutex.lock()
	errors.append("%s:%d (%s) %s %s" % [file, line, function, code, rationale])
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


func count() -> int:
	_mutex.lock()
	var n := errors.size()
	_mutex.unlock()
	return n


func summary(limit: int = 5) -> String:
	_mutex.lock()
	var out := " | ".join(errors.slice(0, limit))
	_mutex.unlock()
	return out
