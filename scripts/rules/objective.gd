class_name Objective
extends Resource
## What a level asks the player to do.
##
## Abstract, even though score targets are the only kind so far. The cost is one
## small class; the alternative is refactoring the game loop the first time a
## level wants something other than a number — "bank three turns in a row", "do
## it without a Farkle", "score 2000 in a single turn".
##
## A level used to be one hand, so there was one verdict and no is_failed(). A
## level is many turns now, which splits it in two, and the two are asked at
## different moments: is_met() after every bank, because the moment it is true
## the level is over and the player should not have to keep playing; is_failed()
## at the end of a turn, because running out of turns is how a level is lost and
## only the objective knows whether what remains could still be enough.

## Whether the player has done it. Asked after every bank, so it reads the
## *banked* score and never the projected one — points still riding on a turn
## are not points won.
func is_met(_context : GameContext) -> bool:
	return false

## Whether the level is out of reach. Asked at the end of a turn, after is_met.
func is_failed(_context : GameContext) -> bool:
	return false

## One line stating the goal, e.g. "Reach 1500 points".
func get_description() -> String:
	return ""

## The number that is counting up. Split out from the text so the HUD can
## *animate* it — a score that snaps from 400 to 3150 is a number, and one that
## rolls up to 3150 is an event. The HUD cannot tween a string.
func get_progress_value(_context : GameContext) -> int:
	return 0

## What that number is counting towards, or 0 for an objective with no fixed
## goal. Endless has one per round; a future "bank three turns running" would
## not.
func get_progress_goal() -> int:
	return 0

## Renders a progress value the way this objective wants it read. Takes the
## value rather than the context, so the HUD can format a half-finished tween
## step and not only the true current score.
func format_progress(value : int) -> String:
	return str(value)

## Short progress readout for the HUD, e.g. "1200 / 1500". Reads the live score,
## so it moves while the player is still deciding whether to push.
func get_progress_text(context : GameContext) -> String:
	return format_progress(get_progress_value(context))

## How close the player is, 0 to 1, for a progress bar. Zero for an objective
## that cannot express itself as a fraction.
func get_progress_ratio(_context : GameContext) -> float:
	return 0.0
