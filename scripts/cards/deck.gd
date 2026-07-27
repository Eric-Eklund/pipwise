class_name Deck
extends RefCounted
## A draw pile and a discard pile, drawing without replacement.
##
## DiceBag mirrors this class on purpose: both are "draw from a shuffled pile,
## spent items go to a discard, reshuffle when the pile runs dry". Keeping the
## two symmetrical means the game loop treats cards and dice the same way.

signal cards_drawn(cards : Array[Card])
signal reshuffled

var _draw_pile : Array[Card] = []
var _discard_pile : Array[Card] = []
var _rng : RngService

func _init(definition : DeckDefinition, rng : RngService) -> void:
	_rng = rng
	for card_data in definition.cards:
		_draw_pile.append(Card.new(card_data))
	_rng.shuffle(_draw_pile)

func draw_pile_size() -> int:
	return _draw_pile.size()

func discard_pile_size() -> int:
	return _discard_pile.size()

func total_size() -> int:
	return _draw_pile.size() + _discard_pile.size()

func is_exhausted() -> bool:
	return total_size() == 0

## Draws up to [param count] cards, reshuffling the discard pile back in if the
## draw pile empties. Returns fewer than requested only when the whole deck is
## exhausted, so callers should check the returned size rather than assume.
func draw(count : int) -> Array[Card]:
	var drawn : Array[Card] = []
	for _i in count:
		if _draw_pile.is_empty():
			if _discard_pile.is_empty():
				break
			reshuffle_discard()
		var card : Card = _draw_pile.pop_back()
		drawn.append(card)
	if not drawn.is_empty():
		cards_drawn.emit(drawn)
	return drawn

## Sends cards to the discard pile, clearing their per-play state.
func discard(cards : Array[Card]) -> void:
	for card in cards:
		card.is_selected = false
		card.is_scoring = false
		_discard_pile.append(card)

func reshuffle_discard() -> void:
	if _discard_pile.is_empty():
		return
	_draw_pile.append_array(_discard_pile)
	_discard_pile.clear()
	_rng.shuffle(_draw_pile)
	reshuffled.emit()
