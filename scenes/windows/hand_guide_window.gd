extends GameOverlay
## What each poker hand is worth on this level.
##
## Built from the level's own evaluator and context rather than from a written
## list, so it cannot drift from the scoring — and so a boss shows up in it. On
## Mirror Master the pair reads as blocked and the straight shows x7.5 rather
## than x5, which turns the twist from an unpleasant surprise into a plan.

const BANNED_COLOR := Color(0.55, 0.45, 0.48)
const BONUS_COLOR := Color(0.42, 0.85, 0.68)
const NORMAL_COLOR := Color(0.88, 0.90, 0.94)

## Weakest first, the order a player builds through.
const ORDER : Array[int] = [
	PokerHandClassifier.Category.HIGH_CARD,
	PokerHandClassifier.Category.PAIR,
	PokerHandClassifier.Category.TWO_PAIR,
	PokerHandClassifier.Category.THREE_OF_A_KIND,
	PokerHandClassifier.Category.STRAIGHT,
	PokerHandClassifier.Category.FLUSH,
	PokerHandClassifier.Category.FULL_HOUSE,
	PokerHandClassifier.Category.FOUR_OF_A_KIND,
	PokerHandClassifier.Category.STRAIGHT_FLUSH,
]

func show_hands(evaluator : HandEvaluator, context : GameContext) -> void:
	var poker := evaluator as PokerHandEvaluator
	if poker == null:
		# A level with a different evaluator has no table to show.
		add_line("This level scores by its own rules.", NORMAL_COLOR)
		return

	add_line(
		"Your score is (card values + dice pips) times the hand you make.",
		NORMAL_COLOR
	)
	for category in ORDER:
		_add_hand(poker, context, category)

func _add_hand(
	poker : PokerHandEvaluator, context : GameContext, category : int
) -> void:
	var name := PokerHandClassifier.category_name(category)
	if context.is_category_banned(category):
		add_row(name, "blocked", BANNED_COLOR)
		return

	var bonus := context.multiplier_bonus_for(category)
	var multiplier := poker.multiplier_for(category) * (1.0 + bonus)
	var text := _format(multiplier)
	if bonus > 0.0:
		add_row(name, "%s  (boosted)" % text, BONUS_COLOR)
	else:
		add_row(name, text, NORMAL_COLOR)

func _format(multiplier : float) -> String:
	if is_equal_approx(multiplier, roundf(multiplier)):
		return "x%d" % int(roundf(multiplier))
	return "x%.1f" % multiplier
