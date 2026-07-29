extends TestCase
## What a card does to a turn, driven through a real FarkleGame.
##
## The catalogue itself is tested in test_card_library.gd. These are the ones
## that need a board: energy actually leaving the budget, a die arriving on the
## table, a shield surviving a bust, a card waiting for a die.

# --- fixtures --------------------------------------------------------------

func make_ruleset(bag : BagDefinition = null, turns : int = 5) -> Ruleset:
	var ruleset := Ruleset.new()
	ruleset.id = &"test_cards"
	ruleset.dice_count = 6
	ruleset.turns = turns
	ruleset.farkle_penalty = 100
	var objective := ScoreTargetObjective.new()
	objective.target_score = 100000
	ruleset.objective = objective
	if bag != null:
		ruleset.bag_definition = bag
	return ruleset

## A started game with a hand, the way FarkleLevel builds one.
##
## The budget is opened up rather than left at whatever the seed rolled: these
## tests are about what a card does, and a test that fails because the opening
## roll came in at eleven pips is a test about the seed.
func make_game(bag : BagDefinition = null) -> FarkleGame:
	var game := FarkleGame.new(make_ruleset(bag), RngService.new(1))
	game.hand = CardHand.create(RngService.new(4))
	game.start()
	game.context.energy_budget = 100
	return game

func force_faces(game : FarkleGame, values : Array) -> void:
	var in_play := game.get_dice_in_play()
	for i in mini(values.size(), in_play.size()):
		in_play[i].set_value(int(values[i]))
	game.rules = ElementRules.new(game.get_dice_in_play(), game.get_active_cards())

## Puts [param id] in hand and returns the card, so a test does not depend on
## what the deck happened to deal.
func give(game : FarkleGame, id : StringName) -> Card:
	game.hand.hand.append(id)
	return CardLibrary.by_id(id)

## Takes the scoring dice and banks them, which is the shortest road to the next
## turn that does not depend on what the seed rolled.
func take_and_bank(game : FarkleGame) -> void:
	game.select_all_scoring()
	game.commit_selection()
	game.bank()

# --- paying for a card -----------------------------------------------------

func test_playing_a_card_costs_its_energy() -> void:
	var game := make_game()
	var before := game.context.available_energy()
	var card := give(game, CardLibrary.FARKLE_SHIELD)
	assert_true(game.play_card(card), "played")
	assert_eq(game.context.available_energy(), before - card.energy_cost, "and paid for")

func test_a_card_leaves_the_hand_when_played() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.FARKLE_SHIELD)
	var before := game.hand.size()
	game.play_card(card)
	assert_eq(game.hand.size(), before - 1, "one fewer in hand")

func test_a_card_that_is_not_held_cannot_be_played() -> void:
	var game := make_game()
	while game.hand.discard(CardLibrary.FARKLE_SHIELD):
		pass
	assert_false(
		game.can_play_card(CardLibrary.by_id(CardLibrary.FARKLE_SHIELD)), "not in hand"
	)

func test_a_card_you_cannot_afford_is_refused_and_costs_nothing() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.FARKLE_SHIELD)
	game.context.energy_spent = game.context.total_energy()
	assert_false(game.can_play_card(card), "no energy left")
	assert_false(game.play_card(card), "so it is refused")
	assert_true(game.hand.holds(card.id), "and still in hand")

func test_a_card_you_cannot_afford_says_so() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.FARKLE_SHIELD)
	game.context.energy_spent = game.context.total_energy()
	assert_true(game.get_card_refusal(card).contains("⚡"), "the reason is the price")

func test_a_playable_card_has_nothing_to_explain() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.FARKLE_SHIELD)
	assert_eq(game.get_card_refusal(card), "", "nothing is in its way")

## A card played on a dead board would be paying to change a roll that has
## already failed. Farkle Shield in particular has to be bought before the roll
## it protects, or pushing costs nothing.
func test_no_card_can_be_played_after_a_farkle() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.FARKLE_SHIELD)
	force_faces(game, [2, 3, 4, 6, 6, 2])
	game._farkle()
	assert_eq(game.state, FarkleGame.State.FARKLED, "busted")
	assert_false(game.can_play_card(card), "and the card is too late")

## Endless mode is not part of a run, so it has no hand. Every card path has to
## survive that rather than assuming a run exists.
func test_a_game_without_a_hand_offers_no_cards() -> void:
	var game := FarkleGame.new(make_ruleset(), RngService.new(1))
	game.start()
	assert_eq(game.get_hand().size(), 0, "nothing to play")
	assert_false(
		game.can_play_card(CardLibrary.by_id(CardLibrary.LOCK_ALL)), "and no way to play it"
	)

