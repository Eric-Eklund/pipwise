class_name Objective
extends Resource
## What a level asks the player to do, and when they have failed it.
##
## Abstract, even though score targets are the only kind so far. The cost is
## one small class; the alternative is refactoring the game loop the first
## time a level wants a combination goal or a checklist instead.

func is_met(_context : GameContext) -> bool:
	return false

func is_failed(_context : GameContext) -> bool:
	return false

## One line stating the goal, e.g. "Reach 300 points".
func get_description() -> String:
	return ""

## Short progress readout for the HUD, e.g. "120 / 300".
func get_progress_text(_context : GameContext) -> String:
	return ""
