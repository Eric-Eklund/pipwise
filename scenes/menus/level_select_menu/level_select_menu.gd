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
	# guaranteed to be campaign order. Sorting by path restores it, which holds
	# as long as level files stay single-digit — level_10 would sort before
	# level_2.
	var paths : Array = game_state.level_states.keys()
	paths.sort()
	for entry in paths:
		var file_path := String(entry)
		var display_name := file_path.get_file().trim_suffix(".tscn")
		display_name = display_name.replace("_", " ").capitalize()
		level_buttons_container.add_item(display_name)
		level_paths.append(file_path)

func _on_level_buttons_container_item_activated(index: int) -> void:
	GameState.set_checkpoint_level_path(level_paths[index])
	level_selected.emit()

## MainMenu._open_sub_menu() connects this menu's `hidden` signal to its own
## close handler, so hiding is all it takes to go back. Needed on Android,
## where there is no Escape key to trigger ui_cancel.
func _on_back_button_pressed() -> void:
	hide()
