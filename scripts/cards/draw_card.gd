class_name DrawCard
extends Card
## Section 3.2's Draw 2: two more cards.
##
## Cheap and almost never wrong, which is the point of a common — it is the card
## that teaches a new player that the row is worth looking at.
##
## Always playable, including on a full hand. The card leaves the hand before it
## takes effect, so drawing two into the gap it just made is a net gain of one
## even at the cap. Guarding on is_full() would have refused a play that is still
## worth making.

@export_range(1, 5) var count : int = 2

func on_played(game) -> void:
	game.hand.draw(count)