# --- extra die -------------------------------------------------------------

func test_extra_die_puts_another_die_on_the_table() -> void:
	var game := make_game()
	var before := game.get_dice_in_play().size()
	assert_true(game.play_card(give(game, CardLibrary.EXTRA_DIE)), "played")
	assert_eq(game.get_dice_in_play().size(), before + 1, "one more in play")

## It arrives rolled. A die handed over blank shows nothing, scores nothing and
## cannot be pushed off — and the value cards would then have a target with no
## face to move.
func test_the_extra_die_arrives_rolled() -> void:
	var game := make_game()
	game.play_card(give(game, CardLibrary.EXTRA_DIE))
	for die in game.get_pool().get_lent():
		assert_true(die.get_value() > 0, "showing a face")
		assert_true(die.current_face in die.type.faces, "one its own type holds")

## Lent for the turn, not added to the bag. Every target in Campaign.TARGETS was
## measured against six dice, and a seventh that survived the turn would quietly
## re-measure the rest of the level.
func test_the_extra_die_goes_back_at_the_end_of_the_turn() -> void:
	var game := make_game()
	var owned := game.get_dice().size()
	game.play_card(give(game, CardLibrary.EXTRA_DIE))
	assert_eq(game.get_dice().size(), owned + 1, "seven for now")
	force_faces(game, [1, 1, 3, 4, 6, 2, 5])
	take_and_bank(game)
	assert_eq(game.get_dice().size(), owned, "and six again next turn")

## The row is what caps this: a die has a floor size, so past a point the tray
## stops shrinking them and starts asking the board for more width than the
## screen has.
func test_extra_die_is_refused_once_the_table_is_full() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.EXTRA_DIE)
	while game.get_pool().size() < ExtraDieCard.MAX_DICE:
		game.get_pool().add_die(StarterDice.create_basic_d6())
	assert_false(game.can_play_card(card), "no room left")
	assert_true(game.get_card_refusal(card).contains("room"), "and it says why")

# --- score boost -----------------------------------------------------------

func test_score_boost_pays_half_again_on_a_matched_set() -> void:
	var game := make_game()
	force_faces(game, [4, 4, 4, 2, 3, 6])
	game.select_all_scoring()
	var before := game.selection_score.total()
	assert_eq(before, FarkleScorer.triple_points(4), "three 4s, and nothing else scores")

	assert_true(game.play_card(give(game, CardLibrary.SCORE_BOOST)), "played")
	game.select_all_scoring()
	assert_eq(game.selection_score.total(), int(round(before * 1.5)), "half again")

## Singles are left alone. A card that paid on everything would be the element
## combo ladder wearing a different name.
func test_score_boost_leaves_single_dice_alone() -> void:
	var game := make_game()
	force_faces(game, [1, 5, 2, 3, 4, 6])
	game.select_all_scoring()
	var before := game.selection_score.total()
	game.play_card(give(game, CardLibrary.SCORE_BOOST))
	game.select_all_scoring()
	assert_eq(game.selection_score.total(), before, "a 1 and a 5 pay what they always did")

## "One roll" is one roll, not one turn: the card buys the board in front of
## you. Rolling again is what spends it, and nothing has to remember to.
func test_score_boost_is_spent_by_the_next_roll() -> void:
	var game := make_game()
	force_faces(game, [4, 4, 4, 2, 3, 6])
	game.play_card(give(game, CardLibrary.SCORE_BOOST))
	assert_eq(game.get_active_cards().size(), 1, "in force")

	game.select_all_scoring()
	game.commit_selection()
	assert_eq(game.get_active_cards().size(), 1, "a take does not spend it")
	assert_true(game.push(), "rolled again")
	assert_eq(game.get_active_cards().size(), 0, "and now it is gone")

# --- lock all --------------------------------------------------------------

func test_lock_all_takes_the_scoring_dice() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	assert_true(game.play_card(give(game, CardLibrary.LOCK_ALL)), "played")
	assert_eq(game.get_pool().set_aside_count(), 2, "both 1s are set aside")
	assert_eq(game.context.turn_score, 200, "and their points are riding on the turn")

