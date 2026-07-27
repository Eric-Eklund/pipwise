extends TestCase
## ScoreTargetObjective is the only objective so far, but Objective is
## polymorphic on purpose. These tests pin the boundary conditions, which is
## where an off-by-one would otherwise hide, and the split between the two
## questions a level asks.

func _context(banked : int, riding : int = 0, turn : int = 1, limit : int = 5) -> GameContext:
	var rng := RngService.new(12)
	var context := GameContext.new(DicePool.new(StarterDice.create_starter_bag(6), rng), rng)
	context.banked_score = banked
	context.turn_score = riding
	context.turn = turn
	context.turn_limit = limit
	return context

func _objective(target : int) -> ScoreTargetObjective:
	var objective := ScoreTargetObjective.new()
	objective.target_score = target
	return objective

# --- is_met ----------------------------------------------------------------

func test_is_met_exactly_at_the_target() -> void:
	assert_true(_objective(1000).is_met(_context(1000)), "reaching it counts")

func test_is_met_above_the_target() -> void:
	assert_true(_objective(1000).is_met(_context(1001)))

func test_is_not_met_one_short() -> void:
	assert_false(_objective(1000).is_met(_context(999)))

## The rule the whole push-your-luck loop rests on: points riding on a turn are
## not points won, so a turn worth the target does not end the level until it
## is banked.
func test_riding_points_do_not_win_the_level() -> void:
	assert_false(_objective(1000).is_met(_context(0, 5000)), "5000 at risk is not 5000")

# --- is_failed -------------------------------------------------------------

func test_a_level_is_not_failed_while_turns_remain() -> void:
	assert_false(_objective(1000).is_failed(_context(0, 0, 3, 5)), "two turns left")

func test_a_level_is_failed_once_the_turns_run_out_short() -> void:
	assert_true(_objective(1000).is_failed(_context(900, 0, 6, 5)), "out of turns")

func test_a_level_reached_on_the_last_turn_is_not_failed() -> void:
	assert_false(_objective(1000).is_failed(_context(1000, 0, 6, 5)), "cleared it")

func test_an_unlimited_level_never_fails() -> void:
	assert_false(_objective(1000).is_failed(_context(0, 0, 99, 0)), "no turn limit")

# --- readouts --------------------------------------------------------------

func test_progress_text_reports_both_numbers() -> void:
	var text := _objective(1000).get_progress_text(_context(400))
	assert_true(text.contains("400") and text.contains("1000"), "got \"%s\"" % text)

## The progress readout shows what banking right now would give, because that is
## the question the player is actually asking while deciding whether to push.
func test_progress_text_counts_the_points_still_riding() -> void:
	assert_eq(_objective(1000).get_progress_text(_context(400, 250)), "650 / 1000")

func test_progress_ratio_is_a_fraction_of_the_target() -> void:
	assert_true(is_equal_approx(_objective(1000).get_progress_ratio(_context(500)), 0.5))

func test_progress_ratio_is_capped_at_one() -> void:
	assert_true(is_equal_approx(_objective(1000).get_progress_ratio(_context(9999)), 1.0))

func test_description_states_the_goal() -> void:
	assert_true(_objective(1000).get_description().contains("1000"))

# --- the abstract base -----------------------------------------------------

## The base is inert rather than erroring, so a level configured with it is
## unwinnable but not broken. Pinned so the behaviour reads as a choice.
func test_the_base_objective_is_never_met_and_never_failed() -> void:
	assert_false(Objective.new().is_met(_context(99999)))
	assert_false(Objective.new().is_failed(_context(0, 0, 99, 5)))
