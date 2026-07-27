class_name RedrawCardsAction
extends DieAction
## Replaces every unlocked card in the hand and deals back up to full.
##
## Pairs with LockCardAction: lock what is worth keeping, then redraw the rest.
## Locks clear on their own once a card leaves the hand, because Deck.discard
## resets the flag.

func can_apply(context : GameContext) -> bool:
	return not context.hand.get_unlocked().is_empty()

func apply(context : GameContext) -> void:
	var replaced := context.hand.get_unlocked()
	context.hand.remove(replaced)
	context.deck.discard(replaced)
	context.refill_hand()
