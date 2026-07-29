class_name LockAllCard
extends Card
## Lock All: every scoring die is set aside and its points join the turn, in one
## tap.
##
## The cheap one, and the only card that presses a button the player already
## has. What it buys is the tap count on a busy board — six dice to mark, or
## this — and on a board where the best take is a *subset* it buys the answer to
## which dice those are, which is the one question the game asks that a new
## player reliably gets wrong.
##
## It takes the best selection rather than literally every scoring die, for the
## reason FarkleScorer.best_of() exists: adding a die that scores can lower the
## total, so "lock everything that scores" would sometimes hand the player less
## than the Take button standing next to it. A card must never be the worse of
## two buttons.
##
## Everything a normal take does follows from here — Nature handing dice back,
## hot dice, the level being won — because it goes through
## FarkleGame.commit_selection() rather than reaching into the pool itself.

## Refused when nothing on the table scores, which is a Farkle waiting to be
## acknowledged rather than a board to lock.
func can_play(game) -> bool:
	return game != null and not game.get_best_selection().is_empty()

func get_refusal(_game) -> String:
	return "Nothing on the table scores."

func on_played(game) -> void:
	game.select_all_scoring()
	game.commit_selection()
