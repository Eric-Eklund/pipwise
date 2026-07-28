extends TestCase
## Energy: where it comes from, what shrinks it, and what it does not.
##
## The design document's energy is the sum of the dice, taken **once a turn**
## rather than read continuously. That distinction is what most of this file is
## about, and it is not cosmetic: a budget that moves under the player mid-turn
## cannot be planned against, and planning a turn around it is the whole point.

var _context : GameContext

func before_each() -> void:
	_context = _context_showing([4, 2, 6, 1, 5, 3])

## A context whose turn has already begun, so the budget is taken. FarkleGame
## does this in _begin_turn(); there is no game here, so the test does it.
func _context_showing(values : Array) -> GameContext:
	var rng := RngService.new(99)
	var pool := DicePool.new(StarterDice.create_starter_bag(values.size()), rng)
	var context := GameContext.new(pool, rng)
	_set_faces(context, values)
	context.snapshot_energy()
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

## The rule the snapshot exists for. Spend nine, push into a terrible roll, and
## the budget that paid for it must not shrink out from under what was already
## bought — the card has been played and the points are already on the board.
func test_a_worse_roll_cannot_take_back_energy_already_spent() -> void:
	_context.spend_energy(9)
	_set_faces(_context, [1, 1, 1, 1, 1, 1])
	_context.pool.rolled.emit([] as Array[Die])
	assert_eq(_context.total_energy(), 21, "the budget was taken at the top of the turn")
	assert_eq(_context.available_energy(), 12, "and what is left is untouched")

## A push happens inside a turn, and the turn's budget was already decided. Six
## 1s rolled halfway through are a bad roll, not a smaller wallet.
func test_pushing_does_not_re_take_the_budget() -> void:
	_set_faces(_context, [1, 1, 1, 1, 1, 1])
	assert_eq(_context.total_energy(), 21, "still the opening roll's pips")

func test_taking_the_budget_announces_it() -> void:
	var fired := [0]
	_context.energy_changed.connect(func() -> void: fired[0] += 1)
	_context.snapshot_energy()
	assert_eq(fired[0], 1, "the row has something new to draw")

func test_energy_never_reads_as_negative() -> void:
	_context.spend_energy(21)
	_context.energy_spent = 999
	assert_eq(_context.available_energy(), 0, "floored, not negative")

func test_a_turn_starts_with_a_clean_slate() -> void:
	_context.spend_energy(10)
	_context.advance_turn()
	assert_eq(_context.available_energy(), 21, "what was spent belonged to the old turn")

## A fresh context has no budget until its first turn has rolled. Nothing should
## be affordable in that gap, or a card could be played onto an empty table.
func test_there_is_no_budget_before_the_first_roll() -> void:
	var rng := RngService.new(99)
	var pool := DicePool.new(StarterDice.create_starter_bag(6), rng)
	var context := GameContext.new(pool, rng)
	assert_eq(context.total_energy(), 0, "nothing has been rolled")
	assert_false(context.can_afford(1), "so nothing is affordable")
