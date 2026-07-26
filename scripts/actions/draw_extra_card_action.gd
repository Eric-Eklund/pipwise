class_name DrawExtraCardAction
extends DieAction
## Permanently widens the hand and fills the new slots.

@export_range(1, 5) var amount : int = 1

func can_apply(context : GameContext) -> bool:
	return not context.deck.is_exhausted()

func apply(context : GameContext) -> void:
	context.hand.max_size += amount
	context.refill_hand()
