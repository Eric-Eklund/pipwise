extends Control

## Loads a simple ItemList node within a margin container. The list is built from
## the levels the player has reached, which GameState records in level_states.
## Activating a level updates the GameState's checkpoint and emits a signal.
## The main menu node will trigger a load action from that signal.

signal level_selected

@onready var level_buttons_container: ItemList = %LevelButtonsContainer
var level_paths : Array[String]

func _ready() -> void:
	add_levels_to_container()

## A fresh level list is propagated into the ItemList, and the file names cleaned.
func add_levels_to_container() -> void:
	level_buttons_container.clear()
	level_paths.clear()
	var game_state := GameState.get_or_create_state()
	# level_states is keyed in the order levels were first reached, which is not
	# campaign order. Sorting restores it, but it has to be done on the trailing
	# number rather than on the string: plain sorting puts level_10 before
	# level_2, which was harmless at five levels and is not at thirty.
	var paths : Array = game_state.level_states.keys()
	paths.sort_custom(_before)
	for entry in paths:
		var file_path := String(entry)
		var display_name := file_path.get_file().trim_suffix(".tscn")
		display_name = display_name.replace("_", " ").capitalize()
		level_buttons_container.add_item(display_name)
		level_paths.append(file_path)

## Orders two level paths by their trailing number, falling back to the path
## itself for anything that is not numbered.
func _before(first, second) -> bool:
	var first_number := _level_number(String(first))
	var second_number := _level_number(String(second))
	if first_number == second_number:
		return String(first) < String(second)
	return first_number < second_number

## The number in a name like "level_12.tscn", or -1 when there is none.
func _level_number(path : String) -> int:
	var name := path.get_file().trim_suffix(".tscn")
	var digits := ""
	for index in range(name.length() - 1, -1, -1):
		if not name[index].is_valid_int():
			break
		digits = name[index] + digits
	return int(digits) if digits.is_valid_int() else -1

func _on_level_buttons_container_item_activated(index: int) -> void:
	GameState.set_checkpoint_level_path(level_paths[index])
	level_selected.emit()

## MainMenu._open_sub_menu() connects this menu's `hidden` signal to its own
## close handler, so hiding is all it takes to go back. Needed on Android,
## where there is no Escape key to trigger ui_cancel.
func _on_back_button_pressed() -> void:
	hide()