func test_lock_all_is_refused_when_nothing_scores() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.LOCK_ALL)
	force_faces(game, [2, 3, 4, 6, 6, 2])
	assert_false(game.can_play_card(card), "nothing to lock")
	assert_true(game.get_card_refusal(card).contains("scores"), "and it says why")

## It goes through commit_selection(), so everything a normal take sets off
## still happens — hot dice most of all, which is where the big turns come from.
func test_lock_all_earns_hot_dice_like_any_other_take() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 1, 5, 5, 5])
	var hot := [false]
	game.hot_dice.connect(func() -> void: hot[0] = true)
	game.play_card(give(game, CardLibrary.LOCK_ALL))
	assert_true(hot[0], "the table cleared")
	assert_eq(game.get_dice_in_play().size(), 6, "and came back")

# --- farkle shield ---------------------------------------------------------

func test_farkle_shield_banks_the_turn_instead_of_losing_it() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	game.select_all_scoring()
	game.commit_selection()
	var riding := game.context.turn_score
	assert_true(riding > 0, "there is something to protect")

	game.play_card(give(game, CardLibrary.FARKLE_SHIELD))
	force_faces(game, [2, 3, 4, 6, 6, 2])
	game._farkle()

	assert_eq(game.context.banked_score, riding, "the points were saved")
	assert_eq(game.context.turn_score, 0, "and are no longer riding")

## The level's own penalty goes with them. A shielded bust that still charged
## 100 off the banked score would be a shield that costs points.
func test_farkle_shield_cancels_the_levels_penalty() -> void:
	var game := make_game()
	game.context.banked_score = 500
	game.play_card(give(game, CardLibrary.FARKLE_SHIELD))
	force_faces(game, [2, 3, 4, 6, 6, 2])
	game._farkle()
	assert_eq(game.context.banked_score, 500, "nothing was taken off the bank")

func test_without_a_shield_a_farkle_still_takes_everything() -> void:
	var game := make_game()
	game.context.banked_score = 500
	force_faces(game, [1, 1, 3, 4, 6, 2])
	game.select_all_scoring()
	game.commit_selection()
	game._farkle()
	assert_eq(game.context.turn_score, 0, "the turn is gone")
	assert_eq(game.context.banked_score, 400, "and the level charged for it")

## The shield saves the points, not the roll. Handing the board back would let
## the player push again off dice they had already committed, which is a free
## retry.
func test_farkle_shield_does_not_hand_the_roll_back() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	game.select_all_scoring()
	game.commit_selection()
	game.play_card(give(game, CardLibrary.FARKLE_SHIELD))
	game._farkle()
	assert_eq(game.state, FarkleGame.State.FARKLED, "the turn is still over")

func test_a_spent_shield_stops_claiming_to_be_in_force() -> void:
	var game := make_game()
	game.play_card(give(game, CardLibrary.FARKLE_SHIELD))
	assert_eq(game.get_active_cards().size(), 1, "in force")
	force_faces(game, [2, 3, 4, 6, 6, 2])
	game._farkle()
	assert_eq(game.get_active_cards().size(), 0, "and spent by the bust it stopped")

# --- forced reroll ---------------------------------------------------------

func test_forced_reroll_buys_a_push_with_nothing_set_aside() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	assert_false(game.can_push(), "nothing is committed, so nothing may be risked")
	assert_true(game.play_card(give(game, CardLibrary.FORCED_REROLL)), "played")
	assert_true(game.can_push(), "and now the roll is bought")

func test_forced_reroll_takes_the_bank_away_until_it_is_paid() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	game.select_all_scoring()
	game.commit_selection()
	assert_true(game.can_bank(), "the turn could be ended")

	game.play_card(give(game, CardLibrary.FORCED_REROLL))
	assert_false(game.can_bank(), "not until the dice have moved")
	assert_true(game.get_bank_requirement_text().contains("Roll"), "and the button says so")

	assert_true(game.push(), "so roll")
	if game.state == FarkleGame.State.CHOOSING:
		assert_true(game.can_bank(), "and the bank comes back")

## can_push() refuses to roll over marked dice, so a card that granted the push
## and left the marks in place would have granted nothing the player could act
## on.
func test_forced_reroll_clears_what_the_player_had_marked() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	game.select_all_scoring()
	assert_false(game.get_selection().is_empty(), "something is marked")
	game.play_card(give(game, CardLibrary.FORCED_REROLL))
	assert_true(game.get_selection().is_empty(), "and now nothing is")
	assert_true(game.can_push(), "so the roll it demanded can happen")

# --- targeting -------------------------------------------------------------

