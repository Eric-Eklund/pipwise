extends TestCase
## White energy: where it comes from, what shrinks it, and what it does not.
##
## The rule that earns its own suite is that the budget is recomputed from the
## dice rather than banked. A reroll that lands lower takes energy away that
## was never spent, and that is the whole risk of rerolling.

var _context : GameContext

func before_each() -> void:
	_context = _context_showing([4, 2, 6, 1, 5, 3])

func _context_showing(values : Array) -> GameContext:
	var rng := RngService.new(99)
	var definition := BagDefinition.new()
	for _i in values.size():
		definition.dice.append(StarterDice.create_white_d6())
	var pool := DicePool.new(definition, rng)
	var context := GameContext.new(
		Deck.new(DeckDefinition.create_standard_52(), rng), Hand.new(5), pool, rng
	)
	_set_faces(context, values)
	return context

## Forces the dice onto known faces, so the arithmetic in these tests is not
## at the mercy of the seed.
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

# --- the risk of rerolling ----------------------------------------------

func test_a_worse_roll_shrinks_what_is_left_to_spend() -> void:
	_context.spend_energy(12)
	assert_eq(_context.available_energy(), 9)
	# The same six dice come up all ones: 6 total against 12 already committed.
	_set_faces(_context, [1, 1, 1, 1, 1, 1])
	assert_eq(_context.total_energy(), 6)
	assert_eq(_context.available_energy(), 0, "overspent, and floored rather than negative")

func test_a_better_roll_hands_energy_back() -> void:
	_context.spend_energy(12)
	_set_faces(_context, [6, 6, 6, 6, 6, 6])
	assert_eq(_context.available_energy(), 24, "36 on the table, 12 committed")

func test_energy_never_reads_as_negative() -> void:
	_context.spend_energy(21)
	_set_faces(_context, [1, 1, 1, 1, 1, 1])
	assert_eq(_context.available_energy(), 0)

func test_a_reroll_announces_that_the_budget_moved() -> void:
	var fired := [0]
	_context.energy_changed.connect(func() -> void: fired[0] += 1)
	_context.pool.roll_all()
	assert_eq(fired[0], 1, "the pool has no idea it is currency, so the context says so")
