class_name ExtraDieCard
extends Card
## Section 3.2's Extra Die: one die comes back to the table.
##
## Reuses DicePool.restore(), which is what Nature already pays in, so a restored
## die behaves identically however it got there — it keeps the face it was set
## aside on and is rolled again on the next push.
##
## Worth more than it looks. Fewer dice on the table is the thing that makes a
## push dangerous, so buying one back is buying the turn a longer life rather
## than buying points.

## Dice this brings back.
@export_range(1, 6) var count : int = 1

## Nothing to give back when nothing has been set aside. Guarded rather than
## silently doing nothing, so the row can grey the card out instead of taking
## the energy for free.
func can_play(game) -> bool:
	return game != null and game.get_pool().set_aside_count() > 0

func on_played(game) -> void:
	game.get_pool().restore(count)
