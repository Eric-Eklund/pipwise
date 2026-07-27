extends TestCase
## The six dice on the table: rolled together, held one at a time, rerolled as
## whatever is left.

var _pool : DicePool

func before_each() -> void:
	_pool = DicePool.new(StarterDice.create_starter_bag(6), RngService.new(4242), 3)

func test_a_pool_holds_the_dice_the_definition_named() -> void:
	assert_eq(_pool.size(), 6)

func test_dice_show_nothing_until_they_are_rolled() -> void:
	assert_eq(_pool.total_value(), 0)

func test_rolling_puts_a_face_on_every_die() -> void:
	_pool.roll_all()
	for die in _pool.dice:
		assert_true(die.get_value() >= 1 and die.get_value() <= 6, str(die))

func test_the_total_is_the_sum_of_the_faces() -> void:
	_pool.roll_all()
	var expected := 0
	for die in _pool.dice:
		expected += die.get_value()
	assert_eq(_pool.total_value(), expected)

# --- locking ------------------------------------------------------------

func test_locking_a_die_is_reported_as_a_change() -> void:
	_pool.roll_all()
	assert_true(_pool.set_locked(_pool.dice[0], true))
	assert_eq(_pool.locked_count(), 1)

func test_locking_a_die_that_is_already_locked_changes_nothing() -> void:
	_pool.roll_all()
	_pool.set_locked(_pool.dice[0], true)
	assert_false(_pool.set_locked(_pool.dice[0], true), "no second charge")
	assert_eq(_pool.locked_count(), 1)

func test_a_locked_die_keeps_its_face_through_a_reroll() -> void:
	_pool.roll_all()
	var die := _pool.dice[0]
	_pool.set_locked(die, true)
	var kept := die.get_value()
	_pool.reroll_unheld()
	assert_eq(die.get_value(), kept)

func test_an_unlocked_die_is_free_to_change() -> void:
	_pool.roll_all()
	# Rerolling is random, so this asserts the die was offered to the RNG rather
	# than that it landed differently: after three rerolls of five free dice,
	# something has to have moved.
	var before : Array[int] = []
	for die in _pool.dice:
		before.append(die.get_value())
	_pool.set_locked(_pool.dice[0], true)
	var changed := false
	for _i in 3:
		_pool.reroll_unheld()
		for i in _pool.size():
			if _pool.dice[i].get_value() != before[i]:
				changed = true
	assert_true(changed, "unheld dice move")

# --- freezing -----------------------------------------------------------

func test_freezing_picks_the_requested_number_of_dice() -> void:
	_pool.roll_all()
	var frozen := _pool.freeze_random(2)
	assert_eq(frozen.size(), 2)
	assert_eq(_pool.frozen_count(), 2)

func test_a_frozen_die_cannot_be_locked() -> void:
	_pool.roll_all()
	var die := _pool.freeze_random(1)[0]
	assert_false(_pool.set_locked(die, true), "the choice is gone, not merely paid for")
	assert_eq(_pool.locked_count(), 0)

func test_freezing_a_locked_die_releases_the_lock() -> void:
	_pool.roll_all()
	_pool.set_locked(_pool.dice[0], true)
	_pool.freeze_random(6)
	assert_eq(_pool.locked_count(), 0, "no paying for a choice you no longer have")

func test_a_frozen_die_keeps_its_face_through_a_reroll() -> void:
	_pool.roll_all()
	var die := _pool.freeze_random(1)[0]
	var kept := die.get_value()
	for _i in 3:
		_pool.reroll_unheld()
	assert_eq(die.get_value(), kept)

func test_freezing_cannot_ask_for_more_dice_than_there_are() -> void:
	_pool.roll_all()
	assert_eq(_pool.freeze_random(99).size(), 6)

# --- rerolls ------------------------------------------------------------

func test_a_pool_starts_with_the_rerolls_the_ruleset_allows() -> void:
	assert_eq(_pool.rerolls_left, 3)

func test_each_reroll_spends_one() -> void:
	_pool.roll_all()
	_pool.reroll_unheld()
	assert_eq(_pool.rerolls_left, 2)

func test_rerolls_run_out() -> void:
	_pool.roll_all()
	for _i in 3:
		assert_true(_pool.reroll_unheld())
	assert_eq(_pool.rerolls_left, 0)
	assert_false(_pool.can_reroll())
	assert_false(_pool.reroll_unheld(), "the fourth is refused")

func test_a_fully_held_pool_cannot_reroll() -> void:
	_pool.roll_all()
	for die in _pool.dice:
		_pool.set_locked(die, true)
	assert_false(_pool.can_reroll(), "nothing left to shake")
	assert_eq(_pool.rerolls_left, 3, "and nothing was spent finding that out")

func test_a_pool_with_no_rerolls_allowed_never_offers_one() -> void:
	var pool := DicePool.new(StarterDice.create_starter_bag(6), RngService.new(1), 0)
	pool.roll_all()
	assert_false(pool.can_reroll())
