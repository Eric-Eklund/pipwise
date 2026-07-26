class_name RedrawCardsAction
extends DieAction
## Discards the selected cards and draws replacements.
##
## Requires a selection, so the player chooses what to throw away rather than
## the die deciding for them.

func can_apply(context : GameContext) -> bool:
	return context.hand.selected_count() > 0

func apply(context : GameContext) -> void:
	var replaced := context.hand.take_selected()
	context.deck.discard(replaced)
	context.refill_hand()
