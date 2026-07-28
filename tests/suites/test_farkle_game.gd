extends TestCase
## The turn loop: rolling, setting aside, hot dice, busting, banking, and the
## two ways a level ends.
##
## Every test here drives a real FarkleGame. That is the whole point of keeping
## the engine headless — if a level cannot be played to a win without a frame
## being drawn, the balance probe cannot measure the difficulty curve either.

# --- fixtures --------------------------------------------------------------

## A level with plain dice and a target, played over [param turns] turns.
func make_ruleset(
	target : int = 1000,
	turns : int = 5,
	dice_count : int = 6
) -> Ruleset:
	var ruleset := Ruleset.new()
	ruleset.id = &"test"
	ruleset.dice_count = dice_count
	ruleset.turns = turns
	var objective := ScoreTargetObjective.new()
	objective.target_score = target
	ruleset.objective = objective
	return ruleset

func make_game(ruleset : Ruleset = null, seed_value : int = 1) -> FarkleGame:
	var rules := ruleset if ruleset != null else make_ruleset()
	return FarkleGame.new(rules, RngService.new(seed_value))

## Forces the dice in play onto known faces, so a test can set up an exact
## board instead of hunting for a seed that produces one.
func force_faces(game : FarkleGame, values : Array) -> void:
	var in_play := game.get_dice_in_play()
	for i in mini(values.size(), in_play.size()):
		in_play[i].current_face = _face(int(values[i]))
	# The element rules and the selection score both read the dice, so they have
	# to be rebuilt after the board is rewritten under them.
	game.rules = ElementRules.new(game.get_dice_in_play())

func _face(value : int) -> DieFace:
	return DieFace.create(StringName("pip_%d" % value), value, str(value))

## Takes everything that scores and commits it.
func take_all(game : FarkleGame) -> void:
	game.select_all_scoring()
	game.commit_selection()

# --- starting --------------------------------------------------------------

func test_a_game_starts_with_six_dice_in_play() -> void:
	var game := make_game()
	game.start()
	assert_eq(game.get_dice().size(), 6, "six dice")
	assert_eq(game.get_dice_in_play().size(), 6, "all in play")

func test_a_game_starts_on_turn_one_with_nothing_scored() -> void:
	var game := make_game()
	game.start()
	assert_eq(game.context.turn, 1, "turn 1")
	assert_eq(game.context.banked_score, 0, "nothing banked")
	assert_eq(game.context.turn_score, 0, "nothing riding")

func test_starting_rolls_the_dice() -> void:
	var game := make_game()
	game.start()
	for die in game.get_dice():
		assert_true(die.get_value() > 0, "every die has a face")

# --- selecting -------------------------------------------------------------

func test_only_scoring_dice_can_be_selected() -> void:
	var game := make_game()
	game.start()
	force_faces(game, [1, 2, 3, 4, 6, 6])
	var in_play := game.get_dice_in_play()
	assert_true(game.can_select(in_play[0]), "the 1 scores")
	assert_false(game.can_select(in_play[1]), "the 2 does not")
	assert_false(game.can_select(in_play[4]), "a pair of 6s is not a set")

func test_selecting_is_reversible() -> void:
	var game := make_game()
	game.start()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	var die : Die = game.get_dice_in_play()[0]
	game.toggle_selection(die)
	assert_true(game.is_selected(die), "marked")
	game.toggle_selection(die)
	assert_false(game.is_selected(die), "unmarked")
	assert_eq(game.context.turn_score, 0, "nothing was spent either way")

func test_select_all_scoring_takes_everything_that_counts() -> void:
	var game := make_game()
	game.start()
	force_faces(game, [1, 5, 3, 4, 4, 4])
	game.select_all_scoring()
	assert_eq(game.get_selection().size(), 5, "the 1, the 5 and three 4s")
	assert_eq(game.selection_score.total(), 550, "100 + 50 + 400")

# --- committing ------------------------------------------------------------

func test_committing_moves_points_to_the_turn_score() -> void:
	var game := make_game()
	game.start()
	force_faces(game, [1, 2, 3, 4, 6, 2])
	take_all(game)
	assert_eq(game.context.turn_score, 100, "the 1")
	assert_eq(game.context.banked_score, 0, "not banked yet")

