class_name PokerHandEvaluator
extends HandEvaluator
## Scores a play as a poker hand: category points plus the cards' own values,
## times whatever multiplier the dice have built up.
##
## Poker is a starting point, not a commitment. It is familiar and already
## balanced against a 52-card deck, which makes it a good default while the
## real ruleset is still being found. Swapping it out means writing another
## HandEvaluator and pointing the Ruleset at it.

enum Category {
	HIGH_CARD,
	PAIR,
	TWO_PAIR,
	THREE_OF_A_KIND,
	STRAIGHT,
	FLUSH,
	FULL_HOUSE,
	FOUR_OF_A_KIND,
	STRAIGHT_FLUSH,
}

const CATEGORY_NAMES : Dictionary = {
	Category.HIGH_CARD: "High Card",
	Category.PAIR: "Pair",
	Category.TWO_PAIR: "Two Pair",
	Category.THREE_OF_A_KIND: "Three of a Kind",
	Category.STRAIGHT: "Straight",
	Category.FLUSH: "Flush",
	Category.FULL_HOUSE: "Full House",
	Category.FOUR_OF_A_KIND: "Four of a Kind",
	Category.STRAIGHT_FLUSH: "Straight Flush",
}

@export var high_card_points : int = 5
@export var pair_points : int = 10
@export var two_pair_points : int = 20
@export var three_of_a_kind_points : int = 30
@export var straight_points : int = 40
@export var flush_points : int = 50
@export var full_house_points : int = 60
@export var four_of_a_kind_points : int = 80
@export var straight_flush_points : int = 120

## Straights and flushes need this many cards. Below it they cannot form.
@export_range(3, 7) var run_length : int = 5

func evaluate(cards : Array[Card], context : GameContext) -> HandScore:
	if cards.is_empty():
		return HandScore.new()
	var category := classify(cards)
	var base := points_for(category) + _card_value_sum(cards)
	return HandScore.new(base, context.score_multiplier, String(CATEGORY_NAMES[category]))

func points_for(category : Category) -> int:
	match category:
		Category.PAIR: return pair_points
		Category.TWO_PAIR: return two_pair_points
		Category.THREE_OF_A_KIND: return three_of_a_kind_points
		Category.STRAIGHT: return straight_points
		Category.FLUSH: return flush_points
		Category.FULL_HOUSE: return full_house_points
		Category.FOUR_OF_A_KIND: return four_of_a_kind_points
		Category.STRAIGHT_FLUSH: return straight_flush_points
		_: return high_card_points

func classify(cards : Array[Card]) -> Category:
	if cards.is_empty():
		return Category.HIGH_CARD

	var rank_counts : Dictionary = {}
	var suits : Dictionary = {}
	var ranks : Array[int] = []
	for card in cards:
		var rank := card.data.rank
		rank_counts[rank] = int(rank_counts.get(rank, 0)) + 1
		suits[card.data.suit] = true
		ranks.append(rank)

	var counts : Array[int] = []
	for rank in rank_counts:
		counts.append(int(rank_counts[rank]))
	counts.sort()
	counts.reverse()

	var flush := suits.size() == 1 and cards.size() >= run_length
	var straight := _is_straight(ranks)

	if flush and straight:
		return Category.STRAIGHT_FLUSH
	if counts[0] >= 4:
		return Category.FOUR_OF_A_KIND
	if counts[0] == 3 and counts.size() > 1 and counts[1] >= 2:
		return Category.FULL_HOUSE
	if flush:
		return Category.FLUSH
	if straight:
		return Category.STRAIGHT
	if counts[0] == 3:
		return Category.THREE_OF_A_KIND
	if counts[0] == 2 and counts.size() > 1 and counts[1] == 2:
		return Category.TWO_PAIR
	if counts[0] == 2:
		return Category.PAIR
	return Category.HIGH_CARD

## Aces count high or low, so both A-2-3-4-5 and 10-J-Q-K-A are runs.
func _is_straight(ranks : Array[int]) -> bool:
	if ranks.size() < run_length:
		return false
	var unique : Array[int] = []
	for rank in ranks:
		if rank not in unique:
			unique.append(rank)
	# Any duplicate rank means the cards cannot all be part of one run.
	if unique.size() != ranks.size():
		return false
	if _is_consecutive(unique):
		return true
	if 1 in unique:
		var ace_high := unique.duplicate()
		ace_high[ace_high.find(1)] = 14
		return _is_consecutive(ace_high)
	return false

func _is_consecutive(values : Array) -> bool:
	var sorted_values := values.duplicate()
	sorted_values.sort()
	return sorted_values[sorted_values.size() - 1] - sorted_values[0] == sorted_values.size() - 1

## Face cards are worth 10, aces 11, everything else its pip count.
func _card_value_sum(cards : Array[Card]) -> int:
	var sum := 0
	for card in cards:
		var rank := card.data.rank
		if rank == 1:
			sum += 11
		elif rank > 10:
			sum += 10
		else:
			sum += rank
	return sum
