class_name ShadowVeilCard
extends Card
## Section 3.3's Shadow Veil, reworked: a Farkle *pays* this turn instead of
## costing.
##
## The document says "+100% Farkle points", which is nothing at all in this
## build: a Farkle costs points, it does not pay them, unless three Shadow dice
## are already on the table. Doubling a reward that does not exist is doubling
## zero, so the card grants the Shadow trio's effect on demand instead. See the
## deviations section of docs/DESIGN.md.
##
## Reads as the reckless twin of Shield. Shield keeps a bust from taking the
## turn; this one makes the bust worth having. Both are bought before the roll.
##
## ## Why this potion is not guarded on its element and the others are
##
## It carries Element.SHADOW for its name and its colour, and for nothing else.
## The four boost potions and Earth Restore multiply what a die of their element
## earns, so on a board without one they multiply zero and are refused. This one
## grants the Shadow trio's effect outright — ElementRules.farkle_penalty()
## checks the card before it checks the dice — so it works on a board with no
## Shadow die anywhere, and refusing it there would be taking a working card off
## the player.

func farkle_pays() -> bool:
	return true
