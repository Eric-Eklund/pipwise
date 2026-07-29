class_name ValueConverterCard
extends Card
## Value Converter: a die that scores nothing becomes a 1 or a 5, and which one
## is not up to you.
##
## The dead-roll card. Value Shift moves a die one pip and asks the player to
## have done the arithmetic; this one takes any wasted die and makes it count,
## which is what a 2-3-4-6-6-2 board actually needs.
##
## ## Why it is random, and why that is the price
##
## A chosen 1 would be strictly better than a chosen 5 every time, so choosing
## would make the choice a formality and the card a flat 100 points. Rolling
## between them is what keeps it a gamble, and it is the same argument the whole
## game runs on. The roll goes through the game's seeded stream like every other
## one, so a fixed seed still reproduces the run.
##
## Only a non-scoring die may be picked. Converting a die that already scores
## would be paying four energy to move a 1 to a 5, and offering it would invite
## exactly that.

## What a converted die can land on, and how likely each is. Even odds: a 1 is
## worth twice a 5, so weighting it would be paying for the good half twice.
const VALUES : Array[int] = [1, 5]

func needs_target() -> bool:
	return true

## A die is offered when it is on the table, is not already scoring, and has a
## face this could turn it to.
##
## "Not scoring" is asked of FarkleGame's cache rather than of the die, because
## what scores depends on the whole board — a lone 2 is dead, and the third 2 of
## a triple is not.
func can_target(game, die : Die) -> bool:
	if die == null or die.is_set_aside or die in game.get_scorable_dice():
		return false
	for value in VALUES:
		if die.can_show(value):
			return true
	return false

func target_prompt() -> String:
	return "Tap a die that scores nothing"

func get_refusal(_game) -> String:
	return "Every die on the table already scores."

func on_target(game, die : Die, _choice : int) -> void:
	var choices : Array[int] = []
	for value in VALUES:
		if die.can_show(value):
			choices.append(value)
	if choices.is_empty():
		return
	die.set_value(choices[game.context.rng.randi_range(0, choices.size() - 1)])
