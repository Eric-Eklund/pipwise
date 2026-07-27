class_name LevelModifier
extends Resource
## A rule a boss level bends.
##
## Modifiers configure the GameContext once, at level start, rather than being
## consulted on every evaluation. That keeps the evaluator ignorant of bosses:
## it reads banned categories and bonuses off the context and never learns why
## they are there. The only per-frame question a modifier answers is whether
## the player is allowed to save yet.
##
## Hooks take a GameContext and never a CardDiceGame, so that a modifier held
## by a Ruleset cannot form a cyclic class_name reference back to it.
##
## Not abstract: every hook has a harmless default, so a modifier only overrides
## the one or two it actually cares about.
##
## A modifier carries no name or description. What the boss is called belongs to
## the Ruleset, because Short Deck is a boss with no modifier at all — it is
## just a smaller hand — and identity that lives on the modifier would leave
## that level unlabelled.

## Writes the modifier's effect into the level: freeze dice, ban categories,
## grant category bonuses. Called once, after the opening roll, so that
## anything depending on what the dice show already has it.
func on_level_start(_context : GameContext) -> void:
	pass

## Whether the player has satisfied whatever this boss demands before the hand
## can be saved.
func can_save_hand(_context : GameContext) -> bool:
	return true

## What the player still has to do, e.g. "Lock at least 2 dice". Empty when
## nothing is outstanding. Shown on the save button when it is disabled.
func get_requirement_text(_context : GameContext) -> String:
	return ""
