extends TestCase
## Deck is a draw pile plus a discard pile. The invariant that matters is that
## cards are conserved: total_size() never changes, whatever moves where.

var _deck : Deck

func before_each() -> void:
	_deck = Deck.new(DeckDefinition.create_standard_52(), RngService.new(4242))

func test_standard_deck_has_52_cards() -> void:
	assert_eq(_deck.total_size(), 52)
	assert_eq(_deck.draw_pile_size(), 52)
	assert_eq(_deck.discard_pile_size(), 0)

func test_standard_deck_has_every_card_once() -> void:
	var definition := DeckDefinition.create_standard_52()
	var ids : Array[StringName] = []
	for card_data in definition.cards:
		var id := card_data.get_id()
		if id in ids:
			fail("duplicate card in the standard deck: %s" % id)
			return
		ids.append(id)
	assert_eq(ids.size(), 52, "13 ranks across 4 suits")

func test_draw_moves_cards_out_of_the_pile() -> void:
	var drawn := _deck.draw(5)
	assert_eq(drawn.size(), 5)
	assert_eq(_deck.draw_pile_size(), 47)
	assert_eq(_deck.total_size(), 47, "drawn cards leave the deck entirely")

func test_draw_stops_when_everything_is_exhausted() -> void:
	var drawn := _deck.draw(60)
	assert_eq(drawn.size(), 52, "cannot draw more than exists")
	assert_true(_deck.is_exhausted())

func test_discard_returns_cards_to_the_deck() -> void:
	var drawn := _deck.draw(5)
	_deck.discard(drawn)
	assert_eq(_deck.discard_pile_size(), 5)
	assert_eq(_deck.total_size(), 52, "cards are conserved")

func test_discard_clears_per_play_state() -> void:
	var drawn := _deck.draw(2)
	drawn[0].is_selected = true
	drawn[1].is_scoring = true
	_deck.discard(drawn)
	assert_false(drawn[0].is_selected, "selection must not survive a discard")
	assert_false(drawn[1].is_scoring, "a card out of the hand carries nothing")

func test_empty_draw_pile_reshuffles_the_discard() -> void:
	var drawn := _deck.draw(52)
	_deck.discard(drawn)
	assert_eq(_deck.draw_pile_size(), 0)
	var again := _deck.draw(3)
	assert_eq(again.size(), 3, "the discard pile is reshuffled in to serve the draw")
	assert_eq(_deck.discard_pile_size(), 0)

func test_draw_order_is_reproducible_for_a_seed() -> void:
	var other := Deck.new(DeckDefinition.create_standard_52(), RngService.new(4242))
	var mine := _deck.draw(10)
	var theirs := other.draw(10)
	for i in mine.size():
		if mine[i].get_id() != theirs[i].get_id():
			fail("same seed diverged at index %d" % i)
			return
	assert_true(true, "the first ten cards matched")
