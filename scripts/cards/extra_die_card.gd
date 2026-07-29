class_name ExtraDieCard
extends Card
## Section 3.2's Extra Die, reworked into Second Wind: a die you already set
## aside comes back to the table and is rolled again.
##
## §3.2 asks for "+1 die this round" — a seventh die. The pool is fixed at what
## the bag holds and nothing grows it, so that card cannot be built without a
## temporary die that the tray, the energy budget and hot dice would all have to
## learn about. What is built instead is the nearest honest thing, and the name
## says so: the card is a second wind for a die, not an extra one. See the
## deviations section of docs/DESIGN.md.
##
## The id stays `extra_die`. It is what a saved hand stores, so renaming it would
## empty the hand of anyone mid-run; the display name is the part the player
## reads and the part that had to change.
##
## ## Why it rerolls
##
## Restoring alone hands the die back on the face it was set aside on — and it
## was set aside because that face scored. So the die arrived already scoring and
## could be taken a second time, which made this a "score one die twice" card
## wearing a dice card's name. Rolling it is what makes it a gamble again: the
## die can come back worth nothing.
##
## Nature is deliberately left alone. It restores on the old face, which is its
## own rule and its own balance — see ElementRules.dice_restored().

## Dice this brings back.
@export_range(1, 6) var count : int = 1

## Refused unless the turn would still have a die set aside afterwards.
##
## Two reasons, and the second is the load-bearing one. Nothing to give back is
## nothing to buy. And can_push() needs a commitment to roll against, so
## restoring the *last* set aside die would leave a board with nothing to take
## (the reroll may score nothing), nothing to push, and — on level 5, behind
## MinimumBankModifier — nothing to bank either. That is the dead board this
## project keeps a whole probe for, and the guard is cheaper than the escape.
func can_play(game) -> bool:
	return game != null and game.get_pool().set_aside_count() > count

func get_refusal(game) -> String:
	if game.get_pool().set_aside_count() == 0:
		return "Nothing set aside to bring back."
	return "The last die set aside has to stay, or there is nothing left to roll against."

func on_played(game) -> void:
	# Through the game's own seeded stream, like every other roll in the engine:
	# a fixed seed has to reproduce a run, cards included.
	for die in game.get_pool().restore(count):
		die.roll(game.context.rng)
