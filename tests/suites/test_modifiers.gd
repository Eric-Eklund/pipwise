extends TestCase
## The boss twists, one at a time, plus the two that have to compose.
##
## Modifiers write into the context at level start rather than being consulted
## per hand, so most of these assert on the context afterwards. The one
## exception is The Gambler, which gates saving and therefore has to be asked
## every time.

const C := PokerHandClassifier.Category
const S := CardData.SPADES
const H := CardData.HEARTS
const D := CardData.DIAMONDS
const C_SUIT := CardData.CLUBS

func _context(dice : int = 6) -> GameContext:
	var rng := RngService.new(7)
	var pool := DicePool.new(StarterDice.create_starter_bag(dice), rng, 3)
	pool.roll_all()
	return GameContext.new(
		Deck.new(DeckDefinition.create_standard_52(), rng), Hand.new(5), pool, rng
	)

func _cards(specs : Array) -> Array[Card]:
	var cards : Array[Card] = []
	for spec in specs:
		cards.append(Card.new(CardData.create(spec[0], spec[1])))
	return cards

# --- Frost King ---------------------------------------------------------

func test_frost_king_freezes_one_die() -> void:
	var context := _context()
	var frost := FrozenDieModifier.new()
	frost.on_level_start(context)
	assert_eq(context.pool.frozen_count(), 1)

func test_frost_king_can_freeze_more_than_one() -> void:
	var context := _context()
	var frost := FrozenDieModifier.new()
	frost.count = 3
	frost.on_level_start(context)
	assert_eq(context.pool.frozen_count(), 3)

func test_a_frozen_die_still_counts_towards_the_score() -> void:
	var context := _context()
	var before := context.total_energy()
	FrozenDieModifier.new().on_level_start(context)
	assert_eq(context.total_energy(), before, "dead weight, not a dead die")

func test_frost_king_never_blocks_saving() -> void:
	var context := _context()
	var frost := FrozenDieModifier.new()
	frost.on_level_start(context)
	assert_true(frost.can_save_hand(context))

# --- The Gambler --------------------------------------------------------

func test_the_gambler_blocks_saving_until_two_dice_are_locked() -> void:
	var context := _context()
	var gambler := MinimumLocksModifier.new()
	gambler.on_level_start(context)
	assert_false(gambler.can_save_hand(context), "nothing locked yet")
	context.pool.set_locked(context.pool.dice[0], true)
	assert_false(gambler.can_save_hand(context), "one is not enough")
	context.pool.set_locked(context.pool.dice[1], true)
	assert_true(gambler.can_save_hand(context))

func test_the_gambler_says_how_many_are_still_needed() -> void:
	var context := _context()
	var gambler := MinimumLocksModifier.new()
	assert_eq(gambler.get_requirement_text(context), "Lock 2 more dice")
	context.pool.set_locked(context.pool.dice[0], true)
	assert_eq(gambler.get_requirement_text(context), "Lock 1 more die", "singular")
	context.pool.set_locked(context.pool.dice[1], true)
	assert_eq(gambler.get_requirement_text(context), "", "nothing outstanding")

# --- Mirror Master ------------------------------------------------------

func test_mirror_master_bans_the_pair() -> void:
	var context := _context()
	var ban := CategoryBanModifier.new()
	ban.banned = [C.PAIR]
	ban.on_level_start(context)
	assert_true(context.is_category_banned(C.PAIR))
	assert_false(context.is_category_banned(C.TWO_PAIR), "two pair is a different hand")

func test_a_banned_pair_scores_as_a_high_card() -> void:
	var context := _context()
	var ban := CategoryBanModifier.new()
	ban.banned = [C.PAIR]
	ban.on_level_start(context)
	var score := PokerHandEvaluator.new().evaluate(
		_cards([[5, S], [5, H], [9, D], [11, C_SUIT], [13, S]]), context
	)
	assert_eq(score.label, "High Card")

func test_the_bonus_raises_straights_and_flushes() -> void:
	var context := _context()
	var bonus := CategoryBonusModifier.new()
	bonus.categories = [C.STRAIGHT, C.FLUSH]
	bonus.bonus = 0.5
	bonus.on_level_start(context)
	assert_almost_eq(context.multiplier_bonus_for(C.STRAIGHT), 0.5)
	assert_almost_eq(context.multiplier_bonus_for(C.FLUSH), 0.5)
	assert_almost_eq(context.multiplier_bonus_for(C.PAIR), 0.0, 0.0001, "untouched")

