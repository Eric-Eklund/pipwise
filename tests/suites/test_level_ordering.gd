extends TestCase
## Level select lists levels in campaign order.
##
## Worth its own suite because the old sort was correct for exactly as long as
## the game had fewer than ten levels, and the bug it hid — level_10 listed
## before level_2 — is invisible until the day it is not.

const MENU_SCRIPT := "res://scenes/menus/level_select_menu/level_select_menu.gd"

var _menu : Control

func before_each() -> void:
	_menu = (load(MENU_SCRIPT) as GDScript).new()

func after_each() -> void:
	if _menu != null:
		_menu.free()
		_menu = null

func _sorted(paths : Array) -> Array:
	var copy := paths.duplicate()
	copy.sort_custom(_menu._before)
	return copy

func _path(level : int) -> String:
	return "res://scenes/game_scene/levels/level_%d.tscn" % level

# --- reading the number -------------------------------------------------

func test_the_number_comes_off_the_file_name() -> void:
	assert_eq(_menu._level_number(_path(7)), 7)
	assert_eq(_menu._level_number(_path(30)), 30)

func test_a_level_without_a_number_sorts_last_resort() -> void:
	assert_eq(
		_menu._level_number("res://scenes/game_scene/levels/endless_level.tscn"), -1
	)

# --- the order ----------------------------------------------------------

func test_double_digit_levels_do_not_jump_the_queue() -> void:
	var sorted := _sorted([_path(10), _path(2), _path(1), _path(20), _path(3)])
	assert_eq(sorted[0], _path(1))
	assert_eq(sorted[1], _path(2))
	assert_eq(sorted[2], _path(3))
	assert_eq(sorted[3], _path(10))
	assert_eq(sorted[4], _path(20))

func test_a_full_campaign_comes_back_in_order() -> void:
	var shuffled : Array = []
	for level in range(30, 0, -1):
		shuffled.append(_path(level))
	var sorted := _sorted(shuffled)
	for index in 30:
		if sorted[index] != _path(index + 1):
			fail("position %d holds %s" % [index, sorted[index]])
			return
	assert_true(true, "all 30 levels in campaign order")

## Endless has no number, so it sorts ahead of the numbered levels rather than
## landing somewhere arbitrary among them. Pinned so the behaviour is a choice.
func test_an_unnumbered_level_sorts_before_the_numbered_ones() -> void:
	var endless := "res://scenes/game_scene/levels/endless_level.tscn"
	var sorted := _sorted([_path(2), endless, _path(1)])
	assert_eq(sorted[0], endless)
	assert_eq(sorted[1], _path(1))
	assert_eq(sorted[2], _path(2))
