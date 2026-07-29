class_name ForcedRerollCard
extends Card
## Forced Reroll: roll the table again without setting anything aside — and no
## banking until you do.
##
## The one card that spends the rule the whole game is built on. `can_push()`
## normally demands a commitment first, because rolling again for free is the
## one thing Farkle must never allow; this buys that roll once, and charges for
## it with the bank. A turn holding points cannot end while this is in force, so
## the reroll is never safe — it is the bet the rest of the game makes you earn.
##
## It lasts exactly until the dice move (Duration.ROLL), so the bank comes back
## the instant the player does what the card told them to. Nothing has to
## remember to lift it.
##
## The selection is cleared on the way in. `can_push()` refuses to roll over
## marked dice, so a card that granted the push and left three dice marked would
## have granted nothing until the player worked out which of their own taps was
## in the way.

## Refused when there is nothing left to roll, which is the moment before hot
## dice hands the table back.
func can_play(game) -> bool:
	return game != null and not game.get_pool().is_exhausted()

func get_refusal(_game) -> String:
	return "There is nothing left in play to roll."

func forces_reroll() -> bool:
	return true

func on_played(game) -> void:
	game.clear_selection()
