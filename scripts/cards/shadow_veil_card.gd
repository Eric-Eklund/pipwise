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

func farkle_pays() -> bool:
	return true
