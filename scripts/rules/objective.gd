class_name Objective
extends Resource
## What a level asks the player to do.
##
## Abstract, even though score targets are the only kind so far. The cost is one
## small class; the alternative is refactoring the game loop the first time a
## level wants a specific hand shape instead of a number.
##
## There is no is_failed(). One level is one hand, so there is exactly one
## verdict: the game asks is_met() once, after the hand is saved, and anything
## else is a loss. A separate failure test would have to lie for the whole time
## the player is still deciding.

func is_met(_context : GameContext) -> bool:
	return false

## One line stating the goal, e.g. "Reach 300 points".
func get_description() -> String:
	return ""

## Short progress readout for the HUD, e.g. "120 / 300". Reads the live score,
## so it updates as the player swaps cards and rerolls.
func get_progress_text(_context : GameContext) -> String:
	return ""
