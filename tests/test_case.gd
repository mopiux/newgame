class_name TestCase
extends RefCounted
## Minimal assertion helpers for the headless test runner.

var failures: Array[String] = []
var checks := 0
var _current := ""


func begin(test_name: String) -> void:
	_current = test_name


func check(cond: bool, msg: String = "") -> bool:
	checks += 1
	if not cond:
		failures.append("%s: %s" % [_current, msg])
	return cond


func eq(a: Variant, b: Variant, msg: String = "") -> bool:
	return check(a == b, "%s (expected %s, got %s)" % [msg, str(b), str(a)])


func near(a: float, b: float, eps: float = 0.001, msg: String = "") -> bool:
	return check(absf(a - b) <= eps, "%s (expected %f, got %f)" % [msg, b, a])
