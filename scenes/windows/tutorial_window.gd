extends GameOverlay
## The walkthrough, shown once on the first level.
##
## Four lines, in the order the player will do them. The costs are written out
## rather than read from the ruleset because level 1 is where this appears and
## level 1 never changes them — and a walkthrough that says "3⚡" is easier to
## trust than one that says "the current swap cost".

const HEADING_COLOR := Color(0.98, 0.83, 0.36)
const BODY_COLOR := Color(0.84, 0.87, 0.92)

func _ready() -> void:
	super()
	_step("1 · You get one hand", "Five cards and six dice. Clear the target with them and the level is won. There is no second hand.")
	_step("2 · The dice are money", "Their pips add up to your energy — and the same pips are added to your score. Spending energy does not cost you points.")
	_step("3 · Tap cards to swap", "Tap a card to mark it, then press Swap. 3⚡ each. Cards that are earning you points are framed in green.")
	_step("4 · Tap dice to keep them", "Tap a die to lock it for 4⚡, then Reroll to shake the rest. Three rerolls, free — but a worse roll takes energy back.")
	add_line("Press ? at the top any time to see what each hand pays.", BODY_COLOR)

func _step(heading : String, body : String) -> void:
	add_line(heading, HEADING_COLOR)
	add_line(body, BODY_COLOR)