func test_mirror_masters_two_modifiers_compose() -> void:
	var context := _context()
	var ban := CategoryBanModifier.new()
	ban.banned = [C.PAIR]
	var bonus := CategoryBonusModifier.new()
	bonus.categories = [C.STRAIGHT]
	bonus.bonus = 0.5
	ban.on_level_start(context)
	bonus.on_level_start(context)

	var evaluator := PokerHandEvaluator.new()
	var pair := evaluator.evaluate(
		_cards([[5, S], [5, H], [9, D], [11, C_SUIT], [13, S]]), context
	)
	var straight := evaluator.evaluate(
		_cards([[5, S], [6, H], [7, D], [8, C_SUIT], [9, S]]), context
	)
	assert_almost_eq(pair.multiplier, 1.0, 0.0001, "the pair fell to a high card")
	assert_almost_eq(straight.multiplier, 7.5, 0.0001, "x5 plus the 50%")

func test_two_bans_do_not_overwrite_each_other() -> void:
	var context := _context()
	var first := CategoryBanModifier.new()
	first.banned = [C.PAIR]
	var second := CategoryBanModifier.new()
	second.banned = [C.TWO_PAIR]
	first.on_level_start(context)
	second.on_level_start(context)
	assert_true(context.is_category_banned(C.PAIR))
	assert_true(context.is_category_banned(C.TWO_PAIR))

# --- Wild Card ----------------------------------------------------------

func test_wild_card_rules_out_suits_and_runs() -> void:
	var context := _context()
	var ban := CategoryBanModifier.new()
	ban.banned = [C.STRAIGHT, C.FLUSH, C.STRAIGHT_FLUSH]
	ban.on_level_start(context)

	var evaluator := PokerHandEvaluator.new()
	var straight_flush := evaluator.evaluate(
		_cards([[5, H], [6, H], [7, H], [8, H], [9, H]]), context
	)
	assert_eq(straight_flush.label, "High Card", "nothing left but the ranks")

	var trips := evaluator.evaluate(
		_cards([[8, S], [8, H], [8, D], [11, C_SUIT], [13, S]]), context
	)
	assert_eq(trips.label, "Three of a Kind", "matching ranks still pay")

# --- the base class -----------------------------------------------------

func test_a_bare_modifier_changes_nothing() -> void:
	var context := _context()
	var modifier := LevelModifier.new()
	modifier.on_level_start(context)
	assert_true(modifier.can_save_hand(context))
	assert_eq(modifier.get_requirement_text(context), "")
	assert_true(context.banned_categories.is_empty())
	assert_true(context.category_bonuses.is_empty())

# --- the shipped boss rulesets ------------------------------------------

func test_every_boss_level_names_itself() -> void:
	for level in [5, 10, 15, 20, 25]:
		var ruleset : Ruleset = load("res://resources/rulesets/level_%d.tres" % level)
		assert_false(ruleset.boss_name.is_empty(), "level %d has no boss name" % level)
		assert_false(
			ruleset.boss_description.is_empty(), "level %d has no description" % level
		)

func test_short_deck_is_a_boss_without_a_modifier() -> void:
	var ruleset : Ruleset = load("res://resources/rulesets/level_20.tres")
	assert_eq(ruleset.hand_size, 4)
	assert_true(ruleset.modifiers.is_empty(), "a smaller hand is the whole twist")
	assert_eq(ruleset.boss_name, "Short Deck")

func test_the_boss_rulesets_survive_a_round_trip() -> void:
	var mirror : Ruleset = load("res://resources/rulesets/level_15.tres")
	assert_eq(mirror.modifiers.size(), 2, "the ban and the bonus both loaded")
	var context := _context()
	for modifier in mirror.modifiers:
		modifier.on_level_start(context)
	assert_true(context.is_category_banned(C.PAIR))
	assert_almost_eq(context.multiplier_bonus_for(C.STRAIGHT), 0.5)

func test_every_boss_level_is_playable() -> void:
	for level in [5, 10, 15, 20, 25]:
		var ruleset : Ruleset = load("res://resources/rulesets/level_%d.tres" % level)
		var game := CardDiceGame.new(ruleset, RngService.new(level * 13))
		game.start()
		assert_eq(
			game.context.hand.size(), ruleset.hand_size,
			"level %d dealt the wrong number of cards" % level
		)
		# The Gambler refuses until two dice are locked, so satisfy it first.
		while not game.can_save_hand():
			var locked := false
			for die in game.get_dice():
				if not die.is_locked and game.toggle_lock(die):
					locked = true
					break
			if not locked:
				break
		assert_true(game.can_save_hand(), "level %d cannot be saved at all" % level)
		game.save_hand()
		assert_true(
			game.state == CardDiceGame.State.WON or game.state == CardDiceGame.State.LOST,
			"level %d did not reach a verdict" % level
		)
