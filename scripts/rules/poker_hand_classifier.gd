class_name PokerHandClassifier
extends RefCounted
## Works out which poker hands a set of cards forms, and what each card is worth.
##
## Split out of PokerHandEvaluator so shape and price can change independently.
## The categories are poker's and are settled; the multipliers hung on them are
## still being balanced. Boss modifiers also need to ask "what else does this
## hand qualify as?" when they ban a category, and that is a question about
## shape, not about score.
##
## All static — there is no state to carry.

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

## CardData stores an ace as rank 1 so that A-2-3-4-5 reads as a run, but it is
## the highest card in the deck when it comes to scoring.
const ACE_VALUE : int = 14

## What a card contributes to the base score: 2-10 their pips, J/Q/K 11/12/13,
## ace 14.
static func card_value(rank : int) -> int:
	return ACE_VALUE if rank == 1 else rank

static func card_value_sum(cards : Array[Card]) -> int:
	var sum := 0
	for card in cards:
		sum += card_value(card.data.rank)
	return sum

static func category_name(category : int) -> String:
	return String(CATEGORY_NAMES.get(category, ""))

## The best hand these cards form.
static func classify(cards : Array[Card], run_length : int = 5) -> Category:
	var all := classify_all(cards, run_length)
	return Category.HIGH_CARD if all.is_empty() else all[0]

## Every hand these cards form, best first. A full house is also a three of a
## kind, a two pair and a pair, and listing all of them is what lets a banned
## category fall back to the next best thing the player actually has rather
## than dropping straight to high card.
static func classify_all(cards : Array[Card], run_length : int = 5) -> Array[Category]:
	var result : Array[Category] = []
	if cards.is_empty():
		return result

	var rank_counts : Dictionary = {}
	var suits : Dictionary = {}
	var ranks : Array[int] = []
	for card in cards:
		var rank := card.data.rank
		rank_counts[rank] = int(rank_counts.get(rank, 0)) + 1
		suits[card.data.suit] = true
		ranks.append(rank)

	var best_count := 0
	## How many ranks appear at least twice — the number that separates a two
	## pair from a pair, and a full house from a bare three of a kind.
	var paired_ranks := 0
	for rank in rank_counts:
		var count := int(rank_counts[rank])
		best_count = maxi(best_count, count)
		if count >= 2:
			paired_ranks += 1

	var flush := suits.size() == 1 and cards.size() >= run_length
	var straight := _is_straight(ranks, run_length)

	if flush and straight:
		result.append(Category.STRAIGHT_FLUSH)
	if best_count >= 4:
		result.append(Category.FOUR_OF_A_KIND)
	if best_count >= 3 and paired_ranks >= 2:
		result.append(Category.FULL_HOUSE)
	if flush:
		result.append(Category.FLUSH)
	if straight:
		result.append(Category.STRAIGHT)
	if best_count >= 3:
		result.append(Category.THREE_OF_A_KIND)
	if paired_ranks >= 2:
		result.append(Category.TWO_PAIR)
	if best_count >= 2:
		result.append(Category.PAIR)
	result.append(Category.HIGH_CARD)
	return result

## Which of these cards actually make up [param category].
##
## The view frames them so the player can see what they are building. That means
## it has to agree exactly with what was scored — including when a boss has
## banned the hand the cards obviously form, in which case the caller passes the
## category that survived and the frame lands on the high card instead.
static func scoring_cards(
	cards : Array[Card], category : Category, run_length : int = 5
) -> Array[Card]:
	var result : Array[Card] = []
	if cards.is_empty():
		return result

	match category:
		# The shape is the whole hand — every card is part of the run or the suit.
		Category.STRAIGHT, Category.FLUSH, Category.STRAIGHT_FLUSH:
			return cards.duplicate()
		Category.HIGH_CARD:
			result.append(_highest(cards))
			return result

	var wanted := _ranks_forming(cards, category)
	for card in cards:
		if card.data.rank in wanted:
			result.append(card)
	return result

## The ranks whose repeats build [param category], best first. A hand can hold
## more than the shape needs — three pairs in six cards make a two pair — so the
## strongest ranks win and the rest are left out of the frame.
static func _ranks_forming(cards : Array[Card], category : Category) -> Array[int]:
	var counts : Dictionary = {}
	for card in cards:
		counts[card.data.rank] = int(counts.get(card.data.rank, 0)) + 1

	var minimum := 2
	var wanted_count := 1
	match category:
		Category.FOUR_OF_A_KIND:
			minimum = 4
		Category.THREE_OF_A_KIND:
			minimum = 3
		Category.TWO_PAIR:
			wanted_count = 2
		Category.FULL_HOUSE:
			return _full_house_ranks(counts)

	var candidates : Array[int] = []
	for rank in counts:
		if int(counts[rank]) >= minimum:
			candidates.append(int(rank))
	_sort_by_value(candidates)
	return candidates.slice(0, wanted_count)

## A full house is the best three-of-a-kind plus the best other pair. Picking the
## triple first matters: with two triples the second one is the pair.
static func _full_house_ranks(counts : Dictionary) -> Array[int]:
	var triples : Array[int] = []
	var pairs : Array[int] = []
	for rank in counts:
		if int(counts[rank]) >= 3:
			triples.append(int(rank))
		elif int(counts[rank]) >= 2:
			pairs.append(int(rank))
	_sort_by_value(triples)
	_sort_by_value(pairs)
	if triples.is_empty():
		return []

	var result : Array[int] = [triples[0]]
	if pairs.is_empty():
		# Two triples: the weaker one plays the part of the pair.
		if triples.size() > 1:
			result.append(triples[1])
	else:
		result.append(pairs[0])
	return result

## Strongest first, with an ace counting high.
static func _sort_by_value(ranks : Array[int]) -> void:
	ranks.sort_custom(func(a : int, b : int) -> bool: return card_value(a) > card_value(b))

static func _highest(cards : Array[Card]) -> Card:
	var best : Card = cards[0]
	for card in cards:
		if card_value(card.data.rank) > card_value(best.data.rank):
			best = card
	return best

## Aces count high or low, so both A-2-3-4-5 and 10-J-Q-K-A are runs.
static func _is_straight(ranks : Array[int], run_length : int) -> bool:
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
		ace_high[ace_high.find(1)] = ACE_VALUE
		return _is_consecutive(ace_high)
	return false

static func _is_consecutive(values : Array) -> bool:
	var sorted_values := values.duplicate()
	sorted_values.sort()
	return sorted_values[sorted_values.size() - 1] - sorted_values[0] == sorted_values.size() - 1
