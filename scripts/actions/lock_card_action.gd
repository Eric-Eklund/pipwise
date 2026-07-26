class_name LockCardAction
extends DieAction
## Locks the selected cards so a redraw leaves them alone.

func can_apply(context : GameContext) -> bool:
	for card in context.hand.get_selected():
		if not card.is_locked:
			return true
	return false

func apply(context : GameContext) -> void:
	for card in context.hand.get_selected():
		card.is_locked = true
	context.hand.clear_selection()
