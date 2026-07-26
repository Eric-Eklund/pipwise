class_name LevelState
extends Resource
## Per-level save data.
##
## A key is created in GameState.level_states the first time a level is
## reached, so the presence of a LevelState is what unlocks the level.

## Highest score the player has reached on this level.
@export var best_score : int = 0
## Whether the level's objective has been met at least once.
@export var completed : bool = false
## Whether the level's tutorial has already been shown.
@export var tutorial_read : bool = false
