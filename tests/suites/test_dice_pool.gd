extends TestCase
## The dice a turn is played with: rolled together, set aside one at a time,
## rolled again with whatever is left.

var _pool : DicePool

func before_each() -> void:
	_pool = DicePool.new(StarterDice.create_starter_bag(6), RngService.new(4242))

func test_a_pool_holds_the_dice_the_definition_named() -> void:
	assert_eq(_pool.size(), 6)

func test_dice_show_nothing_until_they_are_rolled() -> void:
	assert_eq(_pool.total_value(), 0)

func test_rolling_puts_a_face_on_every_die() -> void:
	_pool.roll()
	for die in _pool.dice:
		assert_true(die.get_value() >= 1 and die.get_value() <= 6, str(die))

func test_the_total_is_the_sum_of_the_faces() -> void:
	_pool.roll()
	var expected := 0
	for die in _pool.dice:
		expected += die.get_value()
	assert_eq(_pool.total_value(), expected)

func test_every_roll_is_counted() -> void:
	assert_eq(_pool.roll_count, 0, "nothing rolled yet")
	_pool.roll()
	_pool.set_aside(_pool.dice[0])
	_pool.roll()
	assert_eq(_pool.roll_count, 2)

# --- setting aside ---------------------------------------------------------

func test_setting_a_die_aside_takes_it_out_of_play() -> void:
	_pool.roll()
	assert_true(_pool.set_aside(_pool.dice[0]))
	assert_eq(_pool.set_aside_count(), 1)
	assert_eq(_pool.in_play_count(), 5)

func test_setting_aside_a_die_that_is_already_aside_changes_nothing() -> void:
	_pool.roll()
	_pool.set_aside(_pool.dice[0])
	assert_false(_pool.set_aside(_pool.dice[0]), "no double counting")
	assert_eq(_pool.set_aside_count(), 1)

func test_a_die_set_aside_keeps_its_face_through_a_roll() -> void:
	_pool.roll()
	var die := _pool.dice[0]
	_pool.set_aside(die)
	var kept := die.get_value()
	_pool.roll()
	assert_eq(die.get_value(), kept)

func test_dice_still_in_play_are_free_to_change() -> void:
	_pool.roll()
	var before : Array[int] = []
	for die in _pool.dice:
		before.append(die.get_value())
	_pool.set_aside(_pool.dice[0])
	# Rolling is random, so this asserts the dice were offered to the RNG rather
	# than that they landed differently: across three rolls of five free dice,
	# something has to have moved.
	var changed := false
	for _i in 3:
		_pool.roll()
		for i in _pool.size():
			if _pool.dice[i].get_value() != before[i]:
				changed = true
	assert_true(changed, "dice in play move")

func test_taking_a_die_back_puts_it_in_play_again() -> void:
	_pool.roll()
	var die := _pool.dice[0]
	_pool.set_aside(die)
	assert_true(_pool.take_back(die))
	assert_eq(_pool.in_play_count(), 6)

func test_setting_aside_a_whole_selection_reports_how_many_moved() -> void:
	_pool.roll()
	var selection : Array[Die] = [_pool.dice[0], _pool.dice[1], _pool.dice[0]]
	assert_eq(_pool.set_aside_all(selection), 2, "the repeat does not count twice")

# --- restoring -------------------------------------------------------------

func test_restoring_brings_dice_back_newest_first() -> void:
	_pool.roll()
	_pool.set_aside(_pool.dice[0])
	_pool.set_aside(_pool.dice[3])
	_pool.restore(1)
	assert_true(_pool.dice[0].is_set_aside, "the older commitment stays")
	assert_false(_pool.dice[3].is_set_aside, "the newest one comes back")

## The dice rather than a count, so a caller can do something to what it bought
## back. Second Wind rolls its die again; Nature deliberately does not.
func test_restoring_names_the_dice_that_came_back() -> void:
	_pool.roll()
	_pool.set_aside(_pool.dice[0])
	_pool.set_aside(_pool.dice[3])
	var restored := _pool.restore(1)
	assert_eq(restored.size(), 1, "one came back")
	assert_true(restored[0] == _pool.dice[3], "and it is the one that did")

func test_restoring_cannot_ask_for_more_than_was_set_aside() -> void:
	_pool.roll()
	_pool.set_aside(_pool.dice[0])
	assert_eq(_pool.restore(5).size(), 1, "only one to give back")

func test_restoring_nothing_is_harmless() -> void:
	_pool.roll()
	assert_eq(_pool.restore(0).size(), 0)

# --- hot dice --------------------------------------------------------------

func test_a_pool_is_exhausted_once_every_die_is_set_aside() -> void:
	_pool.roll()
	for die in _pool.dice:
		_pool.set_aside(die)
	assert_true(_pool.is_exhausted())

func test_hot_dice_bring_the_whole_table_back() -> void:
	_pool.roll()
	for die in _pool.dice:
		_pool.set_aside(die)
	_pool.reset_for_hot_dice()
	assert_eq(_pool.in_play_count(), 6, "all six again")
	assert_false(_pool.is_exhausted())

## The turn is continuing, not starting over. The roll count is what tells the
## view this is the same turn getting longer.
func test_hot_dice_do_not_reset_the_roll_count() -> void:
	_pool.roll()
	for die in _pool.dice:
		_pool.set_aside(die)
	_pool.reset_for_hot_dice()
	assert_eq(_pool.roll_count, 1, "still the same turn")

func test_resetting_a_turn_clears_everything() -> void:
	_pool.roll()
	_pool.set_aside(_pool.dice[0])
	_pool.reset_turn()
	assert_eq(_pool.in_play_count(), 6)
	assert_eq(_pool.roll_count, 0, "a new turn rolls from scratch")

# --- signals ---------------------------------------------------------------

func test_a_roll_announces_itself() -> void:
	var fired := [0]
	_pool.rolled.connect(func(_dice : Array[Die]) -> void: fired[0] += 1)
	_pool.roll()
	assert_eq(fired[0], 1)

func test_hot_dice_announce_themselves() -> void:
	var fired := [0]
	_pool.hot_dice.connect(func() -> void: fired[0] += 1)
	_pool.roll()
	_pool.reset_for_hot_dice()
	assert_eq(fired[0], 1)

func test_rolling_an_empty_table_does_nothing() -> void:
	_pool.roll()
	for die in _pool.dice:
		_pool.set_aside(die)
	var count_before := _pool.roll_count
	assert_eq(_pool.roll().size(), 0, "nothing to roll")
	assert_eq(_pool.roll_count, count_before, "and no roll was spent")
