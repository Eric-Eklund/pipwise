class_name ElementLockModifier
extends LevelModifier
## Only dice of one element may be set aside. The Fire Lord's rule.
##
## Brutal by construction: two thirds of a scoring roll can become untakeable,
## and a roll where nothing of the right element scores is a Farkle even though
## the dice are covered in 1s. That is the fight — the level hands out a bag
## stacked with the element, and the player has to build the turn out of it.

@export var element : StringName = Element.FIRE

func filter_scorable(_context : GameContext, dice : Array[Die]) -> Array[Die]:
	var allowed : Array[Die] = []
	for die in dice:
		if die != null and die.element == element:
			allowed.append(die)
	return allowed

func get_requirement_text(_context : GameContext) -> String:
	return "Only %s dice score" % Element.get_label(element)
