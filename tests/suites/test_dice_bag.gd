extends TestCase
## DiceBag mirrors Deck: draw without replacement, spend to a used pile, refill
## when the bag runs dry.

var _bag : DiceBag

func before_each() -> void:
	_bag = DiceBag.new(StarterDice.create_starter_bag(6), RngService.new(777))

func test_starter_bag_holds_six_dice() -> void:
	assert_eq(_bag.total_size(), 6)
	assert_eq(_bag.bag_size(), 6)
	assert_eq(_bag.used_size(), 0)

func test_drawn_dice_always_show_a_face() -> void:
	for die in _bag.draw(3):
		if die.current_face == null:
			fail("a drawn die must already be rolled")
			return
	assert_true(true, "every drawn die had a face")

func test_draw_removes_dice_from_the_bag() -> void:
	var drawn := _bag.draw(2)
	assert_eq(drawn.size(), 2)
	assert_eq(_bag.bag_size(), 4)
	assert_eq(_bag.total_size(), 4, "drawn dice are held by the caller, not the bag")

func test_spend_moves_a_die_to_the_used_pile() -> void:
	var die := _bag.draw(1)[0]
	_bag.spend(die)
	assert_true(die.is_spent)
	assert_eq(_bag.used_size(), 1)

func test_return_dice_puts_them_back_unspent() -> void:
	var drawn := _bag.draw(2)
	_bag.return_dice(drawn)
	assert_eq(_bag.used_size(), 2)
	assert_false(drawn[0].is_spent, "returned dice are available again")

func test_empty_bag_refills_from_the_used_pile() -> void:
	var all_dice := _bag.draw(6)
	assert_eq(_bag.bag_size(), 0)
	_bag.return_dice(all_dice)
	var again := _bag.draw(2)
	assert_eq(again.size(), 2, "the used pile is shuffled back in to serve the draw")

func test_draw_stops_when_everything_is_exhausted() -> void:
	var drawn := _bag.draw(10)
	assert_eq(drawn.size(), 6, "cannot draw more dice than exist")
	assert_true(_bag.is_exhausted())

func test_draw_clears_a_stale_spent_flag() -> void:
	var die := _bag.draw(1)[0]
	_bag.spend(die)
	_bag.draw(5)
	var refilled := _bag.draw(1)
	if refilled.is_empty():
		fail("expected the used pile to be refilled")
		return
	assert_false(refilled[0].is_spent, "a redrawn die is usable again")
