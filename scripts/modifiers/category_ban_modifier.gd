class_name CategoryBanModifier
extends LevelModifier
## Rules hand shapes out of play.
##
## A banned shape does not make the hand unplayable — the evaluator falls back
## to the next best thing the cards form, so a banned pair scores as a high
## card. That is what makes the ban bite: the hand still counts, it just counts
## for much less.
##
## Two bosses share this one class. Mirror Master bans the pair; Wild Card bans
## everything that depends on suit or sequence, which is the reading of "all
## cards are wild" that matches the spec's note that it makes flushes and
## straights harder rather than easier.

## PokerHandClassifier.Category values. Kept as plain ints because Godot cannot
## export a typed array of a foreign enum.
@export var banned : Array[int] = []

func on_level_start(context : GameContext) -> void:
	# Appended rather than assigned, so two modifiers can each ban something.
	for category in banned:
		if category not in context.banned_categories:
			context.banned_categories.append(category)
