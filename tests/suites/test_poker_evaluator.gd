extends TestCase
## The scoring formula: (cards + dice) x hand multiplier.
##
## The shapes themselves are covered in test_poker_classifier. What is pinned
## here is the price of each shape and the fact that the dice ride along into
## the score rather than being consumed by it.

const S := CardData.SPADES
const H := CardData.HEARTS
const D := CardData.DIAMONDS
const C := CardData.CLUBS

var _evaluator : PokerHandEvaluator

func before_each() -> void:
	_evaluator = PokerHandEvaluator.new()

func _cards(specs : Array) -> Array[Card]:
	var cards : Array[Card] = []
	for spec in specs:
		cards.append(Card.new(CardData.create(spec[0], spec[1])))
	return cards

## A context whose dice show exactly [param dice_values].
func _context(dice_values : Array) -> GameContext:
	var rng := RngService.new(1)
	var definition := BagDefinition.new()
	for _i in dice_values.size():
		definition.dice.append(StarterDice.create_white_d6())
	var pool := DicePool.new(definition, rng)
	for i in dice_values.size():
		pool.dice[i].current_face = DieFace.create(&"fixed", int(dice_values[i]))
	return GameContext.new(
		Deck.new(DeckDefinition.create_standard_52(), rng), Hand.new(5), pool, rng
	)

# --- the spec's worked example ------------------------------------------

## The spec's headline number, 112, comes from a 35-point hand plus 21 on the
## dice, doubled by a pair. Its own example cards (7-K-K-9-3) actually come to
## 45, not 35, so this uses a hand that really does total 35 — K-K-4-3-2, still
## a pair.
func test_the_design_specs_worked_example() -> void:
	var cards := _cards([[13, S], [13, H], [4, D], [3, C], [2, S]])
	var score := _evaluator.evaluate(cards, _context([4, 2, 6, 1, 5, 3]))
	assert_eq(score.card_points, 35, "card values")
	assert_eq(score.dice_points, 21, "dice bonus")
	assert_eq(score.base_points(), 56)
	assert_almost_eq(score.multiplier, 2.0, 0.0001, "a pair")
	assert_eq(score.total(), 112)
	assert_eq(score.label, "Pair")

## The spec's example cards, scored as written. Kept alongside the one above so
## the arithmetic slip in the design document cannot quietly become a bug here.
func test_the_specs_example_cards_score_what_they_actually_add_up_to() -> void:
	var cards := _cards([[7, S], [13, H], [13, D], [9, C], [3, S]])
	var score := _evaluator.evaluate(cards, _context([4, 2, 6, 1, 5, 3]))
	assert_eq(score.card_points, 45)
	assert_eq(score.total(), (45 + 21) * 2)

# --- multipliers --------------------------------------------------------

func _multiplier_of(specs : Array) -> float:
	return _evaluator.evaluate(_cards(specs), _context([1, 1, 1, 1, 1, 1])).multiplier

func test_a_high_card_does_not_multiply() -> void:
	assert_almost_eq(_multiplier_of([[2, S], [5, H], [9, D], [11, C], [13, S]]), 1.0)

func test_a_pair_doubles() -> void:
	assert_almost_eq(_multiplier_of([[5, S], [5, H], [9, D], [11, C], [13, S]]), 2.0)

func test_a_two_pair_triples() -> void:
	assert_almost_eq(_multiplier_of([[5, S], [5, H], [11, D], [11, C], [13, S]]), 3.0)

func test_a_three_of_a_kind_quadruples() -> void:
	assert_almost_eq(_multiplier_of([[8, S], [8, H], [8, D], [11, C], [13, S]]), 4.0)

func test_a_straight_is_five() -> void:
	assert_almost_eq(_multiplier_of([[5, S], [6, H], [7, D], [8, C], [9, S]]), 5.0)

func test_a_flush_is_six() -> void:
	assert_almost_eq(_multiplier_of([[2, H], [5, H], [9, H], [11, H], [13, H]]), 6.0)

func test_a_full_house_is_eight() -> void:
	assert_almost_eq(_multiplier_of([[8, S], [8, H], [8, D], [11, C], [11, S]]), 8.0)

func test_a_four_of_a_kind_is_nine() -> void:
	assert_almost_eq(
		_multiplier_of([[8, S], [8, H], [8, D], [8, C], [11, S]]), 9.0, 0.0001,
		"between the full house and the straight flush, as in poker"
	)

