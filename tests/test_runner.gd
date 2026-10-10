extends Node
## Headless test runner:
##   godot --headless --path . res://tests/test_runner.tscn
## Runs every test_*() method of every tests/test_*.gd suite, prints a
## summary and exits with code 1 if anything failed.

const SUITES := [
	"res://tests/test_generation.gd",
	"res://tests/test_room_layout.gd",
	"res://tests/test_stats.gd",
	"res://tests/test_save.gd",
	"res://tests/test_data.gd",
	"res://tests/test_gameplay.gd",
]


func _ready() -> void:
	# watchdog: a crashed or stuck suite must still end the process with failure
	get_tree().create_timer(240.0).timeout.connect(func():
		print("TIMEOUT: test run took too long")
		get_tree().quit(2))
	_run.call_deferred()


func _run() -> void:
	# tests must not touch the player's real profile
	SaveManager.profile = SaveManager.default_profile()
	var total_checks := 0
	var failures: Array[String] = []
	var tests_run := 0
	var t0 := Time.get_ticks_msec()
	for path in SUITES:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			failures.append("cannot load " + path)
			continue
		var suite: TestCase = script.new()
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			suite.begin("%s::%s" % [path.get_file().get_basename(), name])
			var before := suite.failures.size()
			suite.call(name)
			tests_run += 1
			var status := "ok" if suite.failures.size() == before else "FAIL"
			print("  [%s] %s" % [status, suite._current])
		total_checks += suite.checks
		failures.append_array(suite.failures)
	print("")
	print("%d tests, %d checks, %d failures (%d ms)" % [tests_run, total_checks, failures.size(), Time.get_ticks_msec() - t0])
	for f in failures:
		print("  FAILURE: " + f)
	get_tree().quit(1 if not failures.is_empty() else 0)
