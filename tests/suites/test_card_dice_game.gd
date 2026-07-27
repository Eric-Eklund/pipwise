extends TestCase
## The whole loop, driven headless. This is what the engine/view split was for:
## a level can be played to a win or a loss without rendering a frame.

const SEED := 90210

func _ruleset(target : int, plays : int = 4) -> Ruleset:
	var ruleset := Ruleset.new()
	ruleset.hand_size = 5
	ruleset.dice_per_turn = 2
	ruleset.max_plays = plays
	ruleset.evaluator = PokerHandEvaluator.new()
	var objective := ScoreTargetObjective.new()
	objective.target_score = target
	ruleset.objective = objective
	return ruleset

func _started(target : int, plays : int = 4) -> CardDiceGame:
	var game := CardDiceGame.new(_ruleset(target, plays), RngService.new(SEED))
	game.start()
	return game

func _select_first(game : CardDiceGame) -> void:
	game.context.hand.toggle_selection(game.context.hand.cards[0])

# --- setup --------------------------------------------------------------

func test_start_deals_a_full_hand_and_dice() -> void:
	var game := _started(1000)
	assert_eq(game.context.hand.size(), 5)
	assert_eq(game.drawn_dice.size(), 2)
	assert_eq(game.state, CardDiceGame.State.PLAYING)

func test_start_sets_plays_from_the_ruleset() -> void:
	assert_eq(_started(1000, 3).context.plays_left, 3)

func test_ruleset_falls_back_to_a_standard_deck_and_bag() -> void:
	# The shipped level rulesets leave both null, so this is the live path.
	var game := _started(1000)
	assert_eq(game.context.deck.total_size(), 47, "52 minus the opening hand")
	assert_eq(game.bag.total_size(), 4, "6 minus the two drawn dice")

# --- playing ------------------------------------------------------------

func test_cannot_play_without_a_selection() -> void:
	var game := _started(1000)
	assert_false(game.can_play(), "nothing is selected yet")

func test_play_scores_and_spends_a_play() -> void:
	var game := _started(1000)
	_select_first(game)
	assert_true(game.can_play())
	game.play_selected()
	assert_true(game.context.score > 0, "a played card is worth something")
	assert_eq(game.context.plays_left, 3)

func test_play_refills_the_hand() -> void:
	var game := _started(1000)
	_select_first(game)
	game.play_selected()
	assert_eq(game.context.hand.size(), 5, "the hand is dealt back up")

func test_play_deals_a_fresh_pair_of_dice() -> void:
	var game := _started(1000)
	_select_first(game)
	game.play_selected()
	assert_eq(game.drawn_dice.size(), 2)

func test_multiplier_is_consumed_by_the_hand_it_boosted() -> void:
	var game := _started(1000)
	game.context.score_multiplier = 3.0
	_select_first(game)
	var reported : Array[HandScore] = []
	game.hand_played.connect(func(score : HandScore) -> void: reported.append(score))
	game.play_selected()
	assert_eq(reported.size(), 1)
	assert_almost_eq(reported[0].multiplier, 3.0, 0.0001, "the played hand got the boost")
	assert_almost_eq(game.context.score_multiplier, 1.0, 0.0001, "and it reset afterwards")

# --- outcomes -----------------------------------------------------------

func test_reaching_the_target_wins() -> void:
	var game := _started(1)
	var won := [false]
	game.game_won.connect(func() -> void: won[0] = true)
	_select_first(game)
	game.play_selected()
	assert_true(won[0], "any play clears a target of 1")
	assert_eq(game.state, CardDiceGame.State.WON)

func test_running_out_of_plays_loses() -> void:
	var game := _started(1000000, 1)
	var lost := [false]
	game.game_lost.connect(func() -> void: lost[0] = true)
	_select_first(game)
	game.play_selected()
	assert_true(lost[0], "one play cannot reach a million")
	assert_eq(game.state, CardDiceGame.State.LOST)

func test_a_winning_play_does_not_deal_another_turn() -> void:
	var game := _started(1)
	var dice_before := game.drawn_dice
	_select_first(game)
	game.play_selected()
	assert_eq(game.drawn_dice, dice_before, "the outcome is judged before dealing")

func test_play_is_refused_once_the_game_is_over() -> void:
	var game := _started(1)
	_select_first(game)
	game.play_selected()
	var score_at_win := game.context.score
	_select_first(game)
	game.play_selected()
	assert_eq(game.context.score, score_at_win, "a finished game accepts no more plays")

# --- dice ---------------------------------------------------------------

func test_spending_a_die_marks_it_spent() -> void:
	var game := _started(1000)
	var die := game.drawn_dice[0]
	# The face is random, so force one with no precondition.
	var multiplier := ScoreMultiplierAction.new()
	multiplier.bonus = 0.5
	die.current_face = DieFace.create(&"test_mult", multiplier, "x1.5")
	assert_true(game.spend_die(die))
	assert_true(die.is_spent)
	assert_almost_eq(game.context.score_multiplier, 1.5)

func test_a_die_cannot_be_spent_twice() -> void:
	var game := _started(1000)
	var die := game.drawn_dice[0]
	var multiplier := ScoreMultiplierAction.new()
	multiplier.bonus = 0.5
	die.current_face = DieFace.create(&"test_mult", multiplier, "x1.5")
	game.spend_die(die)
	assert_false(game.spend_die(die), "the second attempt is refused")
	assert_almost_eq(game.context.score_multiplier, 1.5, 0.0001, "and had no effect")

func test_a_die_whose_action_cannot_run_is_refused() -> void:
	var game := _started(1000)
	var die := game.drawn_dice[0]
	# Lock needs a selection, and nothing is selected.
	die.current_face = DieFace.create(&"test_lock", LockCardAction.new(), "Lock")
	assert_false(game.spend_die(die))
	assert_false(die.is_spent)

# --- determinism --------------------------------------------------------

func test_the_same_seed_deals_the_same_opening_hand() -> void:
	var first := _started(1000)
	var second := _started(1000)
	for i in first.context.hand.size():
		if first.context.hand.cards[i].get_id() != second.context.hand.cards[i].get_id():
			fail("same seed diverged at card %d" % i)
			return
	assert_true(true, "the opening hands matched")

## The deck is built and shuffled before the bag, on one shared RngService.
## Swapping those two lines would change every seeded outcome in the game.
func test_deck_consumes_the_rng_before_the_bag() -> void:
	var rng := RngService.new(SEED)
	var expected := Deck.new(DeckDefinition.create_standard_52(), rng).draw(5)
	var game := _started(1000)
	for i in expected.size():
		if expected[i].get_id() != game.context.hand.cards[i].get_id():
			fail("the deck no longer draws the RNG first")
			return
	assert_true(true, "deck-then-bag ordering held")
