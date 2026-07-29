class_name NatureRestoreCard
extends Card
## Section 3.3's Earth Restore: 🌿 Nature hands back two dice instead of one.
##
## Its own class rather than an ElementBoostCard, because Nature is one of the
## two elements that pays no points at all — it pays in dice. Doubling a bonus it
## never earns would have been doubling zero, which is exactly the trap section
## 3.3 walks into with Crystal Focus.
##
## Worth nothing without a Nature die on the table, and it is now refused there
## rather than sold. This comment used to argue the opposite — that a potion for
## an element you did not bring is a bad draw and Discard Swap is the answer to a
## hand of them. It still is a bad draw. What the argument missed is that Nature
## arrives on level 7, so for six levels this card was bright, buyable and worth
## exactly nothing, and spending on it looked like the card system being broken.
## Refusing it costs the player nothing: the card waits in hand for the level
## where it works.

## Added to what Nature already returns, so this stacks with the Nature trio
## rather than replacing it — three Nature dice and this card hand back four.
@export_range(1, 4) var extra_dice : int = 1

## ElementRules.dice_restored() returns zero outright unless a Nature die scored,
## so this adds to nothing on a board without one.
func can_play(game) -> bool:
	return _element_is_in_play(game)

func get_refusal(_game) -> String:
	return "No %s dice on the table." % Element.get_label(element)

func dice_restored_bonus() -> int:
	return extra_dice