func test_committing_takes_the_dice_off_the_table() -> void:
	var game := make_game()
	game.start()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	take_all(game)
	assert_eq(game.get_dice_in_play().size(), 4, "two 1s set aside")
	assert_eq(game.context.pool.set_aside_count(), 2, "and accounted for")

func test_an_empty_selection_cannot_be_committed() -> void:
	var game := make_game()
	game.start()
	force_faces(game, [1, 2, 3, 4, 6, 2])
	assert_false(game.can_commit_selection(), "nothing marked")
	assert_false(game.commit_selection(), "and nothing happens")

# --- pushing ---------------------------------------------------------------

func test_pushing_needs_something_committed_first() -> void:
	var game := make_game()
	game.start()
	force_faces(game, [1, 2, 3, 4, 6, 2])
	assert_false(game.can_push(), "a free reroll would break the whole game")

func test_pushing_rolls_the_dice_that_are_left() -> void:
	var game := make_game()
	game.start()
	force_faces(game, [1, 2, 3, 4, 6, 2])
	take_all(game)
	assert_true(game.can_push(), "one die committed")
	game.push()
	assert_eq(game.get_dice_in_play().size(), 5, "five still rolling")

## Both outcomes assert, because a push has exactly two and either branch on its
## own leaves the test vacuous whenever the dice go the other way — which is how
## this one spent a while asserting nothing at all.
func test_pushing_either_keeps_the_turn_score_or_farkles_it_away() -> void:
	var game := make_game()
	game.start()
	force_faces(game, [1, 2, 3, 4, 6, 2])
	take_all(game)
	var before := game.context.turn_score
	game.push()
	if game.state == FarkleGame.State.FARKLED:
		assert_eq(game.context.turn_score, 0, "a Farkle takes all of it")
	else:
		assert_eq(game.context.turn_score, before, "otherwise it is all still riding")

# --- hot dice --------------------------------------------------------------

func test_clearing_the_table_brings_every_die_back() -> void:
	var game := make_game()
	game.start()
	force_faces(game, [1, 1, 1, 5, 5, 5])
	take_all(game)
	assert_eq(game.get_dice_in_play().size(), 6, "all six back")
	assert_eq(game.context.pool.set_aside_count(), 0, "nothing set aside")

## Three 1s and three 5s: 1000 + 500, carried through the hot dice reroll. The
## fresh roll can immediately Farkle it away again, so both branches assert.
func test_hot_dice_keep_the_turn_score() -> void:
	var game := make_game()
	game.start()
	force_faces(game, [1, 1, 1, 5, 5, 5])
	take_all(game)
	if game.state == FarkleGame.State.FARKLED:
		assert_eq(game.context.turn_score, 0, "the fresh roll took it back")
	else:
		assert_eq(game.context.turn_score, 1500, "carried into the new roll")

# --- farkle ----------------------------------------------------------------

func test_a_roll_that_scores_nothing_farkles() -> void:
	var game := make_game()
	game.start()
	force_faces(game, [2, 2, 3, 4, 6, 6])
	# Re-running the check is what a push would do, without the randomness.
	assert_eq(game.get_scorable_dice().size(), 0, "nothing to take")

func test_a_farkle_wipes_the_turn_score() -> void:
	var ruleset := make_ruleset(100000, 5)
	var game := make_game(ruleset)
	game.start()
	# Push until a Farkle happens. The target is unreachable so the level cannot
	# end underneath the loop.
	var guard := 0
	while game.state != FarkleGame.State.FARKLED and guard < 500:
		guard += 1
		if game.get_scorable_dice().is_empty():
			break
		take_all(game)
		if game.state == FarkleGame.State.CHOOSING and game.can_push():
			game.push()
	assert_true(guard < 500, "a Farkle is reachable at all")
	assert_eq(game.state, FarkleGame.State.FARKLED, "the turn died")
	assert_eq(game.context.turn_score, 0, "the points went with it")

func test_a_farkle_charges_the_penalty_against_banked_points() -> void:
	var ruleset := make_ruleset(100000, 5)
	ruleset.farkle_penalty = 100
	var game := make_game(ruleset)
	game.start()
	game.context.banked_score = 500
	game.context.lose_turn_score(game.rules.farkle_penalty(ruleset.farkle_penalty))
	assert_eq(game.context.banked_score, 400, "100 off the bank")

