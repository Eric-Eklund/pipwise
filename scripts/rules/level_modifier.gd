class_name LevelModifier
extends Resource
## A rule a boss level bends.
##
## Hooks take a GameContext and never a FarkleGame, so that a modifier held by a
## Ruleset cannot form a cyclic class_name reference back to it.
##
## Not abstract: every hook has a harmless default, so a modifier only overrides
## the one or two it actually cares about.
##
## A modifier carries no name or description. What the boss is called belongs to
## the Ruleset, because a boss can be nothing but a hard target and a themed bag
## — a twist with no modifier at all — and identity living on the modifier would
## leave that level unlabelled.

## Writes the modifier's effect into the level. Called once, before the first
## roll of the level.
func on_level_start(_context : GameContext) -> void:
	pass

## Called at the start of every turn, before the dice are rolled.
func on_turn_start(_context : GameContext) -> void:
	pass

## Narrows which of the dice in play the scorer is even shown. Returning fewer
## dice than it was given is how a boss says "only Fire counts" without the
## scorer ever learning that bosses exist.
##
## This runs *before* scoring, not after, so the dice it removes cannot appear
## inside a shape and then be pulled out of it — three dice of a broken straight
## are takeable-looking and worth nothing. Returning nothing turns the roll into
## a Farkle, which is exactly the threat a boss like that is supposed to be.
func filter_scorable(_context : GameContext, dice : Array[Die]) -> Array[Die]:
	return dice

## Whether the player is allowed to bank right now.
func can_bank(_context : GameContext) -> bool:
	return true

## What the player still has to do, e.g. "Reach 500 to bank". Empty when nothing
## is outstanding. Shown on the bank button while it is disabled.
func get_requirement_text(_context : GameContext) -> String:
	return ""
