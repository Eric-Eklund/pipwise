extends SceneTree
## Headless test runner.
##
##     godot --headless --script res://tests/run_tests.gd
##
## Extending SceneTree is what makes that work: the script owns the main loop
## and can set the process exit code with quit(). Without a non-zero exit on
## failure, CI has no way to fail the build.

const SUITE_DIR := "res://tests/suites"

func _initialize() -> void:
	var suite_paths := _find_suites()
	if suite_paths.is_empty():
		push_error("No test suites found in %s" % SUITE_DIR)
		quit(1)
		return

	var total_passed := 0
	var all_failures : Array[String] = []

	for path in suite_paths:
		var script : GDScript = load(path)
		if script == null:
			all_failures.append("%s: failed to load" % path)
			continue
		var suite = script.new()
		if not suite is TestCase:
			all_failures.append("%s: does not extend TestCase" % path)
			continue

		var failures : Array[String] = suite.run()
		total_passed += suite.passed
		var suite_name := path.get_file().trim_suffix(".gd")
		if failures.is_empty():
			print("  PASS  %s (%d assertions)" % [suite_name, suite.passed])
		else:
			print("  FAIL  %s (%d passed, %d failed)" % [suite_name, suite.passed, failures.size()])
			for failure in failures:
				print("          %s" % failure)
				all_failures.append("%s :: %s" % [suite_name, failure])

	print("")
	if all_failures.is_empty():
		print("%d assertions passed across %d suites." % [total_passed, suite_paths.size()])
		quit(0)
	else:
		print("%d passed, %d FAILED." % [total_passed, all_failures.size()])
		quit(1)

func _find_suites() -> Array[String]:
	var paths : Array[String] = []
	var dir := DirAccess.open(SUITE_DIR)
	if dir == null:
		push_error("Cannot open %s" % SUITE_DIR)
		return paths
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("test_"):
			# Exported and .import'd projects report .gd as .gd.remap.
			paths.append("%s/%s" % [SUITE_DIR, file_name.trim_suffix(".remap")])
		file_name = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	return paths
