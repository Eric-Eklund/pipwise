extends TestCase
## What a card does to a turn, driven through a real FarkleGame.
##
## The catalogue itself is tested in test_card_library.gd. These are the ones
## that need a board: energy actually leaving the budget, a potion reaching the
## scorer, a Shield surviving a bust.

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
func make_game(bag : BagDefinition = null) -> FarkleGame:
	var game := FarkleGame.new(make_ruleset(bag), RngService.new(1))
	game.hand = CardHand.create(RngService.new(4))
	game.start()
	return game

func force_faces(game : FarkleGame, values : Array) -> void:
	var in_play := game.get_dice_in_play()
	for i in mini(values.size(), in_play.size()):
		in_play[i].current_face = DieFace.create(StringName("pip_%d" % int(values[i])), int(values[i]))
	game.rules = ElementRules.new(game.get_dice_in_play(), game.get_active_cards())

## Puts [param id] in hand and returns the card, so a test does not depend on
## what the deck happened to deal.
func give(game : FarkleGame, id : StringName) -> Card:
	game.hand.hand.append(id)
	return CardLibrary.by_id(id)

# --- paying for a card -----------------------------------------------------

func test_playing_a_card_costs_its_energy() -> void:
	var game := make_game()
	var before := game.context.available_energy()
	var card := give(game, CardLibrary.SHIELD)
	assert_true(game.play_card(card), "played")
	assert_eq(game.context.available_energy(), before - card.energy_cost, "and paid for")

func test_a_card_leaves_the_hand_when_played() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.SHIELD)
	var before := game.hand.size()
	game.play_card(card)
	assert_eq(game.hand.size(), before - 1, "one fewer in hand")

func test_a_card_that_is_not_held_cannot_be_played() -> void:
	var game := make_game()
	while game.hand.discard(CardLibrary.SHIELD):
		pass
	assert_false(game.can_play_card(CardLibrary.by_id(CardLibrary.SHIELD)), "not in hand")

func test_a_card_you_cannot_afford_is_refused_and_costs_nothing() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.CRYSTAL_FOCUS)
	game.context.energy_spent = game.context.total_energy()
	assert_false(game.can_play_card(card), "no energy left")
	assert_false(game.play_card(card), "so it is refused")
	assert_true(game.hand.holds(card.id), "and still in hand")

## A card played on a dead board would be paying to change a roll that has
## already failed. Shield in particular has to be bought before the roll it
## protects, or pushing costs nothing.
func test_no_card_can_be_played_after_a_farkle() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.SHIELD)
	force_faces(game, [2, 3, 4, 6, 6, 2])
	game._farkle()
	assert_eq(game.state, FarkleGame.State.FARKLED, "busted")
	assert_false(game.can_play_card(card), "and the card is too late")

# --- scrolls ---------------------------------------------------------------

func test_extra_die_brings_a_die_back() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	game.select_all_scoring()
	game.commit_selection()
	var in_play := game.get_dice_in_play().size()
	var card := give(game, CardLibrary.EXTRA_DIE)
	assert_true(game.play_card(card), "played")
	assert_eq(game.get_dice_in_play().size(), in_play + 1, "one more on the table")

func test_extra_die_is_refused_when_nothing_has_been_set_aside() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.EXTRA_DIE)
	assert_false(game.can_play_card(card), "every die is already in play")

## The die comes back rolled, not on the face it was set aside on. Restoring
## alone handed it back already scoring — it was set aside *because* it scored —
## so the card was worth a second helping of one die's points rather than a
## gamble on a fresh face.
##
## Asserted against the type's own faces rather than against a value: force_faces
## mints a face that no DieType holds, and only a real roll can replace it with
## one that does. A value would be a coin flip on the seed.
func test_extra_die_rolls_the_die_it_brings_back() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	game.select_all_scoring()
	game.commit_selection()

	var restored_before := game.get_pool().get_set_aside()
	assert_true(game.play_card(give(game, CardLibrary.EXTRA_DIE)), "played")

	var came_back : Die = null
	for die in game.get_dice_in_play():
		if die in restored_before:
			came_back = die
	assert_true(came_back != null, "a die came back")
	assert_true(
		came_back.current_face in came_back.type.faces,
		"and it was rolled rather than handed back on its old face"
	)

## Restoring the last set aside die would leave nothing to push against, and the
## reroll can leave nothing to take — which on level 5, behind the bank gate, is
## a board with all three buttons dead.
func test_extra_die_will_not_restore_the_last_die_set_aside() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.EXTRA_DIE)
	force_faces(game, [1, 3, 4, 6, 2, 2])
	game.select_all_scoring()
	game.commit_selection()
	assert_eq(game.get_pool().set_aside_count(), 1, "exactly one commitment")
	assert_true(game.hand.holds(card.id), "the card is held")
	assert_false(game.can_play_card(card), "so there is nothing it may take back")

