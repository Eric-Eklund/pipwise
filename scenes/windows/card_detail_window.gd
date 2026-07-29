extends GameOverlay
## One card, explained, opened by holding it down in the row.
##
## The row has exactly two things it can say about a card: full brightness or
## greyed out. On a phone there is no hover to explain the difference, so the
## explanation has to be something a thumb can ask for — and the question a
## greyed card raises is never "what does this do", it is "why will it not go".
## That sentence is the reason this window exists; the rest is context around it.
##
## Built from the card and the live game rather than from written copy, the same
## way the scoring guide is, so it cannot describe a rule the level does not have.

const NORMAL_COLOR := Color(0.88, 0.90, 0.94)
const MUTED_COLOR := Color(0.62, 0.66, 0.72)
## The refusal line. The same red the board uses for a Farkle, because both are
## the game saying no.
const REFUSED_COLOR := Color(0.90, 0.44, 0.36)

func show_card(card : Card, game : FarkleGame) -> void:
	if card == null:
		return
	# The name carries the card's own colour rather than sitting in the overlay's
	# title, which is one flat style for every window. A potion is looked for by
	# its element, and this is the one place it can be shown at full size.
	add_row(card.get_label(), "%d⚡" % card.energy_cost, card.get_color())
	add_line(card.description, NORMAL_COLOR)

	# What the element itself does, for the potions. A player holding down Frost
	# Shield on a board with no Ice is not only asking why it is greyed out —
	# they are asking what Ice was for.
	if card.element != Element.NONE:
		add_line(
			"%s — %s" % [Element.get_label(card.element), Element.get_description(card.element)],
			MUTED_COLOR
		)

	var refusal := game.get_card_refusal(card) if game != null else ""
	if not refusal.is_empty():
		add_line(refusal, REFUSED_COLOR)
