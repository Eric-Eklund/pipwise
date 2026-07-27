extends TestCase
## Characterisation tests for hand shapes and card values.
##
## These were written against the old evaluator and moved here when scoring and
## classification were split. The shapes have not changed and neither have the
## expectations — only the card values did, and those are pinned below.

func _cards(specs : Array) -> Array[Card]:
	var cards : Array[Card] = []
	for spec in specs:
		cards.append(Card.new(CardData.create(spec[0], spec[1])))
	return cards

const S := CardData.SPADES
const H := CardData.HEARTS
const D := CardData.DIAMONDS
const C := CardData.CLUBS

func _classify(specs : Array) -> int:
	return PokerHandClassifier.classify(_cards(specs))

# --- card values --------------------------------------------------------

func test_an_ace_is_the_highest_card() -> void:
	assert_eq(PokerHandClassifier.card_value(1), 14, "ace is stored as rank 1")

func test_face_cards_are_worth_their_rank() -> void:
	assert_eq(PokerHandClassifier.card_value(11), 11, "jack")
	assert_eq(PokerHandClassifier.card_value(12), 12, "queen")
	assert_eq(PokerHandClassifier.card_value(13), 13, "king")

func test_number_cards_are_worth_their_pips() -> void:
	assert_eq(PokerHandClassifier.card_value(2), 2)
	assert_eq(PokerHandClassifier.card_value(10), 10)

func test_card_value_sum_adds_the_whole_hand() -> void:
	# The design spec's worked example is 7 + K + K + 9 + 3, which it totals as
	# 35. That is an arithmetic slip in the spec — the cards come to 45. The
	# formula is what matters, so the formula is what is pinned.
	var cards := _cards([[7, S], [13, H], [13, D], [9, C], [3, S]])
	assert_eq(PokerHandClassifier.card_value_sum(cards), 45)

func test_card_value_sum_counts_an_ace_as_fourteen() -> void:
	var cards := _cards([[1, S], [2, H]])
	assert_eq(PokerHandClassifier.card_value_sum(cards), 16)

# --- shapes -------------------------------------------------------------

func test_five_unrelated_cards_are_a_high_card() -> void:
	assert_eq(
		_classify([[2, S], [5, H], [9, D], [11, C], [13, S]]),
		PokerHandClassifier.Category.HIGH_CARD
	)

func test_two_matching_ranks_are_a_pair() -> void:
	assert_eq(
		_classify([[5, S], [5, H], [9, D], [11, C], [13, S]]),
		PokerHandClassifier.Category.PAIR
	)

func test_two_matching_ranks_twice_are_a_two_pair() -> void:
	assert_eq(
		_classify([[5, S], [5, H], [11, D], [11, C], [13, S]]),
		PokerHandClassifier.Category.TWO_PAIR
	)

func test_three_matching_ranks_are_a_three_of_a_kind() -> void:
	assert_eq(
		_classify([[8, S], [8, H], [8, D], [11, C], [13, S]]),
		PokerHandClassifier.Category.THREE_OF_A_KIND
	)

func test_five_consecutive_ranks_are_a_straight() -> void:
	assert_eq(
		_classify([[5, S], [6, H], [7, D], [8, C], [9, S]]),
		PokerHandClassifier.Category.STRAIGHT
	)

func test_a_straight_may_be_out_of_order() -> void:
	assert_eq(
		_classify([[9, S], [6, H], [8, D], [5, C], [7, S]]),
		PokerHandClassifier.Category.STRAIGHT
	)

func test_an_ace_can_run_low() -> void:
	assert_eq(
		_classify([[1, S], [2, H], [3, D], [4, C], [5, S]]),
		PokerHandClassifier.Category.STRAIGHT
	)

func test_an_ace_can_run_high() -> void:
	assert_eq(
		_classify([[10, S], [11, H], [12, D], [13, C], [1, S]]),
		PokerHandClassifier.Category.STRAIGHT
	)