func test_extra_die_leaves_the_push_legal() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	game.select_all_scoring()
	game.commit_selection()
	game.play_card(give(game, CardLibrary.EXTRA_DIE))
	assert_true(game.can_push(), "there is still a commitment to roll against")

## The signal has to name the dice a card turned over: the tray redraws a face
## only when it rolls one, so a die missing from here keeps showing the old face
## while the scorer reads the new one.
func test_playing_a_card_reports_the_dice_it_rolled() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	game.select_all_scoring()
	game.commit_selection()

	var reported : Array = []
	game.card_played.connect(func(_card : Card, rerolled : Array[Die]) -> void:
		reported = rerolled)

	game.play_card(give(game, CardLibrary.SHIELD))
	assert_eq(reported.size(), 0, "Shield touches no dice, so it names none")

	# Not a count: a reroll may land on the face it left, and a die that did not
	# change is a die the tray has nothing to redraw. What must hold is that
	# nothing is named that the card did not put back on the table.
	game.play_card(give(game, CardLibrary.EXTRA_DIE))
	for die in reported:
		assert_true(die in game.get_dice_in_play(), "only dice it brought back")

func test_draw_two_is_a_net_gain_even_on_a_full_hand() -> void:
	var game := make_game()
	game.hand.hand = [CardLibrary.DRAW_TWO] as Array[StringName]
	while not game.hand.is_full():
		game.hand.hand.append(CardLibrary.SHIELD)
	game.play_card(CardLibrary.by_id(CardLibrary.DRAW_TWO))
	assert_eq(game.hand.size(), CardHand.MAX_HAND, "back to the cap, one card better off")

func test_discard_swap_replaces_the_rest_of_the_hand() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.DISCARD_SWAP)
	var before := game.hand.size()
	assert_true(game.play_card(card), "played")
	assert_eq(game.hand.size(), before - 1, "the swap is one smaller than the hand it left")

func test_discard_swap_needs_something_to_swap() -> void:
	var game := make_game()
	game.hand.hand = [CardLibrary.DISCARD_SWAP] as Array[StringName]
	assert_false(
		game.can_play_card(CardLibrary.by_id(CardLibrary.DISCARD_SWAP)),
		"nothing behind it to throw away"
	)

# --- shield ----------------------------------------------------------------

func test_shield_banks_the_turn_instead_of_losing_it() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	game.select_all_scoring()
	game.commit_selection()
	var riding := game.context.turn_score
	assert_true(riding > 0, "there is something to protect")

	game.play_card(give(game, CardLibrary.SHIELD))
	force_faces(game, [2, 3, 4, 6, 6, 2])
	game._farkle()

	assert_eq(game.context.banked_score, riding, "the points were saved")
	assert_eq(game.context.turn_score, 0, "and are no longer riding")

func test_without_shield_a_farkle_still_takes_everything() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	game.select_all_scoring()
	game.commit_selection()
	game._farkle()
	assert_eq(game.context.banked_score, 0, "nothing saved")
	assert_eq(game.context.turn_score, 0, "and the turn is gone")

## Shield saves the points, not the roll. Handing the board back would let the
## player push again off dice they had already committed, which is a free retry.
func test_shield_does_not_hand_the_roll_back() -> void:
	var game := make_game()
	force_faces(game, [1, 1, 3, 4, 6, 2])
	game.select_all_scoring()
	game.commit_selection()
	game.play_card(give(game, CardLibrary.SHIELD))
	game._farkle()
	assert_eq(game.state, FarkleGame.State.FARKLED, "the turn is still over")

# --- potions ---------------------------------------------------------------

func fire_game() -> FarkleGame:
	return make_game(StarterDice.create_element_bag(Element.FIRE, 3))

func test_fire_brew_doubles_what_fire_pays() -> void:
	var game := fire_game()
	force_faces(game, [6, 6, 6, 2, 3, 4])
	game.select_all_scoring()
	var before := game.selection_score.element_bonus

	game.play_card(give(game, CardLibrary.FIRE_BREW))
	game.select_all_scoring()
	assert_almost_eq(game.selection_score.element_bonus, before * 2.0, 0.01, "doubled")

func test_a_potion_only_touches_its_own_element() -> void:
	var game := fire_game()
	force_faces(game, [6, 6, 6, 2, 3, 4])
	game.select_all_scoring()
	var before := game.selection_score.element_bonus

	game.play_card(give(game, CardLibrary.FROST_SHIELD))
	game.select_all_scoring()
	assert_almost_eq(game.selection_score.element_bonus, before, 0.01, "Ice does nothing here")

## The cache is keyed on the rules object, so a card that did not rebuild it
## would leave the Take button offering the pre-card answer until the next roll.
func test_playing_a_potion_updates_what_take_offers() -> void:
	var game := fire_game()
	force_faces(game, [6, 6, 6, 2, 3, 4])
	game.select_all_scoring()
	var before := game.selection_score.total()
	game.play_card(give(game, CardLibrary.FIRE_BREW))
	game.select_all_scoring()
	assert_true(game.selection_score.total() > before, "the board is worth more now")

