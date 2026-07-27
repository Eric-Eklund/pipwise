extends TestCase
## The whole loop, driven headless. This is what the engine/view split was for:
## a level can be played to a win or a loss without rendering a frame.

const SEED := 90210

func _ruleset(target : int) -> Ruleset:
	var ruleset := Ruleset.new()
	ruleset.hand_size = 5
	ruleset.dice_count = 6
	ruleset.max_rerolls = 3
	ruleset.evaluator = PokerHandEvaluator.new()
	var objective := ScoreTargetObjective.new()
	objective.target_score = target
	ruleset.objective = objective
	return ruleset

func _started(target : int) -> CardDiceGame:
	var game := CardDiceGame.new(_ruleset(target), RngService.new(SEED))
	game.start()
	return game

func _select_first(game : CardDiceGame, count : int = 1) -> void:
	for i in count:
		game.context.hand.toggle_selection(game.context.hand.cards[i])

## Forces the dice onto known faces so a test can reason about the budget.
func _show_dice(game : CardDiceGame, values : Array) -> void:
	for i in values.size():
		game.context.pool.dice[i].current_face = DieFace.create(&"fixed", int(values[i]))

# --- setup --------------------------------------------------------------

func test_start_deals_a_full_hand_and_rolls_every_die() -> void:
	var game := _started(1000)
	assert_eq(game.context.hand.size(), 5)
	assert_eq(game.get_dice().size(), 6)
	assert_true(game.context.total_energy() >= 6, "every die shows something")
	assert_eq(game.state, CardDiceGame.State.PLAYING)

func test_ruleset_falls_back_to_a_standard_deck_and_bag() -> void:
	# The shipped level rulesets leave both null, so this is the live path.
	var game := _started(1000)
	assert_eq(game.context.deck.total_size(), 47, "52 minus the opening hand")
	assert_eq(game.get_pool().size(), 6)

# --- which cards are carrying the hand ----------------------------------

func _scoring_count(game : CardDiceGame) -> int:
	var count := 0
	for card in game.context.hand.cards:
		if card.is_scoring:
			count += 1
	return count

func test_the_carrying_cards_are_marked_from_the_start() -> void:
	var game := _started(1000)
	assert_true(_scoring_count(game) >= 1, "something is always carrying the hand")
	assert_eq(_scoring_count(game), game.preview.scoring_cards.size())

func test_the_marks_follow_a_swap() -> void:
	var game := _started(1000)
	_select_first(game, 2)
	game.swap_selected()
	assert_eq(
		_scoring_count(game), game.preview.scoring_cards.size(),
		"recomputed against the new hand"
	)

func test_a_card_that_leaves_the_hand_stops_carrying_it() -> void:
	var game := _started(1000)
	# Mark whatever is currently scoring, then throw it away.
	for card in game.context.hand.cards:
		if card.is_scoring:
			game.context.hand.toggle_selection(card)
	var discarded := game.context.hand.get_selected()
	if discarded.is_empty():
		fail("nothing was scoring to begin with")
		return
	game.swap_selected()
	for card in discarded:
		assert_false(card.is_scoring, "%s left the hand still marked" % card)

func test_only_the_pair_carries_a_pair() -> void:
	var game := _started(1000)
	# Force a known hand: two kings and three unrelated cards.
	game.context.hand.cards = [
		Card.new(CardData.create(13, CardData.SPADES)),
		Card.new(CardData.create(13, CardData.HEARTS)),
		Card.new(CardData.create(4, CardData.DIAMONDS)),
		Card.new(CardData.create(3, CardData.CLUBS)),
		Card.new(CardData.create(2, CardData.SPADES)),
	]
	game._refresh_score()
	assert_eq(game.preview.label, "Pair")
	assert_eq(_scoring_count(game), 2)
	for card in game.context.hand.cards:
		assert_eq(card.is_scoring, card.data.rank == 13, str(card))

func test_the_preview_is_kept_rather_than_recomputed() -> void:
	var game := _started(1000)
	assert_not_null(game.preview)
	assert_eq(game.preview.total(), game.context.score)

