class_name ExtraDieCard
extends Card
## Extra Die: one more die lands on the table, rolled, for the rest of the turn.
##
## The pool is the bag the player brought, so this is the one card that changes
## how many dice are in play. The die is lent rather than given —
## `DicePool.reset_turn()` takes it back at the turn boundary — because a die
## that outlived the turn it was bought for would quietly grow the bag for the
## rest of the level, and every target in `Campaign.TARGETS` was measured
## against six.
##
## ## What a seventh die costs you
##
## A straight and three pairs both want the whole table (FarkleScorer's
## WHOLE_SET_SIZE), so while the extra die is out neither can fire — seven dice
## are not six. That is the rule staying one rule rather than growing a special
## case, and it is worth knowing before playing this on a board showing five
## different faces. Set a die aside and the table is six again.

## How many dice may be on the table at once.
##
## Not a balance cap — it is the row. `DiceTray` floors a die at MIN_DIE_SIZE,
## so past a point the dice stop shrinking and the tray starts asking the board
## for more width than the screen has, which drags the whole layout off both
## edges. Nine 44px dice and their 8px gaps come to 460 of the board's 496; a
## tenth would not fit.
const MAX_DICE := 9

## Dice this puts on the table. One is the card; the export is here so that a
## future upgrade to it is data rather than a second class.
@export_range(1, 4) var count : int = 1

func can_play(game) -> bool:
	return game != null and game.get_pool().size() + count <= MAX_DICE

func get_refusal(_game) -> String:
	return "There is no room on the table for another die."

func on_played(game) -> void:
	for _i in count:
		# Typed rather than inferred: [param game] is untyped on purpose (see
		# Card.on_played), so nothing here knows what the pool hands back.
		var die : Die = game.get_pool().add_die(StarterDice.create_basic_d6())
		# Through the game's own seeded stream, like every other roll in the
		# engine: a fixed seed has to reproduce a run, cards included.
		die.roll(game.context.rng)
