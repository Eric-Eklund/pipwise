extends TestCase
## ScoreTargetObjective is the only objective so far, but Objective is
## polymorphic on purpose. These tests pin the boundary conditions, which is
## where an off-by-one would otherwise hide.

func _context(score : int) -> GameContext:
	var rng := RngService.new(12)
	var context := GameContext.new(
		Deck.new(DeckDefinition.create_standard_52(), rng),
		Hand.new(5),
		DicePool.new(StarterDice.create_starter_bag(6), rng),
		rng
	)
	context.score = score
	return context

func _objective(target : int) -> ScoreTargetObjective:
	var objective := ScoreTargetObjective.new()
	objective.target_score = target
	return objective

func test_is_met_exactly_at_the_target() -> void:
	assert_true(_objective(300).is_met(_context(300)), "reaching the target counts as met")

func test_is_met_above_the_target() -> void:
	assert_true(_objective(300).is_met(_context(301)))

func test_is_not_met_one_short() -> void:
	assert_false(_objective(300).is_met(_context(299)))

func test_progress_text_reports_both_numbers() -> void:
	var text := _objective(300).get_progress_text(_context(120))
	assert_true(text.contains("120") and text.contains("300"), "got \"%s\"" % text)

## The progress text reads the live score, so it moves while the player is
## still deciding rather than only after the hand is saved.
func test_progress_text_follows_the_live_score() -> void:
	var context := _context(0)
	var objective := _objective(300)
	assert_true(objective.get_progress_text(context).contains("0"))
	context.score = 180
	assert_true(objective.get_progress_text(context).contains("180"))

func test_description_states_the_goal() -> void:
	assert_true(_objective(300).get_description().contains("300"))

func test_base_objective_is_never_met() -> void:
	# The abstract base is inert rather than erroring, so a level configured
	# with it is unwinnable. Pinned so the behaviour is a choice.
	assert_false(Objective.new().is_met(_context(9999)))
