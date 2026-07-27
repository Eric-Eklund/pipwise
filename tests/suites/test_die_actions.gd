extends TestCase
## Dice are currency, so each face's action is the thing being bought. These
## tests cover them in isolation, against a context built by hand.

var _context : GameContext

func before_each() -> void:
	var rng := RngService.new(555)
	var deck := Deck.new(DeckDefinition.create_standard_52(), rng)
	var hand := Hand.new(5)
	_context = GameContext.new(deck, hand, rng)
	_context.refill_hand()

# --- redraw -------------------------------------------------------------

func test_redraw_replaces_every_unlocked_card() -> void:
	var before : Array[StringName] = []
	for card in _context.hand.cards:
		before.append(card.get_id())
	RedrawCardsAction.new().apply(_context)
	assert_eq(_context.hand.size(), 5, "the hand is dealt back up to full")
	for card in _context.hand.cards:
		if card.get_id() in before:
			# Possible only if the deck recycled, which it cannot at 47 left.
			fail("a card survived a redraw it was not locked against")
			return
	assert_true(true, "every card was replaced")

func test_redraw_keeps_locked_cards() -> void:
	var kept := _context.hand.cards[0]
	var kept_id := kept.get_id()
	kept.is_locked = true
	RedrawCardsAction.new().apply(_context)
	assert_eq(_context.hand.size(), 5)
	var still_there := false
	for card in _context.hand.cards:
		if card == kept:
			still_there = true
	assert_true(still_there, "the locked card %s must survive" % kept_id)

func test_redraw_needs_at_least_one_unlocked_card() -> void:
	var action := RedrawCardsAction.new()
	assert_true(action.can_apply(_context), "a fresh hand is all unlocked")
	for card in _context.hand.cards:
		card.is_locked = true
	assert_false(action.can_apply(_context), "a fully locked hand has nothing to redraw")

func test_redraw_does_not_require_a_selection() -> void:
	_context.hand.clear_selection()
	assert_true(RedrawCardsAction.new().can_apply(_context),
		"redraw acts on locks, not on the selection")

# --- lock ---------------------------------------------------------------

func test_lock_marks_the_selected_cards() -> void:
	_context.hand.toggle_selection(_context.hand.cards[0])
	_context.hand.toggle_selection(_context.hand.cards[2])
	LockCardAction.new().apply(_context)
	assert_true(_context.hand.cards[0].is_locked)
	assert_true(_context.hand.cards[2].is_locked)
	assert_false(_context.hand.cards[1].is_locked)

func test_lock_clears_the_selection() -> void:
	_context.hand.toggle_selection(_context.hand.cards[0])
	LockCardAction.new().apply(_context)
	assert_eq(_context.hand.selected_count(), 0)

func test_lock_needs_an_unlocked_selection() -> void:
	var action := LockCardAction.new()
	assert_false(action.can_apply(_context), "nothing selected")
	_context.hand.toggle_selection(_context.hand.cards[0])
	assert_true(action.can_apply(_context))
	_context.hand.cards[0].is_locked = true
	assert_false(action.can_apply(_context), "already locked, nothing to do")

# --- draw extra ---------------------------------------------------------

func test_draw_extra_widens_the_hand() -> void:
	var action := DrawExtraCardAction.new()
	action.amount = 2
	action.apply(_context)
	assert_eq(_context.hand.max_size, 7)
	assert_eq(_context.hand.size(), 7, "the new slots are filled immediately")

func test_draw_extra_needs_a_non_empty_deck() -> void:
	var action := DrawExtraCardAction.new()
	assert_true(action.can_apply(_context))
	_context.deck.draw(52)
	assert_false(action.can_apply(_context), "an exhausted deck has nothing to give")

# --- multiplier ---------------------------------------------------------

func test_multiplier_raises_the_context_multiplier() -> void:
	var action := ScoreMultiplierAction.new()
	action.bonus = 0.5
	action.apply(_context)
	assert_almost_eq(_context.score_multiplier, 1.5)

func test_multipliers_stack_within_a_turn() -> void:
	var action := ScoreMultiplierAction.new()
	action.bonus = 1.0
	action.apply(_context)
	action.apply(_context)
	assert_almost_eq(_context.score_multiplier, 3.0)

func test_multiplier_is_always_applicable() -> void:
	assert_true(ScoreMultiplierAction.new().can_apply(_context),
		"it has no precondition, unlike the others")

# --- the starter die ----------------------------------------------------

func test_starter_die_has_six_faces_all_carrying_actions() -> void:
	var die := StarterDice.create_action_d6()
	assert_eq(die.face_count(), 6)
	for face in die.faces:
		if face.action == null:
			fail("face %s has no action" % face.id)
			return
		if face.action.description.is_empty():
			fail("face %s has no description for the UI" % face.id)
			return
	assert_true(true, "every face carries a described action")