func test_a_targeted_card_waits_and_costs_nothing_yet() -> void:
	var game := make_game()
	force_faces(game, [2, 3, 4, 6, 6, 2])
	var spent := game.context.energy_spent
	assert_true(game.play_card(give(game, CardLibrary.VALUE_CONVERTER)), "the tap was taken")
	assert_true(game.is_targeting(), "and the board is waiting for a die")
	assert_eq(game.context.energy_spent, spent, "nothing has been paid for yet")
	assert_true(game.hand.holds(CardLibrary.VALUE_CONVERTER), "and the card is still in hand")

func test_cancelling_leaves_the_turn_exactly_as_it_was() -> void:
	var game := make_game()
	force_faces(game, [2, 3, 4, 6, 6, 2])
	var card := give(game, CardLibrary.VALUE_CONVERTER)
	var spent := game.context.energy_spent
	var held := game.hand.size()
	game.play_card(card)
	assert_true(game.cancel_targeting(), "backed out")
	assert_false(game.is_targeting(), "nothing is waiting")
	assert_eq(game.context.energy_spent, spent, "nothing was spent")
	assert_eq(game.hand.size(), held, "and nothing was discarded")

## While a card is waiting, a tap on a die means "this one" and the three
## buttons mean nothing. A board that took an instruction here would be acting
## on a question it had already asked.
func test_the_board_takes_no_other_instruction_while_a_card_waits() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	game.select_all_scoring()
	game.commit_selection()
	game.play_card(give(game, CardLibrary.VALUE_CONVERTER))

	assert_true(game.is_targeting(), "waiting")
	assert_false(game.can_bank(), "the bank is off")
	assert_false(game.can_push(), "the push is off")
	assert_false(game.can_commit_selection(), "and so is the take")
	assert_false(game.toggle_selection(game.get_dice_in_play()[0]), "marking does nothing")
	assert_false(
		game.can_play_card(give(game, CardLibrary.LOCK_ALL)), "and no second card may go"
	)

func test_a_card_waiting_for_a_die_says_so_when_another_is_held_down() -> void:
	var game := make_game()
	force_faces(game, [2, 3, 4, 6, 6, 2])
	game.play_card(give(game, CardLibrary.VALUE_CONVERTER))
	var other := give(game, CardLibrary.LOCK_ALL)
	assert_true(game.get_card_refusal(other).contains("waiting"), "the reason is the wait")

# --- value converter -------------------------------------------------------

func test_value_converter_turns_a_dead_die_into_a_scoring_one() -> void:
	var game := make_game()
	force_faces(game, [2, 3, 4, 6, 6, 2])
	var card := give(game, CardLibrary.VALUE_CONVERTER)
	# Counted rather than asked whether it is held: the fixture's hand is dealt
	# from a real deck and may already have held a copy of this card.
	var copies := game.hand.hand.count(card.id)
	game.play_card(card)
	var die := game.get_targets_for(card)[0]
	assert_true(game.apply_target(die), "given a die")

	assert_true(die.get_value() in ValueConverterCard.VALUES, "it is a 1 or a 5 now")
	assert_true(die in game.get_scorable_dice(), "and it scores")
	assert_eq(game.context.energy_spent, card.energy_cost, "paid for on the way")
	assert_eq(game.hand.hand.count(card.id), copies - 1, "and one copy left the hand")

## Converting a die that already scores is paying four energy to move a 1 to a
## 5. Offering it would invite exactly that.
func test_value_converter_only_offers_the_dice_that_score_nothing() -> void:
	var game := make_game()
	force_faces(game, [1, 5, 2, 3, 4, 6])
	var card := give(game, CardLibrary.VALUE_CONVERTER)
	game.play_card(card)
	for die in game.get_dice_in_play():
		assert_eq(
			game.can_target(die),
			not die in game.get_scorable_dice(),
			"a %d is offered: %s" % [die.get_value(), not die in game.get_scorable_dice()]
		)

func test_value_converter_is_refused_when_every_die_already_scores() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 1, 5, 5, 5])
	var card := give(game, CardLibrary.VALUE_CONVERTER)
	assert_false(game.can_play_card(card), "nothing dead to revive")
	assert_true(game.get_card_refusal(card).contains("already scores"), "and it says why")

# --- value shift -----------------------------------------------------------

