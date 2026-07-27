class_name PokerHandEvaluator
extends HandEvaluator
## Prices a hand: everything on the table added up, times what the cards are
## worth as poker.
##
##     (sum of card values + sum of dice pips) x hand multiplier
##
## The dice count twice by design. The same pips the player spends as white
## energy also ride along into the score, so swapping a card costs tempo and
## options rather than points — which is what keeps a 15-second round about
## choosing, not about hoarding.
##
## The shapes themselves live in PokerHandClassifier. This class only decides
## what each shape is worth.

@export_group("Multipliers")
@export var high_card_multiplier : float = 1.0
@export var pair_multiplier : float = 2.0
@export var two_pair_multiplier : float = 3.0
@export var three_of_a_kind_multiplier : float = 4.0
@export var straight_multiplier : float = 5.0
@export var flush_multiplier : float = 6.0
@export var full_house_multiplier : float = 8.0
## Absent from the design spec. Placed between the full house and the straight
## flush so that quads keep beating a full house, as they do in poker.
@export var four_of_a_kind_multiplier : float = 9.0
@export var straight_flush_multiplier : float = 10.0

@export_group("Shape")
## Straights and flushes need this many cards. Below it they cannot form.
@export_range(3, 7) var run_length : int = 5
## Hands smaller than this cannot be saved at all.
@export_range(1, 7) var minimum_cards : int = 1

func is_valid_play(cards : Array[Card]) -> bool:
	return cards.size() >= minimum_cards

func evaluate(cards : Array[Card], context : GameContext) -> HandScore:
	if cards.is_empty():
		return HandScore.new()
	var category := best_allowed_category(cards, context)
	var multiplier := multiplier_for(category) \
		* (1.0 + context.multiplier_bonus_for(category)) \
		* context.score_multiplier
	return HandScore.new(
		PokerHandClassifier.card_value_sum(cards),
		context.total_energy(),
		multiplier,
		PokerHandClassifier.category_name(category),
		category,
		PokerHandClassifier.scoring_cards(cards, category, run_length)
	)

## The best shape the hand forms that a boss has not ruled out. A banned pair
## falls back to high card rather than making the hand unplayable — a level the
## player cannot score at all is a bug, not a difficulty setting.
func best_allowed_category(cards : Array[Card], context : GameContext) -> int:
	var categories := PokerHandClassifier.classify_all(cards, run_length)
	for category in categories:
		if not context.is_category_banned(category):
			return category
	return PokerHandClassifier.Category.HIGH_CARD

func multiplier_for(category : int) -> float:
	match category:
		PokerHandClassifier.Category.PAIR: return pair_multiplier
		PokerHandClassifier.Category.TWO_PAIR: return two_pair_multiplier
		PokerHandClassifier.Category.THREE_OF_A_KIND: return three_of_a_kind_multiplier
		PokerHandClassifier.Category.STRAIGHT: return straight_multiplier
		PokerHandClassifier.Category.FLUSH: return flush_multiplier
		PokerHandClassifier.Category.FULL_HOUSE: return full_house_multiplier
		PokerHandClassifier.Category.FOUR_OF_A_KIND: return four_of_a_kind_multiplier
		PokerHandClassifier.Category.STRAIGHT_FLUSH: return straight_flush_multiplier
		_: return high_card_multiplier
