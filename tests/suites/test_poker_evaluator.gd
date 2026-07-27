extends TestCase
## PokerHandEvaluator is a starting point rather than a commitment, so these
## tests are mostly characterisation: they record what the scoring currently
## does so a rebalance is a deliberate act, not an accident.

const C := CardData.CLUBS
const D := CardData.DIAMONDS
const H := CardData.HEARTS
const S := CardData.SPADES

var _evaluator : PokerHandEvaluator

func before_each() -> void:
	_evaluator = PokerHandEvaluator.new()

## specs are [rank, suit] pairs.
func _cards(specs : Array) -> Array[Card]:
	var result : Array[Card] = []
	for spec in specs:
		result.append(Card.new(CardData.create(spec[0], spec[1])))
	return result

func _classify(specs : Array) -> PokerHandEvaluator.Category:
	return _evaluator.classify(_cards(specs))

func _context() -> GameContext:
	var rng := RngService.new(21)
	return GameContext.new(Deck.new(DeckDefinition.create_standard_52(), rng), Hand.new(5), rng)

# --- categories ---------------------------------------------------------

func test_high_card() -> void:
	assert_eq(_classify([[2, C], [5, D], [9, H], [11, S], [13, C]]),
		PokerHandEvaluator.Category.HIGH_CARD)

func test_pair() -> void:
	assert_eq(_classify([[4, C], [4, D], [9, H], [11, S], [13, C]]),
		PokerHandEvaluator.Category.PAIR)

func test_two_pair() -> void:
	assert_eq(_classify([[4, C], [4, D], [9, H], [9, S], [13, C]]),
		PokerHandEvaluator.Category.TWO_PAIR)

func test_three_of_a_kind() -> void:
	assert_eq(_classify([[4, C], [4, D], [4, H], [9, S], [13, C]]),
		PokerHandEvaluator.Category.THREE_OF_A_KIND)

func test_full_house() -> void:
	assert_eq(_classify([[4, C], [4, D], [4, H], [9, S], [9, C]]),
		PokerHandEvaluator.Category.FULL_HOUSE)

func test_four_of_a_kind() -> void:
	assert_eq(_classify([[4, C], [4, D], [4, H], [4, S], [9, C]]),
		PokerHandEvaluator.Category.FOUR_OF_A_KIND)

func test_flush() -> void:
	assert_eq(_classify([[2, H], [5, H], [9, H], [11, H], [13, H]]),
		PokerHandEvaluator.Category.FLUSH)

func test_straight() -> void:
	assert_eq(_classify([[5, C], [6, D], [7, H], [8, S], [9, C]]),
		PokerHandEvaluator.Category.STRAIGHT)

func test_straight_flush() -> void:
	assert_eq(_classify([[5, H], [6, H], [7, H], [8, H], [9, H]]),
		PokerHandEvaluator.Category.STRAIGHT_FLUSH)

# --- straight edges -----------------------------------------------------

func test_ace_low_straight() -> void:
	assert_eq(_classify([[1, C], [2, D], [3, H], [4, S], [5, C]]),
		PokerHandEvaluator.Category.STRAIGHT, "A-2-3-4-5 is a wheel")

func test_ace_high_straight() -> void:
	assert_eq(_classify([[10, C], [11, D], [12, H], [13, S], [1, C]]),
		PokerHandEvaluator.Category.STRAIGHT, "10-J-Q-K-A is a broadway")

func test_duplicate_rank_is_never_a_straight() -> void:
	assert_eq(_classify([[2, C], [3, D], [4, H], [5, S], [5, C]]),
		PokerHandEvaluator.Category.PAIR, "a repeated rank breaks the run")

func test_gapped_run_is_not_a_straight() -> void:
	assert_eq(_classify([[2, C], [3, D], [4, H], [5, S], [7, C]]),
		PokerHandEvaluator.Category.HIGH_CARD)

func test_four_cards_cannot_be_a_straight() -> void:
	assert_eq(_classify([[5, C], [6, D], [7, H], [8, S]]),
		PokerHandEvaluator.Category.HIGH_CARD, "run_length is 5")

func test_four_cards_cannot_be_a_flush() -> void:
	assert_eq(_classify([[2, H], [5, H], [9, H], [11, H]]),
		PokerHandEvaluator.Category.HIGH_CARD, "run_length is 5")

## Straights are "the whole selection is one exact run", not "contains a run".
## This only becomes reachable once DrawExtraCardAction widens the hand past
## five, and it is pinned here so the choice stays visible.
func test_six_cards_containing_a_run_is_not_a_straight() -> void:
	assert_eq(_classify([[5, C], [6, D], [7, H], [8, S], [9, C], [13, D]]),
		PokerHandEvaluator.Category.HIGH_CARD)

# --- scoring ------------------------------------------------------------

func test_single_card_is_a_legal_play() -> void:
	assert_true(_evaluator.is_valid_play(_cards([[1, S]])),
		"is_valid_play is not overridden, so any non-empty selection plays")

func test_empty_selection_is_not_a_legal_play() -> void:
	assert_false(_evaluator.is_valid_play([] as Array[Card]))

func test_score_combines_category_and_card_values() -> void:
	# Pair of fours plus 9, J, K: 10 + (4+4+9+10+10) = 47.
	var score := _evaluator.evaluate(_cards([[4, C], [4, D], [9, H], [11, S], [13, C]]), _context())
	assert_eq(score.base_points, 47)
	assert_eq(score.label, "Pair")

func test_aces_are_worth_eleven() -> void:
	var score := _evaluator.evaluate(_cards([[1, S]]), _context())
	assert_eq(score.base_points, 16, "high card 5 + ace 11")

func test_face_cards_are_worth_ten() -> void:
	var score := _evaluator.evaluate(_cards([[13, S]]), _context())
	assert_eq(score.base_points, 15, "high card 5 + king 10")

func test_multiplier_comes_from_the_context() -> void:
	var context := _context()
	context.score_multiplier = 2.5
	var score := _evaluator.evaluate(_cards([[13, S]]), context)
	assert_almost_eq(score.multiplier, 2.5)
	assert_eq(score.total(), 38, "15 x 2.5 rounds to 38")

func test_empty_selection_scores_nothing() -> void:
	var score := _evaluator.evaluate([] as Array[Card], _context())
	assert_eq(score.base_points, 0)
	assert_false(score.is_scoring())

func test_classify_does_not_mutate_its_input() -> void:
	var cards := _cards([[10, C], [11, D], [12, H], [13, S], [1, C]])
	_evaluator.classify(cards)
	assert_eq(cards[4].data.rank, 1, "the ace must not be rewritten to 14")
