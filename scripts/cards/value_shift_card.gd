class_name ValueShiftCard
extends Card
## Value Shift: one die moves a single pip, up or down.
##
## The cheapest way to say "that 2 should have been a 1". The direction is a
## choice the player arms before tapping, rather than something the card guesses
## — a card that silently flipped to whichever direction was legal would be a
## different card every time it was played.
##
## A die that cannot move the armed way is not offered: with "+1" armed a 6 is
## untappable, because there is no seventh face for it to land on. FarkleGame
## arms whichever direction has somewhere to go, so the card never opens onto a
## tray with nothing in it.
##
## The change sticks until the die is rolled again, which is all "permanent" can
## mean for a face: nothing here remembers that the die was shifted, and the
## next roll overwrites it like any other.

## The two directions, in the order the row draws them. The index the player
## armed is what FarkleGame hands back to on_target().
const CHOICES : Array[String] = ["+1", "−1"]
const DELTAS : Array[int] = [1, -1]

## Playable while any die is showing a face. Every value a d6 can show moves one
## way or the other, so this is exactly the condition under which some direction
## has a target — which is what FarkleGame.can_play() needs it to mean.
##
## Deliberately not the base class's check, which asks only about the direction
## currently armed. That is the right question once the card is waiting for a
## die and the wrong one before it is played: a board of six 6s would refuse a
## card that "−1" plays perfectly well.
func can_play(game) -> bool:
	for die in game.get_dice_in_play():
		if die.get_value() > 0:
			return true
	return false

func get_refusal(_game) -> String:
	return "Nothing on the table to shift."

func needs_target() -> bool:
	return true

func can_target(game, die : Die) -> bool:
	if die == null or die.get_value() <= 0:
		return false
	return die.can_show(die.get_value() + delta_for(game.get_target_choice()))

func target_prompt() -> String:
	return "Tap a die to shift it"

func target_choices() -> Array[String]:
	return CHOICES.duplicate()

func on_target(_game, die : Die, choice : int) -> void:
	die.set_value(die.get_value() + delta_for(choice))

## Which way an armed choice moves a die. Out of range answers +1, because a
## choice nobody made is the one the row opens on.
func delta_for(choice : int) -> int:
	if choice < 0 or choice >= DELTAS.size():
		return DELTAS[0]
	return DELTAS[choice]