func test_the_score_is_live_before_anything_is_saved() -> void:
	var game := _started(1000)
	assert_true(game.context.score > 0, "the hand on the table is already worth something")
	assert_eq(game.context.score, game.preview_score().total())

# --- swapping cards -----------------------------------------------------

func test_swapping_costs_three_energy_a_card() -> void:
	var game := _started(1000)
	_select_first(game, 2)
	assert_eq(game.selected_swap_cost(), 6)
	var before := game.context.available_energy()
	assert_true(game.swap_selected())
	assert_eq(game.context.available_energy(), before - 6)

func test_swapping_replaces_the_marked_cards_and_refills() -> void:
	var game := _started(1000)
	var kept := game.context.hand.cards[4].get_id()
	_select_first(game, 2)
	game.swap_selected()
	assert_eq(game.context.hand.size(), 5, "dealt back up to full")
	assert_eq(game.context.hand.cards[2].get_id(), kept, "unmarked cards stayed")
	assert_eq(game.context.hand.selected_count(), 0, "and the marks are gone")

func test_swapping_nothing_is_refused() -> void:
	var game := _started(1000)
	assert_false(game.can_swap_selected(), "nothing is marked")
	assert_false(game.swap_selected())

func test_a_swap_the_player_cannot_afford_is_refused() -> void:
	var game := _started(1000)
	_show_dice(game, [1, 1, 1, 1, 1, 1])
	# 6 energy buys two swaps, not three.
	_select_first(game, 3)
	assert_eq(game.selected_swap_cost(), 9)
	assert_false(game.can_swap_selected())
	assert_false(game.swap_selected())
	assert_eq(game.context.energy_spent, 0, "and cost nothing to find out")

func test_swapping_updates_the_live_score() -> void:
	var game := _started(1000)
	_select_first(game, 2)
	game.swap_selected()
	assert_eq(game.context.score, game.preview_score().total())

# --- locking dice -------------------------------------------------------

func test_locking_a_die_costs_four_energy() -> void:
	var game := _started(1000)
	var before := game.context.available_energy()
	assert_true(game.toggle_lock(game.get_dice()[0]))
	assert_true(game.get_dice()[0].is_locked)
	assert_eq(game.context.available_energy(), before - 4)

func test_unlocking_a_die_hands_the_energy_back() -> void:
	var game := _started(1000)
	var before := game.context.available_energy()
	var die := game.get_dice()[0]
	game.toggle_lock(die)
	game.toggle_lock(die)
	assert_false(die.is_locked)
	assert_eq(game.context.available_energy(), before, "changing your mind is free")

func test_a_lock_the_player_cannot_afford_is_refused() -> void:
	var game := _started(1000)
	_show_dice(game, [1, 1, 1, 1, 1, 1])
	game.context.spend_energy(4)
	# 2 left, and a lock costs 4.
	assert_false(game.can_toggle_lock(game.get_dice()[0]))
	assert_false(game.toggle_lock(game.get_dice()[0]))

func test_a_frozen_die_cannot_be_locked_at_any_price() -> void:
	var game := _started(1000)
	var die := game.get_pool().freeze_random(1)[0]
	assert_false(game.can_toggle_lock(die))
	assert_false(game.toggle_lock(die))
	assert_eq(game.context.energy_spent, 0)

# --- rerolling ----------------------------------------------------------

func test_a_reroll_is_free_but_counted() -> void:
	var game := _started(1000)
	assert_eq(game.rerolls_left(), 3)
	assert_true(game.reroll())
	assert_eq(game.rerolls_left(), 2)
	assert_eq(game.context.energy_spent, 0, "rerolls cost no energy")

func test_rerolls_run_out_after_three() -> void:
	var game := _started(1000)
	for _i in 3:
		assert_true(game.reroll())
	assert_false(game.can_reroll())
	assert_false(game.reroll())

func test_a_locked_die_survives_a_reroll() -> void:
	var game := _started(1000)
	var die := game.get_dice()[0]
	game.toggle_lock(die)
	var kept := die.get_value()
	game.reroll()
	assert_eq(die.get_value(), kept)

func test_a_reroll_updates_the_live_score() -> void:
	var game := _started(1000)
	game.reroll()
	assert_eq(game.context.score, game.preview_score().total())