func test_a_straight_flush_is_ten() -> void:
	assert_almost_eq(_multiplier_of([[5, H], [6, H], [7, H], [8, H], [9, H]]), 10.0)

# --- the dice -----------------------------------------------------------

func test_the_dice_are_added_before_the_multiplier() -> void:
	var cards := _cards([[5, S], [5, H], [2, D], [3, C], [4, S]])
	# 5+5+2+3+4 = 19 cards, 12 dice, pair x2.
	var score := _evaluator.evaluate(cards, _context([2, 2, 2, 2, 2, 2]))
	assert_eq(score.total(), (19 + 12) * 2)

func test_spending_energy_does_not_shrink_the_dice_bonus() -> void:
	var context := _context([6, 6, 6, 6, 6, 6])
	var cards := _cards([[5, S], [5, H], [2, D], [3, C], [4, S]])
	var before := _evaluator.evaluate(cards, context).dice_points
	context.spend_energy(12)
	var after := _evaluator.evaluate(cards, context).dice_points
	assert_eq(before, 36)
	assert_eq(after, 36, "the pips stay on the table after they are spent")

func test_the_score_multiplier_stacks_on_top() -> void:
	var context := _context([1, 1, 1, 1, 1, 1])
	context.score_multiplier = 1.5
	var score := _evaluator.evaluate(
		_cards([[5, S], [5, H], [9, D], [11, C], [13, S]]), context
	)
	assert_almost_eq(score.multiplier, 3.0, 0.0001, "a pair at x2, boosted by x1.5")

# --- boss hooks ---------------------------------------------------------

func test_a_banned_category_falls_back_to_the_next_best() -> void:
	var context := _context([1, 1, 1, 1, 1, 1])
	context.banned_categories = [PokerHandClassifier.Category.PAIR]
	var score := _evaluator.evaluate(
		_cards([[5, S], [5, H], [9, D], [11, C], [13, S]]), context
	)
	assert_eq(score.label, "High Card")
	assert_almost_eq(score.multiplier, 1.0)

func test_a_banned_category_leaves_a_better_shape_alone() -> void:
	var context := _context([1, 1, 1, 1, 1, 1])
	context.banned_categories = [PokerHandClassifier.Category.PAIR]
	var score := _evaluator.evaluate(
		_cards([[8, S], [8, H], [8, D], [11, C], [11, S]]), context
	)
	assert_eq(score.label, "Full House", "a full house is not scored as a pair")

func test_a_category_bonus_raises_only_that_shape() -> void:
	var context := _context([1, 1, 1, 1, 1, 1])
	context.category_bonuses = {PokerHandClassifier.Category.STRAIGHT: 0.5}
	var straight := _evaluator.evaluate(
		_cards([[5, S], [6, H], [7, D], [8, C], [9, S]]), context
	)
	var pair := _evaluator.evaluate(
		_cards([[5, S], [5, H], [9, D], [11, C], [13, S]]), context
	)
	assert_almost_eq(straight.multiplier, 7.5, 0.0001, "x5 plus 50%")
	assert_almost_eq(pair.multiplier, 2.0, 0.0001, "untouched")

# --- edges --------------------------------------------------------------

func test_an_empty_hand_scores_nothing() -> void:
	var empty : Array[Card] = []
	var score := _evaluator.evaluate(empty, _context([6, 6, 6, 6, 6, 6]))
	assert_eq(score.total(), 0, "not even the dice bonus")
	assert_false(score.is_scoring())

func test_a_hand_below_the_minimum_is_not_a_valid_play() -> void:
	_evaluator.minimum_cards = 4
	assert_false(_evaluator.is_valid_play(_cards([[5, S], [5, H], [9, D]])))
	assert_true(_evaluator.is_valid_play(_cards([[5, S], [5, H], [9, D], [11, C]])))

func test_the_breakdown_reads_the_way_the_hud_shows_it() -> void:
	var cards := _cards([[13, S], [13, H], [4, D], [3, C], [2, S]])
	var score := _evaluator.evaluate(cards, _context([4, 2, 6, 1, 5, 3]))
	assert_eq(score.breakdown_text(), "(35 + 21) x2 = 112")
