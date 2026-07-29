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

func test_the_slice_is_scrolls_and_potions() -> void:
	assert_eq(CardLibrary.by_rarity(Card.Rarity.COMMON).size(), 4, "four scrolls")
	assert_eq(CardLibrary.by_rarity(Card.Rarity.UNCOMMON).size(), 6, "six potions")
	for rarity in [Card.Rarity.RARE, Card.Rarity.EPIC, Card.Rarity.LEGENDARY]:
		assert_eq(CardLibrary.by_rarity(rarity).size(), 0, "nothing above uncommon yet")

func test_every_card_names_and_explains_itself() -> void:
	for card in CardLibrary.all():
		assert_false(card.display_name.is_empty(), "%s has a name" % card.id)
		assert_false(card.description.is_empty(), "%s says what it does" % card.id)
		assert_true(card.energy_cost > 0, "%s costs something" % card.id)

## Section 3.3 gives one potion per element, and all six elements are dealt by
## the campaign now — so a potion for an element the player can never own would
## be a dead draw.
func test_there_is_one_potion_for_every_element() -> void:
	var covered : Dictionary = {}
	for card in CardLibrary.by_rarity(Card.Rarity.UNCOMMON):
		covered[card.element] = true
	for element in Element.ALL:
		assert_true(covered.has(element), "%s has a potion" % element)

func test_the_scrolls_carry_no_element() -> void:
	for card in CardLibrary.by_rarity(Card.Rarity.COMMON):
		assert_eq(card.element, Element.NONE, "%s is elementless" % card.id)

## The document's own energy costs, kept for every card that survived into this
## build. Pinned so a balance pass has to be a decision rather than a drift.
func test_the_costs_are_the_design_documents() -> void:
	var expected := {
		CardLibrary.EXTRA_DIE: 3, CardLibrary.SHIELD: 5,
		CardLibrary.DRAW_TWO: 3, CardLibrary.DISCARD_SWAP: 4,
		CardLibrary.FIRE_BREW: 5, CardLibrary.FROST_SHIELD: 6,
		CardLibrary.STORM_CALL: 7, CardLibrary.EARTH_RESTORE: 5,
		CardLibrary.SHADOW_VEIL: 6, CardLibrary.CRYSTAL_FOCUS: 8,
	}
	for id in expected:
		assert_eq(CardLibrary.by_id(id).energy_cost, int(expected[id]), String(id))

## Cards are shared instances, so one carrying per-play state would leak it into
## every other hand holding the same card.
func test_a_card_is_the_same_object_everywhere() -> void:
	assert_true(
		CardLibrary.by_id(CardLibrary.SHIELD) == CardLibrary.by_id(CardLibrary.SHIELD),
		"looked up twice, the same card"
	)

# --- decks -----------------------------------------------------------------

func test_a_deck_holds_every_card_weighted_by_rarity() -> void:
	var deck := CardLibrary.build_deck(RngService.new(7))
	assert_eq(deck.size(), 4 * 3 + 6 * 1, "three of each scroll, one of each potion")

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
	hand.hand = [CardLibrary.SHIELD, CardLibrary.SHIELD] as Array[StringName]
	assert_true(hand.discard(CardLibrary.SHIELD), "found")
	assert_eq(hand.size(), 1, "one copy left")
	assert_true(hand.holds(CardLibrary.SHIELD), "and it is still held")

func test_discarding_what_is_not_held_fails() -> void:
	var hand := CardHand.new(RngService.new(3))
	assert_false(hand.discard(CardLibrary.SHIELD), "nothing to discard")

func test_a_swap_draws_back_what_it_threw_away() -> void:
	var hand := CardHand.create(RngService.new(3))
	hand.swap_all()
	assert_eq(hand.size(), 5, "the same number, a different five")

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
	hand.hand = [CardLibrary.SHIELD, &"deleted_card"] as Array[StringName]
	assert_eq(hand.get_cards().size(), 1, "the missing one is dropped, not fatal")