# --- outcomes -----------------------------------------------------------

func test_clearing_the_target_wins() -> void:
	var game := _started(1)
	var won := [false]
	game.game_won.connect(func() -> void: won[0] = true)
	game.save_hand()
	assert_true(won[0], "any hand clears a target of 1")
	assert_eq(game.state, CardDiceGame.State.WON)

func test_falling_short_loses() -> void:
	var game := _started(1000000)
	var lost := [false]
	game.game_lost.connect(func() -> void: lost[0] = true)
	game.save_hand()
	assert_true(lost[0], "one hand cannot reach a million")
	assert_eq(game.state, CardDiceGame.State.LOST)

func test_saving_reports_the_score_it_locked_in() -> void:
	var game := _started(1)
	var reported : Array[HandScore] = []
	game.hand_saved.connect(func(score : HandScore) -> void: reported.append(score))
	game.save_hand()
	assert_eq(reported.size(), 1)
	assert_eq(reported[0].total(), game.context.score)
	assert_eq(game.last_score.total(), game.context.score)

func test_a_level_is_one_hand() -> void:
	var game := _started(1)
	game.save_hand()
	var score_at_win := game.context.score
	game.save_hand()
	assert_eq(game.context.score, score_at_win, "the second save does nothing")

func test_a_finished_level_accepts_no_more_moves() -> void:
	var game := _started(1)
	game.save_hand()
	_select_first(game, 1)
	assert_false(game.can_swap_selected())
	assert_false(game.can_reroll())
	assert_false(game.can_toggle_lock(game.get_dice()[0]))

# --- boss hooks ---------------------------------------------------------

func test_a_modifier_can_block_saving() -> void:
	var ruleset := _ruleset(1)
	ruleset.modifiers = [_BlockingModifier.new()]
	var game := CardDiceGame.new(ruleset, RngService.new(SEED))
	game.start()
	assert_false(game.can_save_hand())
	assert_eq(game.get_save_requirement_text(), "Do the thing")
	game.save_hand()
	assert_eq(game.state, CardDiceGame.State.PLAYING, "still waiting")

func test_a_modifier_runs_at_level_start() -> void:
	var ruleset := _ruleset(1)
	var modifier := _FreezingModifier.new()
	ruleset.modifiers = [modifier]
	var game := CardDiceGame.new(ruleset, RngService.new(SEED))
	game.start()
	assert_eq(game.get_pool().frozen_count(), 1)
	assert_true(modifier.saw_a_rolled_die, "modifiers run after the opening roll")

# --- determinism --------------------------------------------------------

func test_the_same_seed_deals_the_same_opening_hand() -> void:
	var first := _started(1000)
	var second := _started(1000)
	for i in first.context.hand.size():
		if first.context.hand.cards[i].get_id() != second.context.hand.cards[i].get_id():
			fail("same seed diverged at card %d" % i)
			return
	assert_true(true, "the opening hands matched")

func test_the_same_seed_rolls_the_same_dice() -> void:
	assert_eq(_started(1000).context.total_energy(), _started(1000).context.total_energy())

## The deck is built and shuffled before the dice pool, on one shared
## RngService. Swapping those two lines would change every seeded outcome.
func test_deck_consumes_the_rng_before_the_dice() -> void:
	var rng := RngService.new(SEED)
	var expected := Deck.new(DeckDefinition.create_standard_52(), rng).draw(5)
	var game := _started(1000)
	for i in expected.size():
		if expected[i].get_id() != game.context.hand.cards[i].get_id():
			fail("the deck no longer draws the RNG first")
			return
	assert_true(true, "deck-then-dice ordering held")

# --- fixtures -----------------------------------------------------------

class _BlockingModifier extends LevelModifier:
	func can_save_hand(_context : GameContext) -> bool:
		return false

	func get_requirement_text(_context : GameContext) -> String:
		return "Do the thing"


class _FreezingModifier extends LevelModifier:
	var saw_a_rolled_die : bool = false

	func on_level_start(context : GameContext) -> void:
		saw_a_rolled_die = context.pool.total_value() > 0
		context.pool.freeze_random(1)
