extends TestCase
## ScoreTargetObjective is the only objective so far, but Objective is
## polymorphic on purpose. These tests pin the boundary conditions, which is
## where an off-by-one would otherwise hide.

func _context(score : int, plays_left : int) -> GameContext:
	var rng := RngService.new(12)
	var context := GameContext.new(Deck.new(DeckDefinition.create_standard_52(), rng), Hand.new(5), rng)
	context.score = score
	context.plays_left = plays_left
	return context

func _objective(target : int) -> ScoreTargetObjective:
	var objective := ScoreTargetObjective.new()
	objective.target_score = target
	return objective

func test_is_met_exactly_at_the_target() -> void:
	assert_true(_objective(300).is_met(_context(300, 2)), "reaching the target counts as met")

func test_is_met_above_the_target() -> void:
	assert_true(_objective(300).is_met(_context(301, 2)))

func test_is_not_met_one_short() -> void:
	assert_false(_objective(300).is_met(_context(299, 2)))

func test_is_not_failed_while_plays_remain() -> void:
	assert_false(_objective(300).is_failed(_context(0, 1)), "one play left is still a chance")

func test_is_failed_when_plays_run_out_short() -> void:
	assert_true(_objective(300).is_failed(_context(299, 0)))

func test_is_not_failed_when_plays_run_out_on_target() -> void:
	assert_false(_objective(300).is_failed(_context(300, 0)), "hitting the target on the last play is a win")

func test_progress_text_reports_both_numbers() -> void:
	var text := _objective(300).get_progress_text(_context(120, 2))
	assert_true(text.contains("120") and text.contains("300"), "got \"%s\"" % text)

func test_base_objective_is_neither_met_nor_failed() -> void:
	# The abstract base is inert rather than erroring, so a level configured
	# with it is unwinnable and unloseable. Pinned so the behaviour is a choice.
	var base := Objective.new()
	assert_false(base.is_met(_context(9999, 0)))
	assert_false(base.is_failed(_context(0, 0)))