func test_ranks_do_not_wrap_around_the_ace() -> void:
	assert_eq(
		_classify([[12, S], [13, H], [1, D], [2, C], [3, S]]),
		PokerHandClassifier.Category.HIGH_CARD,
		"Q-K-A-2-3 is not a run"
	)

func test_five_of_one_suit_are_a_flush() -> void:
	assert_eq(
		_classify([[2, H], [5, H], [9, H], [11, H], [13, H]]),
		PokerHandClassifier.Category.FLUSH
	)

func test_four_of_one_suit_are_not_a_flush() -> void:
	assert_eq(
		_classify([[2, H], [5, H], [9, H], [11, H]]),
		PokerHandClassifier.Category.HIGH_CARD,
		"a flush needs run_length cards"
	)

func test_three_plus_two_are_a_full_house() -> void:
	assert_eq(
		_classify([[8, S], [8, H], [8, D], [11, C], [11, S]]),
		PokerHandClassifier.Category.FULL_HOUSE
	)

func test_four_matching_ranks_are_a_four_of_a_kind() -> void:
	assert_eq(
		_classify([[8, S], [8, H], [8, D], [8, C], [11, S]]),
		PokerHandClassifier.Category.FOUR_OF_A_KIND
	)

func test_a_run_in_one_suit_is_a_straight_flush() -> void:
	assert_eq(
		_classify([[5, H], [6, H], [7, H], [8, H], [9, H]]),
		PokerHandClassifier.Category.STRAIGHT_FLUSH
	)

func test_an_empty_hand_classifies_as_a_high_card() -> void:
	var empty : Array[Card] = []
	assert_eq(PokerHandClassifier.classify(empty), PokerHandClassifier.Category.HIGH_CARD)
	assert_true(PokerHandClassifier.classify_all(empty).is_empty(), "but forms nothing")

# --- fallbacks ----------------------------------------------------------

func test_classify_all_lists_the_best_shape_first() -> void:
	var all := PokerHandClassifier.classify_all(
		_cards([[8, S], [8, H], [8, D], [11, C], [11, S]])
	)
	assert_eq(all[0], PokerHandClassifier.Category.FULL_HOUSE)

func test_a_full_house_is_also_a_trip_a_two_pair_and_a_pair() -> void:
	var all := PokerHandClassifier.classify_all(
		_cards([[8, S], [8, H], [8, D], [11, C], [11, S]])
	)
	assert_true(PokerHandClassifier.Category.THREE_OF_A_KIND in all)
	assert_true(PokerHandClassifier.Category.TWO_PAIR in all)
	assert_true(PokerHandClassifier.Category.PAIR in all)
	assert_true(PokerHandClassifier.Category.HIGH_CARD in all, "always the last resort")

func test_a_straight_flush_is_also_a_straight_and_a_flush() -> void:
	var all := PokerHandClassifier.classify_all(
		_cards([[5, H], [6, H], [7, H], [8, H], [9, H]])
	)
	assert_eq(all[0], PokerHandClassifier.Category.STRAIGHT_FLUSH)
	assert_true(PokerHandClassifier.Category.STRAIGHT in all)
	assert_true(PokerHandClassifier.Category.FLUSH in all)

# --- which cards carry the hand -----------------------------------------

func _scoring(specs : Array, category : int) -> Array[Card]:
	return PokerHandClassifier.scoring_cards(_cards(specs), category)

func _ranks_of(cards : Array[Card]) -> Array[int]:
	var ranks : Array[int] = []
	for card in cards:
		ranks.append(card.data.rank)
	ranks.sort()
	return ranks

func test_a_pair_is_carried_by_two_cards() -> void:
	var scored := _scoring(
		[[5, S], [5, H], [9, D], [11, C], [13, S]], PokerHandClassifier.Category.PAIR
	)
	assert_eq(scored.size(), 2)
	assert_eq(_ranks_of(scored), [5, 5] as Array[int])

