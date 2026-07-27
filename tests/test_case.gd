class_name TestCase
extends RefCounted
## Base class for the engine test suites.
##
## Deliberately tiny and dependency-free. gdUnit4 cannot be installed from the
## environment these tests were written in, and vendoring a framework that had
## never been run would have been worse than a harness small enough to read in
## one sitting.
##
## Assertions record failures rather than halting, so one broken expectation
## does not hide the rest of the suite.

var failures : Array[String] = []
var passed : int = 0

var _current : String = ""

## Runs every method named test_*. Returns the failure messages.
func run() -> Array[String]:
	failures.clear()
	passed = 0
	for method_name in _find_test_methods():
		_current = method_name
		before_each()
		call(method_name)
		after_each()
	return failures

## Override to build fixtures before each test.
func before_each() -> void:
	pass

## Override to tear down after each test.
func after_each() -> void:
	pass

## get_method_list() reports inherited methods more than once, so the names are
## deduplicated — otherwise every test would run repeatedly and the counts lie.
func _find_test_methods() -> Array[String]:
	var names : Array[String] = []
	for method in get_method_list():
		var method_name := String(method.get("name", ""))
		if method_name.begins_with("test_") and method_name not in names:
			names.append(method_name)
	names.sort()
	return names

# --- assertions ---------------------------------------------------------

func assert_true(value : bool, context : String = "") -> void:
	if value:
		passed += 1
	else:
		_fail("expected true", context)

func assert_false(value : bool, context : String = "") -> void:
	if not value:
		passed += 1
	else:
		_fail("expected false", context)

func assert_eq(actual, expected, context : String = "") -> void:
	if actual == expected:
		passed += 1
	else:
		_fail("expected %s, got %s" % [_show(expected), _show(actual)], context)

func assert_ne(actual, unexpected, context : String = "") -> void:
	if actual != unexpected:
		passed += 1
	else:
		_fail("expected anything but %s" % _show(unexpected), context)

func assert_almost_eq(actual : float, expected : float, tolerance : float = 0.0001, context : String = "") -> void:
	if absf(actual - expected) <= tolerance:
		passed += 1
	else:
		_fail("expected %f (+/- %f), got %f" % [expected, tolerance, actual], context)

func assert_null(value, context : String = "") -> void:
	if value == null:
		passed += 1
	else:
		_fail("expected null, got %s" % _show(value), context)

func assert_not_null(value, context : String = "") -> void:
	if value != null:
		passed += 1
	else:
		_fail("expected non-null", context)

func fail(message : String) -> void:
	_fail(message, "")

func _fail(message : String, context : String) -> void:
	var suffix := "" if context.is_empty() else "  (%s)" % context
	failures.append("%s: %s%s" % [_current, message, suffix])

func _show(value) -> String:
	if value == null:
		return "<null>"
	if value is String or value is StringName:
		return "\"%s\"" % value
	return str(value)