func test_the_banked_score_never_goes_negative() -> void:
	var game := make_game()
	game.start()
	game.context.banked_score = 50
	game.context.lose_turn_score(100)
	assert_eq(game.context.banked_score, 0, "floored, not in debt")

func test_a_farkle_has_to_be_acknowledged_before_the_turn_moves_on() -> void:
	var ruleset := make_ruleset(100000, 5)
	var game := make_game(ruleset)
	game.start()
	force_faces(game, [2, 2, 3, 4, 6, 6])
	game._farkle()
	assert_eq(game.state, FarkleGame.State.FARKLED, "stopped")
	var turn_before := game.context.turn
	game.continue_after_farkle()
	assert_eq(game.context.turn, turn_before + 1, "then it moves on")

# --- banking ---------------------------------------------------------------

func test_banking_makes_the_turn_score_safe() -> void:
	var game := make_game(make_ruleset(100000, 5))
	game.start()
	force_faces(game, [1, 2, 3, 4, 6, 2])
	take_all(game)
	game.bank()
	assert_eq(game.context.banked_score, 100, "banked")
	assert_eq(game.context.turn_score, 0, "nothing riding")

func test_banking_ends_the_turn() -> void:
	var game := make_game(make_ruleset(100000, 5))
	game.start()
	force_faces(game, [1, 2, 3, 4, 6, 2])
	take_all(game)
	game.bank()
	assert_eq(game.context.turn, 2, "next turn")
	assert_eq(game.get_dice_in_play().size(), 6, "with a full table")

func test_nothing_can_be_banked_before_anything_scores() -> void:
	var game := make_game()
	game.start()
	assert_false(game.can_bank(), "an empty turn is not a bank")

func test_an_uncommitted_selection_cannot_be_banked() -> void:
	var game := make_game(make_ruleset(100000, 5))
	game.start()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	take_all(game)
	# Mark a second die but do not commit it.
	force_faces(game, [1, 3, 4, 6])
	var in_play := game.get_dice_in_play()
	game.toggle_selection(in_play[0])
	assert_false(game.can_bank(), "commit it or drop it first")

func test_a_minimum_bank_blocks_a_small_turn() -> void:
	var ruleset := make_ruleset(100000, 5)
	ruleset.minimum_bank = 500
	var game := make_game(ruleset)
	game.start()
	force_faces(game, [1, 2, 3, 4, 6, 2])
	take_all(game)
	assert_false(game.can_bank(), "100 is not enough")
	assert_eq(game.get_bank_requirement_text(), "Reach 500 to bank", "and it says so")

# --- winning and losing ----------------------------------------------------

func test_banking_the_target_wins_the_level() -> void:
	var game := make_game(make_ruleset(100, 5))
	game.start()
	force_faces(game, [1, 2, 3, 4, 6, 2])
	take_all(game)
	game.bank()
	assert_eq(game.state, FarkleGame.State.WON, "cleared")

func test_a_win_on_the_last_turn_is_still_a_win() -> void:
	# The order of the two checks in _end_turn is what this pins: winning is
	# tested before running out of turns.
	var game := make_game(make_ruleset(100, 1))
	game.start()
	force_faces(game, [1, 2, 3, 4, 6, 2])
	take_all(game)
	game.bank()
	assert_eq(game.state, FarkleGame.State.WON, "not a loss")

func test_running_out_of_turns_short_of_the_target_loses() -> void:
	var game := make_game(make_ruleset(100000, 1))
	game.start()
	force_faces(game, [1, 2, 3, 4, 6, 2])
	take_all(game)
	game.bank()
	assert_eq(game.state, FarkleGame.State.LOST, "out of turns")

func test_a_level_with_no_turn_limit_never_runs_out() -> void:
	var ruleset := make_ruleset(100000, 0)
	var game := make_game(ruleset)
	game.start()
	assert_eq(game.context.turns_left(), -1, "unlimited")
	assert_true(game.context.has_turns_left(), "always")

# --- objective -------------------------------------------------------------

func test_the_objective_reads_banked_points_not_riding_ones() -> void:
	var game := make_game(make_ruleset(100, 5))
	game.start()
	force_faces(game, [1, 2, 3, 4, 6, 2])
	take_all(game)
	assert_false(game.get_objective().is_met(game.context), "100 is riding, not won")
	game.bank()
	assert_true(game.get_objective().is_met(game.context), "now it is won")