func test_a_two_pair_is_carried_by_four() -> void:
	var scored := _scoring(
		[[5, S], [5, H], [11, D], [11, C], [13, S]],
		PokerHandClassifier.Category.TWO_PAIR
	)
	assert_eq(_ranks_of(scored), [5, 5, 11, 11] as Array[int])

func test_a_three_of_a_kind_leaves_the_spare_cards_out() -> void:
	var scored := _scoring(
		[[8, S], [8, H], [8, D], [11, C], [13, S]],
		PokerHandClassifier.Category.THREE_OF_A_KIND
	)
	assert_eq(_ranks_of(scored), [8, 8, 8] as Array[int])

func test_a_four_of_a_kind_leaves_the_kicker_out() -> void:
	var scored := _scoring(
		[[8, S], [8, H], [8, D], [8, C], [11, S]],
		PokerHandClassifier.Category.FOUR_OF_A_KIND
	)
	assert_eq(_ranks_of(scored), [8, 8, 8, 8] as Array[int])

func test_a_full_house_is_carried_by_all_five() -> void:
	var scored := _scoring(
		[[8, S], [8, H], [8, D], [11, C], [11, S]],
		PokerHandClassifier.Category.FULL_HOUSE
	)
	assert_eq(_ranks_of(scored), [8, 8, 8, 11, 11] as Array[int])

func test_a_straight_is_carried_by_the_whole_hand() -> void:
	var scored := _scoring(
		[[5, S], [6, H], [7, D], [8, C], [9, S]], PokerHandClassifier.Category.STRAIGHT
	)
	assert_eq(scored.size(), 5, "the run is every card")

func test_a_flush_is_carried_by_the_whole_hand() -> void:
	var scored := _scoring(
		[[2, H], [5, H], [9, H], [11, H], [13, H]], PokerHandClassifier.Category.FLUSH
	)
	assert_eq(scored.size(), 5)

func test_a_high_card_is_carried_by_exactly_one() -> void:
	var scored := _scoring(
		[[2, S], [5, H], [9, D], [11, C], [13, S]],
		PokerHandClassifier.Category.HIGH_CARD
	)
	assert_eq(scored.size(), 1)
	assert_eq(scored[0].data.rank, 13, "the king")

func test_the_high_card_counts_an_ace_as_highest() -> void:
	var scored := _scoring(
		[[1, S], [5, H], [9, D], [11, C], [13, S]],
		PokerHandClassifier.Category.HIGH_CARD
	)
	assert_eq(scored[0].data.rank, 1, "the ace, stored as rank 1 but worth 14")

## A hand can hold more than the shape needs. Framing all of it would tell the
## player their two pair is doing work that only one pair is being paid for.
func test_a_pair_picks_the_stronger_of_two() -> void:
	var scored := _scoring(
		[[5, S], [5, H], [11, D], [11, C], [13, S]], PokerHandClassifier.Category.PAIR
	)
	assert_eq(_ranks_of(scored), [11, 11] as Array[int], "the jacks, not the fives")

func test_two_triples_make_a_full_house_of_the_stronger_and_the_weaker() -> void:
	var scored := _scoring(
		[[8, S], [8, H], [8, D], [11, C], [11, S], [11, H]],
		PokerHandClassifier.Category.FULL_HOUSE
	)
	assert_eq(_ranks_of(scored), [8, 8, 8, 11, 11, 11] as Array[int])

func test_an_empty_hand_is_carried_by_nothing() -> void:
	var empty : Array[Card] = []
	assert_true(
		PokerHandClassifier.scoring_cards(
			empty, PokerHandClassifier.Category.HIGH_CARD
		).is_empty()
	)

func test_a_bare_pair_forms_nothing_but_a_pair_and_a_high_card() -> void:
	var all := PokerHandClassifier.classify_all(
		_cards([[5, S], [5, H], [9, D], [11, C], [13, S]])
	)
	assert_eq(all.size(), 2)
	assert_eq(all[0], PokerHandClassifier.Category.PAIR)
	assert_eq(all[1], PokerHandClassifier.Category.HIGH_CARD)
