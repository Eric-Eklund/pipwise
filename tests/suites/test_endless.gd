extends TestCase
## Endless mode's escalation.
##
## The campaign caps its target because an unclearable level is a bug. Endless
## is the opposite: it is supposed to outrun the player eventually, and these
## tests pin that it actually does.

const C := PokerHandClassifier.Category

var _run : EndlessRun

func before_each() -> void:
	_run = EndlessRun.new()

# --- the target ---------------------------------------------------------

func test_the_first_round_starts_at_the_base() -> void:
	assert_eq(_run.target_for(1), _run.base_target)

func test_the_target_climbs_every_round() -> void:
	var previous := 0
	for round_number in range(1, 60):
		var target := _run.target_for(round_number)
		if round_number > 1 and target <= previous:
			fail("round %d did not raise the target" % round_number)
			return
		previous = target
	assert_true(true, "the target keeps climbing")

## Nothing caps it, which is what eventually ends a run. A ceiling here would
## mean a player who reaches it never loses.
func test_the_target_has_no_ceiling() -> void:
	assert_true(
		_run.target_for(200) > 1000,
		"got %d at round 200" % _run.target_for(200)
	)

# --- tightening ---------------------------------------------------------

func test_rerolls_are_taken_away_but_never_all_of_them() -> void:
	assert_eq(_run.rerolls_for(1), 3)
	assert_eq(_run.rerolls_for(_run.rounds_per_reroll_cut + 1), 2)
	assert_eq(_run.rerolls_for(_run.rounds_per_reroll_cut * 2 + 1), 1)
	assert_eq(_run.rerolls_for(500), _run.minimum_rerolls, "and it stops there")

func test_dice_are_taken_away_but_never_all_of_them() -> void:
	assert_eq(_run.dice_for(1), 6)
	assert_eq(_run.dice_for(_run.rounds_per_die_cut + 1), 5)
	assert_eq(_run.dice_for(500), _run.minimum_dice, "and it stops there")

func test_resources_only_ever_tighten() -> void:
	var rerolls := 99
	var dice := 99
	for round_number in range(1, 80):
		var next_rerolls := _run.rerolls_for(round_number)
		var next_dice := _run.dice_for(round_number)
		if next_rerolls > rerolls or next_dice > dice:
			fail("round %d handed something back" % round_number)
			return
		rerolls = next_rerolls
		dice = next_dice
	assert_true(true)

func test_shape_demands_arrive_and_then_harden() -> void:
	assert_eq(_run.demand_for(1), -1, "early rounds ask only for a number")
	assert_eq(_run.demand_for(_run.pair_from_round), C.PAIR)
	assert_eq(_run.demand_for(_run.two_pair_from_round), C.TWO_PAIR)

# --- the rulesets it builds ---------------------------------------------

func test_every_round_produces_a_playable_ruleset() -> void:
	for round_number in range(1, 60):
		var ruleset := _run.get_ruleset(round_number)
		if ruleset.dice_count < 1 or ruleset.hand_size < 1:
			fail("round %d is malformed" % round_number)
			return
		if ruleset.get_objective().target_score <= 0:
			fail("round %d has no target" % round_number)
			return
	assert_true(true, "60 rounds all build cleanly")

func test_an_early_round_only_asks_for_a_number() -> void:
	assert_true(_run.get_ruleset(1).get_objective() is ScoreTargetObjective)

func test_a_late_round_asks_for_a_shape() -> void:
	var objective := _run.get_ruleset(_run.two_pair_from_round).get_objective()
	assert_true(objective is RequiredCategoryObjective)
	assert_eq((objective as RequiredCategoryObjective).minimum_category, C.TWO_PAIR)

func test_rounds_are_playable_end_to_end() -> void:
	for round_number in [1, 5, 12, 25]:
		var game := CardDiceGame.new(
			_run.get_ruleset(round_number), RngService.new(round_number * 17)
		)
		game.start()
		assert_true(game.can_save_hand(), "round %d cannot be saved" % round_number)
		game.save_hand()
		assert_true(
			game.state == CardDiceGame.State.WON or game.state == CardDiceGame.State.LOST,
			"round %d reached no verdict" % round_number
		)

## A run has to be losable, or the mode has no score. Round 40 asks for far
## more than a hand can produce, so no seed clears it.
func test_a_run_eventually_becomes_unwinnable() -> void:
	var wins := 0
	for seed_value in range(1, 40):
		var game := CardDiceGame.new(_run.get_ruleset(40), RngService.new(seed_value))
		game.start()
		game.save_hand()
		if game.state == CardDiceGame.State.WON:
			wins += 1
	assert_eq(wins, 0, "round 40 was cleared %d times out of 39" % wins)