## The campaign deals no elements at all before level 3, so for two levels every
## potion in the hand was bright, buyable and worth nothing. A potion multiplies
## its own element's share of the score, and on a board without that element
## there is no share to multiply.
func test_a_potion_is_refused_on_a_board_without_its_element() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.FIRE_BREW)
	assert_eq(game.rules.count_of(Element.FIRE), 0, "a plain bag")
	assert_false(game.can_play_card(card), "so the potion has nothing to double")
	assert_false(game.play_card(card), "and is refused")
	assert_true(game.hand.holds(card.id), "keeping the card for the level that suits it")

func test_a_potion_is_offered_when_its_element_is_on_the_table() -> void:
	var game := fire_game()
	var card := give(game, CardLibrary.FIRE_BREW)
	assert_true(game.can_play_card(card), "there is Fire to double")

## Earth Restore adds to what Nature hands back, and ElementRules.dice_restored()
## returns zero outright without a Nature die, so it adds to nothing.
func test_earth_restore_is_refused_without_nature() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.EARTH_RESTORE)
	assert_false(game.can_play_card(card), "nothing to hand back a die")

## Shadow Veil carries an element for its name and its colour and for nothing
## else: it grants the trio's effect outright rather than multiplying a die's
## share, so it works on a board with no Shadow die anywhere. Guarding it the way
## the other potions are guarded would take a working card off the player.
func test_shadow_veil_works_without_shadow_dice() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.SHADOW_VEIL)
	assert_eq(game.rules.count_of(Element.SHADOW), 0, "no Shadow anywhere")
	assert_true(game.can_play_card(card), "and it is still worth playing")
	assert_true(game.play_card(card), "played")
	assert_true(game.rules.farkle_penalty(100) < 0, "a Farkle now pays")

# --- why a card will not go -------------------------------------------------

## What the detail window shows when a card is held down. The row can only grey
## a card out; this is the only thing that says why.
func test_a_refused_card_says_why() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.FIRE_BREW)
	assert_true(
		game.get_card_refusal(card).contains("Fire"),
		"the reason names the element that is missing"
	)

func test_a_card_you_cannot_afford_says_so() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.CRYSTAL_FOCUS)
	game.context.energy_spent = game.context.total_energy()
	assert_true(game.get_card_refusal(card).contains("⚡"), "the reason is the price")

func test_a_playable_card_has_nothing_to_explain() -> void:
	var game := make_game()
	var card := give(game, CardLibrary.SHIELD)
	assert_eq(game.get_card_refusal(card), "", "nothing is in its way")

func test_earth_restore_hands_back_an_extra_die() -> void:
	var game := make_game(StarterDice.create_element_bag(Element.NATURE, 2))
	force_faces(game, [1, 5, 2, 3, 4, 4])
	game.select_all_scoring()
	var before := game.selection_score.dice_restored

	game.play_card(give(game, CardLibrary.EARTH_RESTORE))
	game.select_all_scoring()
	assert_eq(game.selection_score.dice_restored, before + 1, "one more comes back")

func test_shadow_veil_makes_a_farkle_pay() -> void:
	var game := make_game()
	game.play_card(give(game, CardLibrary.SHADOW_VEIL))
	assert_true(game.rules.farkle_penalty(100) < 0, "the bust pays instead of costing")

func test_without_shadow_veil_a_farkle_still_costs() -> void:
	var game := make_game()
	assert_eq(game.rules.farkle_penalty(100), 100, "the full penalty")

# --- lifetime --------------------------------------------------------------

## Section 3 calls a card's duration "one round", and a round here is a turn.
func test_a_card_wears_off_at_the_end_of_the_turn() -> void:
	var game := fire_game()
	game.play_card(give(game, CardLibrary.FIRE_BREW))
	assert_eq(game.get_active_cards().size(), 1, "in force")
	force_faces(game, [1, 1, 3, 4, 6, 2])
	game.select_all_scoring()
	game.commit_selection()
	game.bank()
	assert_eq(game.get_active_cards().size(), 0, "and gone by the next turn")

func test_the_budget_comes_back_each_turn() -> void:
	var game := make_game()
	game.play_card(give(game, CardLibrary.SHIELD))
	assert_true(game.context.energy_spent > 0, "spent")
	force_faces(game, [1, 1, 3, 4, 6, 2])
	game.select_all_scoring()
	game.commit_selection()
	game.bank()
	assert_eq(game.context.energy_spent, 0, "a new turn, a new budget")

## Endless mode is not part of a run, so it has no hand. Every card path has to
## survive that rather than assuming a run exists.
func test_a_game_without_a_hand_offers_no_cards() -> void:
	var game := FarkleGame.new(make_ruleset(), RngService.new(1))
	game.start()
	assert_eq(game.get_hand().size(), 0, "nothing to play")
	assert_false(game.can_play_card(CardLibrary.by_id(CardLibrary.SHIELD)), "and no way to play it")
