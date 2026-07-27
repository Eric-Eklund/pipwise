extends TestCase
## Energy: where it comes from, what shrinks it, and what it does not.
##
## Nothing spends energy yet — the cards that will are not in the MVP. The
## accounting is kept and tested because the design document's energy is the sum
## of the dice, which the pool already is, and a budget that only appears when
## the first card ships is a budget nobody has ever balanced.

var _context : GameContext

func before_each() -> void:
	_context = _context_showing([4, 2, 6, 1, 5, 3])

func _context_showing(values : Array) -> GameContext:
	var rng := RngService.new(99)
	var pool := DicePool.new(StarterDice.create_starter_bag(values.size()), rng)
	var context := GameContext.new(pool, rng)
	_set_faces(context, values)
	return context

## Forces the dice onto known faces, so the arithmetic here is not at the mercy
## of the seed.
func _set_faces(context : GameContext, values : Array) -> void:
	for i in values.size():
		context.pool.dice[i].current_face = DieFace.create(&"fixed", int(values[i]))

func test_the_budget_is_the_sum_of_the_dice() -> void:
	assert_eq(_context.total_energy(), 21)
	assert_eq(_context.available_energy(), 21)

func test_spending_reduces_what_is_left_but_not_the_total() -> void:
	assert_true(_context.spend_energy(9))
	assert_eq(_context.available_energy(), 12)
	assert_eq(_context.total_energy(), 21, "the pips are still on the table")

func test_spending_more_than_there_is_is_refused() -> void:
	assert_false(_context.spend_energy(22))
	assert_eq(_context.available_energy(), 21, "and costs nothing")

func test_can_afford_agrees_with_spending() -> void:
	assert_true(_context.can_afford(21))
	assert_false(_context.can_afford(22))
	_context.spend_energy(20)
	assert_true(_context.can_afford(1))
	assert_false(_context.can_afford(2))

func test_a_refund_gives_the_energy_back() -> void:
	_context.spend_energy(8)
	_context.refund_energy(4)
	assert_eq(_context.available_energy(), 17)

func test_a_refund_cannot_manufacture_energy() -> void:
	_context.refund_energy(50)
	assert_eq(_context.available_energy(), 21, "capped at the dice on the table")

## Set aside dice still count. The player's dice are their resources whether or
## not this turn has already committed them.
func test_dice_set_aside_still_produce_energy() -> void:
	_context.pool.set_aside(_context.pool.dice[0])
	assert_eq(_context.total_energy(), 21, "unchanged by the commitment")

func test_a_roll_announces_that_the_budget_moved() -> void:
	var fired := [0]
	_context.energy_changed.connect(func() -> void: fired[0] += 1)
	_context.pool.roll()
	assert_eq(fired[0], 1, "the pool has no idea it is currency, so the context says so")

func test_energy_never_reads_as_negative() -> void:
	_context.spend_energy(21)
	_set_faces(_context, [1, 1, 1, 1, 1, 1])
	assert_eq(_context.available_energy(), 0, "floored, not negative")

func test_a_turn_starts_with_a_clean_slate() -> void:
	_context.spend_energy(10)
	_context.advance_turn()
	assert_eq(_context.available_energy(), 21, "what was spent belonged to the old turn")
