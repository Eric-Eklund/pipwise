class_name NatureRestoreCard
extends Card
## Section 3.3's Earth Restore: 🌿 Nature hands back two dice instead of one.
##
## Its own class rather than an ElementBoostCard, because Nature is one of the
## two elements that pays no points at all — it pays in dice. Doubling a bonus it
## never earns would have been doubling zero, which is exactly the trap section
## 3.3 walks into with Crystal Focus.
##
## Worth nothing without a Nature die on the table, and the row cannot know that
## for the player. That is deliberate: a potion for an element you did not bring
## is a bad draw, and Discard Swap is the answer to a hand of them.

## Added to what Nature already returns, so this stacks with the Nature trio
## rather than replacing it — three Nature dice and this card hand back four.
@export_range(1, 4) var extra_dice : int = 1

func dice_restored_bonus() -> int:
	return extra_dice