func test_value_shift_moves_a_die_one_pip() -> void:
	var game := make_game()
	force_faces(game, [2, 3, 4, 6, 6, 2])
	var card := give(game, CardLibrary.VALUE_SHIFT)
	game.play_card(card)
	assert_eq(game.get_target_choice(), 0, "+1 is armed first")

	var die := game.get_dice_in_play()[0]
	assert_true(game.apply_target(die), "given a die")
	assert_eq(die.get_value(), 3, "the 2 went up")

func test_value_shift_can_be_armed_the_other_way() -> void:
	var game := make_game()
	force_faces(game, [2, 3, 4, 6, 6, 2])
	game.play_card(give(game, CardLibrary.VALUE_SHIFT))
	assert_true(game.set_target_choice(1), "armed -1")

	var die := game.get_dice_in_play()[0]
	game.apply_target(die)
	assert_eq(die.get_value(), 1, "the 2 came down, and it scores now")

## A d6 has no seventh face, so with +1 armed a 6 is not a die this can take.
## The player is told by the tray going dark on it rather than by a rule they
## have to remember.
func test_a_die_with_nowhere_to_go_is_not_offered() -> void:
	var game := make_game()
	force_faces(game, [2, 3, 4, 6, 6, 2])
	game.play_card(give(game, CardLibrary.VALUE_SHIFT))
	for die in game.get_dice_in_play():
		assert_eq(game.can_target(die), die.get_value() < 6, "a %d moves up" % die.get_value())
	game.set_target_choice(1)
	for die in game.get_dice_in_play():
		assert_eq(game.can_target(die), die.get_value() > 1, "a %d moves down" % die.get_value())

## The card opens on whichever direction has somewhere to go. With +1 armed on a
## board of six 6s the tray would open dark, and the player would have to work
## out that the card was fine and the button was the problem.
func test_value_shift_opens_on_a_direction_that_works() -> void:
	var game := make_game()
	force_faces(game, [6, 6, 6, 6, 6, 6])
	var card := give(game, CardLibrary.VALUE_SHIFT)
	assert_true(game.can_play_card(card), "six 6s are a board this plays on")
	game.play_card(card)
	assert_eq(game.get_target_choice(), 1, "-1 armed, because +1 has nothing to move")
	assert_false(game.get_targets_for(card).is_empty(), "and the tray has dice in it")

# --- lifetime --------------------------------------------------------------

func test_a_lasting_card_wears_off_at_the_end_of_the_turn() -> void:
	var game := make_game()
	game.play_card(give(game, CardLibrary.FARKLE_SHIELD))
	assert_eq(game.get_active_cards().size(), 1, "in force")
	force_faces(game, [1, 1, 3, 4, 6, 2])
	take_and_bank(game)
	assert_eq(game.get_active_cards().size(), 0, "and gone by the next turn")

## An instant card is never in force at all. One that lingered would be a card
## the HUD went on claiming had done something.
func test_an_instant_card_leaves_nothing_behind() -> void:
	var game := make_game()
	game.play_card(give(game, CardLibrary.EXTRA_DIE))
	assert_eq(game.get_active_cards().size(), 0, "nothing to wear off")

func test_the_budget_comes_back_each_turn() -> void:
	var game := make_game()
	game.play_card(give(game, CardLibrary.FARKLE_SHIELD))
	assert_true(game.context.energy_spent > 0, "spent")
	force_faces(game, [1, 1, 3, 4, 6, 2])
	take_and_bank(game)
	assert_eq(game.context.energy_spent, 0, "a new turn, a new budget")

## The signal has to name the dice a card turned over: the tray redraws a face
## only when it rolls one, so a die missing from here keeps showing the old face
## while the scorer reads the new one.
func test_playing_a_card_reports_the_dice_it_changed() -> void:
	var game := make_game()
	force_faces(game, [2, 3, 4, 6, 6, 2])

	# Filled rather than reassigned: a GDScript lambda captures a local by value,
	# so `reported = changed` would only ever move the closure's own copy and the
	# assertions below would pass against an empty array forever.
	var reported : Array[Die] = []
	game.card_played.connect(func(_card : Card, changed : Array[Die]) -> void:
		reported.assign(changed))

	game.play_card(give(game, CardLibrary.FARKLE_SHIELD))
	assert_eq(reported.size(), 0, "a shield touches no dice, so it names none")

	var shift := give(game, CardLibrary.VALUE_SHIFT)
	game.play_card(shift)
	var die := game.get_dice_in_play()[0]
	game.apply_target(die)
	assert_eq(reported.size(), 1, "one die moved")
	assert_true(die in reported, "and it is the one that was tapped")
