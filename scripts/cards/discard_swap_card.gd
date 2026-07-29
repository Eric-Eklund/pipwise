class_name DiscardSwapCard
extends Card
## Section 3.2's Discard Swap: throw the hand away and draw the same number back.
##
## The answer to a hand full of potions for elements this level does not deal.
## Costs more than Draw 2 and can leave you worse off, which is what makes it a
## decision rather than a button.
##
## Plays out after the card itself has left the hand, so it never redraws itself
## and the swap is always one card smaller than the hand it was played from.

## Nothing to swap when this was the last card. Refused rather than allowed to
## spend energy on emptying an already empty hand.
func can_play(game) -> bool:
	return game != null and game.hand != null and game.hand.size() > 1

func get_refusal(_game) -> String:
	return "No other cards to swap."

func on_played(game) -> void:
	game.hand.swap_all()
