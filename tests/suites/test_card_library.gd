extends TestCase
## What cards exist, what they cost, and that a deck is reproducible.
##
## No game and no board here — these are questions about the catalogue. What a
## card *does* to a turn is tested in test_card.gd against a real FarkleGame.

func before_each() -> void:
	pass

# --- the catalogue ---------------------------------------------------------

func test_every_listed_card_can_be_looked_up() -> void:
	for id in CardLibrary.ORDER:
		assert_not_null(CardLibrary.by_id(id), "%s exists" % id)

func test_an_unknown_id_is_null_rather_than_a_crash() -> void:
	assert_null(CardLibrary.by_id(&"no_such_card"), "a renamed card is gone, not fatal")

func test_the_base_set_is_seven_cards() -> void:
	assert_eq(CardLibrary.all().size(), 7, "the seven base cards and nothing else")

func test_every_card_names_and_explains_itself() -> void:
	for card in CardLibrary.all():
		assert_false(card.display_name.is_empty(), "%s has a name" % card.id)
		assert_false(card.description.is_empty(), "%s says what it does" % card.id)
		assert_false(card.icon.is_empty(), "%s has a glyph to be found by" % card.id)
		assert_true(card.energy_cost > 0, "%s costs something" % card.id)

## The costs the base set was specified with. Pinned so a balance pass has to be
## a decision rather than a drift.
func test_the_costs_are_the_ones_that_were_specified() -> void:
	var expected := {
		CardLibrary.EXTRA_DIE: 3,
		CardLibrary.SCORE_BOOST: 4,
		CardLibrary.VALUE_SHIFT: 5,
		CardLibrary.LOCK_ALL: 2,
		CardLibrary.VALUE_CONVERTER: 4,
		CardLibrary.FARKLE_SHIELD: 6,
		CardLibrary.FORCED_REROLL: 5,
	}
	for id in expected:
		assert_eq(CardLibrary.by_id(id).energy_cost, int(expected[id]), String(id))

## A turn here is many rolls, so a card's lifetime cannot be left to a comment:
## Score Boost buys the board in front of you and Farkle Shield buys the roll you
## have not made yet, and FarkleGame clears the two at different moments.
func test_only_the_lasting_cards_last() -> void:
	var expected := {
		CardLibrary.EXTRA_DIE: Card.Duration.INSTANT,
		CardLibrary.LOCK_ALL: Card.Duration.INSTANT,
		CardLibrary.VALUE_SHIFT: Card.Duration.INSTANT,
		CardLibrary.VALUE_CONVERTER: Card.Duration.INSTANT,
		CardLibrary.SCORE_BOOST: Card.Duration.ROLL,
		CardLibrary.FORCED_REROLL: Card.Duration.ROLL,
		CardLibrary.FARKLE_SHIELD: Card.Duration.TURN,
	}
	for id in expected:
		assert_eq(CardLibrary.by_id(id).duration, expected[id], String(id))

## The two that ask for a die, and the five that do not. A card that quietly
## grew a targeting step would stop the board on a question nothing answers.
func test_only_the_value_cards_ask_for_a_die() -> void:
	for card in CardLibrary.all():
		var asks := card.id in [CardLibrary.VALUE_SHIFT, CardLibrary.VALUE_CONVERTER]
		assert_eq(card.needs_target(), asks, "%s asks for a die: %s" % [card.id, asks])
		if asks:
			assert_false(card.target_prompt().is_empty(), "%s says what to tap" % card.id)

## Cards are shared instances, so one carrying per-play state would leak it into
## every other hand holding the same card.
func test_a_card_is_the_same_object_everywhere() -> void:
	assert_true(
		CardLibrary.by_id(CardLibrary.LOCK_ALL) == CardLibrary.by_id(CardLibrary.LOCK_ALL),
		"looked up twice, the same card"
	)

# --- decks -----------------------------------------------------------------

func test_a_deck_holds_every_card_several_times_over() -> void:
	var deck := CardLibrary.build_deck(RngService.new(7))
	assert_eq(deck.size(), 7 * CardLibrary.COPIES_PER_CARD, "three of each")
	for id in CardLibrary.ORDER:
		assert_eq(deck.count(id), CardLibrary.COPIES_PER_CARD, "%s is in it" % id)

## A fixed seed has to reproduce a whole run, and the cards are part of the run.
func test_the_same_seed_deals_the_same_deck() -> void:
	var first := CardLibrary.build_deck(RngService.new(11))
	var second := CardLibrary.build_deck(RngService.new(11))
	assert_eq(first, second, "same seed, same deck")

func test_different_seeds_deal_different_decks() -> void:
	var first := CardLibrary.build_deck(RngService.new(11))
	var second := CardLibrary.build_deck(RngService.new(12))
	assert_ne(first, second, "and a different one otherwise")

# --- the hand --------------------------------------------------------------

func test_a_new_hand_draws_the_opening_five() -> void:
	var hand := CardHand.create(RngService.new(3))
	assert_eq(hand.size(), 5, "section 3.7's opening draw")

func test_a_hand_will_not_go_over_its_cap() -> void:
	var hand := CardHand.create(RngService.new(3))
	hand.draw(10)
	assert_eq(hand.size(), CardHand.MAX_HAND, "capped")

func test_drawing_returns_what_was_actually_drawn() -> void:
	var hand := CardHand.new(RngService.new(3))
	hand.deck = CardLibrary.build_deck(RngService.new(3))
	assert_eq(hand.draw(2).size(), 2, "two")
	assert_eq(hand.draw(99).size(), 3, "and only three more fit")

## A run that quietly stopped paying cards would look like a bug to the only
## person who could report it.
func test_an_empty_deck_reshuffles_rather_than_running_dry() -> void:
	var hand := CardHand.new(RngService.new(3))
	hand.deck = []
	assert_eq(hand.draw(1).size(), 1, "the deck came back")

func test_discarding_removes_one_copy() -> void:
	var hand := CardHand.new(RngService.new(3))
	hand.hand = [CardLibrary.LOCK_ALL, CardLibrary.LOCK_ALL] as Array[StringName]
	assert_true(hand.discard(CardLibrary.LOCK_ALL), "found")
	assert_eq(hand.size(), 1, "one copy left")
	assert_true(hand.holds(CardLibrary.LOCK_ALL), "and it is still held")

func test_discarding_what_is_not_held_fails() -> void:
	var hand := CardHand.new(RngService.new(3))
	assert_false(hand.discard(CardLibrary.LOCK_ALL), "nothing to discard")

## Restoring must not reshuffle. Quitting between levels and coming back would
## otherwise reroll the run's future, which is the one thing a player would
## notice and call cheating.
func test_a_restored_hand_keeps_the_deck_it_was_saved_with() -> void:
	var original := CardHand.create(RngService.new(3))
	var restored := CardHand.restore(original.hand, original.deck, RngService.new(99))
	assert_eq(restored.hand, original.hand, "same hand")
	assert_eq(restored.deck, original.deck, "and the same deck order")

func test_get_cards_skips_an_id_that_no_longer_exists() -> void:
	var hand := CardHand.new(RngService.new(3))
	hand.hand = [CardLibrary.LOCK_ALL, &"deleted_card"] as Array[StringName]
	assert_eq(hand.get_cards().size(), 1, "the missing one is dropped, not fatal")