func test_progress_shows_what_banking_now_would_give() -> void:
	var game := make_game(make_ruleset(1000, 5))
	game.start()
	force_faces(game, [1, 2, 3, 4, 6, 2])
	take_all(game)
	assert_eq(
		game.get_objective().get_progress_text(game.context),
		"100 / 1000",
		"the projected score"
	)

# --- bosses ----------------------------------------------------------------

func test_an_element_lock_hides_dice_of_other_elements() -> void:
	var ruleset := make_ruleset(100000, 5)
	ruleset.bag_definition = StarterDice.create_element_bag(Element.FIRE, 3)
	var lock := ElementLockModifier.new()
	lock.element = Element.FIRE
	ruleset.modifiers = [lock] as Array[LevelModifier]

	var game := make_game(ruleset)
	game.start()
	# Three Fire dice first, then three plain. Only the Fire 1 may be taken.
	force_faces(game, [1, 2, 3, 1, 4, 6])
	var scorable := game.get_scorable_dice()
	assert_eq(scorable.size(), 1, "one takeable die")
	assert_eq(scorable[0].element, Element.FIRE, "and it is the Fire one")

func test_an_element_lock_can_turn_a_scoring_roll_into_a_farkle() -> void:
	var ruleset := make_ruleset(100000, 5)
	ruleset.bag_definition = StarterDice.create_element_bag(Element.FIRE, 3)
	var lock := ElementLockModifier.new()
	lock.element = Element.FIRE
	ruleset.modifiers = [lock] as Array[LevelModifier]

	var game := make_game(ruleset)
	game.start()
	# The 1 and the 5 are both on plain dice, so nothing may be taken. The sixth
	# die repeats a 5 rather than showing a 6 on purpose: 1-6 would be a
	# straight, and a straight scores every die on the table.
	force_faces(game, [2, 3, 4, 1, 5, 5])
	assert_eq(game.get_scorable_dice().size(), 0, "a Farkle in all but name")

## A straight scores all six dice, so filtering the Fire ones back out of it
## would leave three dice that look takeable and form nothing. The boss has to
## narrow the field before the scorer sees it, and this pins that.
func test_an_element_lock_does_not_offer_a_broken_straight() -> void:
	var ruleset := make_ruleset(100000, 5)
	ruleset.bag_definition = StarterDice.create_element_bag(Element.FIRE, 3)
	var lock := ElementLockModifier.new()
	lock.element = Element.FIRE
	ruleset.modifiers = [lock] as Array[LevelModifier]

	var game := make_game(ruleset)
	game.start()
	force_faces(game, [2, 3, 4, 1, 5, 6])
	for die in game.get_scorable_dice():
		assert_true(game.can_select(die), "offered dice can be selected")
	game.select_all_scoring()
	assert_true(
		game.get_selection().is_empty() or game.can_commit_selection(),
		"and anything selectable can be committed"
	)

# --- elements in play ------------------------------------------------------

func test_nature_hands_a_die_back_after_committing() -> void:
	var ruleset := make_ruleset(100000, 5)
	ruleset.bag_definition = StarterDice.create_element_bag(Element.NATURE, 2)
	var game := make_game(ruleset)
	game.start()
	# The two Nature dice show 1 and 5: six pips, so one die comes back. The
	# plain dice deliberately repeat a 4 — 1-6 would be a straight, which scores
	# every die and would make this a test of hot dice instead.
	force_faces(game, [1, 5, 2, 3, 4, 4])
	game.select_all_scoring()
	assert_eq(game.selection_score.dice_restored, 1, "Nature pays a die")
	game.commit_selection()
	assert_eq(game.get_dice_in_play().size(), 5, "four would be left without it")

func test_the_element_rules_are_rebuilt_for_the_dice_on_the_table() -> void:
	var ruleset := make_ruleset(100000, 5)
	ruleset.bag_definition = StarterDice.create_element_bag(Element.ICE, 3)
	var game := make_game(ruleset)
	game.start()
	assert_true(game.rules.has_trio(Element.ICE), "three Ice dice in play")
	assert_true(game.rules.pairs_score(), "so pairs score")
