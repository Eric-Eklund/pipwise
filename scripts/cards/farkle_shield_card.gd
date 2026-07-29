class_name FarkleShieldCard
extends Card
## Farkle Shield: the next roll that scores nothing costs you nothing.
##
## The only card that touches the bust, which makes it the only card that can
## change how hard a push is worth making. Bought *before* the roll it protects,
## because a card that undid a Farkle after seeing one would make pushing free
## and take the game's core with it — which is why it is the one card here that
## lasts the whole turn rather than the roll it was played on.
##
## It does not hand the roll back. There is still nothing on the table to take,
## so the turn is over either way; what the card buys is keeping what the turn
## had already earned.
##
## ## Why it saves the points and not only the penalty
##
## Read strictly, "a Farkle gives 0 instead of -100" is about
## `Ruleset.farkle_penalty` — and the campaign charges no penalty at all before
## level 6 (`Campaign.penalty_from_level`), so a card that only zeroed it would
## be bright, buyable and worth exactly nothing for the first half of a run.
## That is the dead-card trap deviation 8 of docs/DESIGN.md keeps recording. The
## turn's points are the thing a Farkle actually takes on every level, so those
## are what this protects, and the penalty goes with them:
## FarkleGame._farkle() banks the turn instead of losing it, so nothing is left
## for a penalty to be charged against.
##
## Spent the moment it does its job. Nothing outside a turn can see that — the
## turn ends on a Farkle either way — but get_active_cards() is read by the HUD
## and should not go on claiming a shield that has already been used.

func blocks_farkle() -> bool:
	return true
