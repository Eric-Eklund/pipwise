class_name ShieldCard
extends Card
## Section 3.2's Shield: a roll that scores nothing does not end the turn.
##
## The only card that touches the bust, which makes it the only card that can
## change how hard a push is worth making. Played *before* the roll it protects,
## because a card that undid a Farkle after seeing one would make pushing free
## and take the game's core with it.
##
## It does not stop the roll from being a dead end — there is still nothing to
## take. It stops the turn's points from going, so the player can bank what they
## already had instead of losing it.

func blocks_farkle() -> bool:
	return true
