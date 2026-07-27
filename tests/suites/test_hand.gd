extends TestCase
## Hand owns no drawing logic — whoever holds the Deck fills it. These tests
## pin the bookkeeping it does own: membership, selection and locking.

var _hand : Hand

func before_each() -> void:
	_hand = Hand.new(5)

func _card(rank : int, suit : StringName = CardData.SPADES) -> Card:
	return Card.new(CardData.create(rank, suit))

func _cards(count : int) -> Array[Card]:
	var result : Array[Card] = []
	for i in count:
		result.append(_card(i + 1))
	return result

func test_starts_empty_and_wants_a_full_hand() -> void:
	assert_eq(_hand.size(), 0)
	assert_eq(_hand.missing_count(), 5)
	assert_false(_hand.is_full())

func test_add_fills_the_hand() -> void:
	_hand.add(_cards(5))
	assert_eq(_hand.size(), 5)
	assert_eq(_hand.missing_count(), 0)
	assert_true(_hand.is_full())

func test_missing_count_never_goes_negative() -> void:
	# add() does not cap at max_size, so an over-full hand is reachable.
	_hand.add(_cards(7))
	assert_eq(_hand.size(), 7)
	assert_eq(_hand.missing_count(), 0, "an over-full hand needs no top-up")

func test_remove_takes_only_the_named_cards() -> void:
	var cards := _cards(5)
	_hand.add(cards)
	var doomed : Array[Card] = [cards[1], cards[3]]
	_hand.remove(doomed)
	assert_eq(_hand.size(), 3)
	assert_false(cards[1] in _hand.cards)
	assert_true(cards[0] in _hand.cards)

func test_toggle_selection_flips_and_back() -> void:
	var cards := _cards(3)
	_hand.add(cards)
	_hand.toggle_selection(cards[0])
	assert_true(cards[0].is_selected)
	assert_eq(_hand.selected_count(), 1)
	_hand.toggle_selection(cards[0])
	assert_false(cards[0].is_selected)
	assert_eq(_hand.selected_count(), 0)

func test_take_selected_removes_them_from_the_hand() -> void:
	var cards := _cards(5)
	_hand.add(cards)
	_hand.toggle_selection(cards[0])
	_hand.toggle_selection(cards[2])
	var taken := _hand.take_selected()
	assert_eq(taken.size(), 2)
	assert_eq(_hand.size(), 3)
	assert_eq(_hand.selected_count(), 0)

func test_clear_selection_leaves_the_cards() -> void:
	var cards := _cards(4)
	_hand.add(cards)
	_hand.toggle_selection(cards[1])
	_hand.clear_selection()
	assert_eq(_hand.selected_count(), 0)
	assert_eq(_hand.size(), 4, "clearing a selection removes nothing")

func test_changed_fires_on_add_and_remove() -> void:
	var count := [0]
	_hand.changed.connect(func() -> void: count[0] += 1)
	_hand.add(_cards(2))
	assert_eq(count[0], 1, "adding cards is a change")
	var nothing : Array[Card] = []
	_hand.add(nothing)
	assert_eq(count[0], 1, "adding nothing is not a change")
	_hand.remove(nothing)
	assert_eq(count[0], 1, "removing nothing is not a change")
