class_name Level
extends Control
## Base contract for every level in the game.
##
## LevelManager duck-types onto these three signals to drive level flow,
## so any scene that emits them plugs into the existing level system.

signal level_lost
signal level_won(level_path : String)
@warning_ignore("unused_signal")
signal level_changed(level_path : String)

## Optional path to the next level if using an open world level system.
## Left empty, LevelManager falls back to its SceneLister for the next level.
@export_file("*.tscn") var next_level_path : String

var level_state : LevelState

func _ready() -> void:
	level_state = GameState.get_level_state(scene_file_path)

## Call when the player clears the level.
func win() -> void:
	level_won.emit(next_level_path)

## Call when the player fails the level.
func lose() -> void:
	level_lost.emit()
