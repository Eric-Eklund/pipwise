extends TestCase
## The scoring table, the decompositions, and the one question that matters:
## does this roll score at all?

var _rules : ElementRules

func before_each() -> void:
	# No elements unless a test asks for them, so the plain Farkle numbers can
	# be pinned without an element quietly inflating them.
	_rules = ElementRules.new()

# --- fixtures --------------------------------------------------------------

## A die showing [param value], optionally of an element.
func die(value : int, element : StringName = Element.NONE) -> Die:
	var type := DieType.new()
	type.id = StringName("test_%s" % element)
	type.element = element
	type.faces = [DieFace.create(&"pip", value, str(value))]
	var result := Die.new(type)
	result.current_face = type.faces[0]
	return result

## Dice from a list of values, all of the same element.
func dice(values : Array, element : StringName = Element.NONE) -> Array[Die]:
	var result : Array[Die] = []
	for value in values:
		result.append(die(int(value), element))
	return result

## Dice from pairs of [value, element].
func mixed(spec : Array) -> Array[Die]:
	var result : Array[Die] = []
	for entry in spec:
		result.append(die(int(entry[0]), entry[1]))
	return result

func score_of(values : Array, rules : ElementRules = null) -> DiceScore:
	return FarkleScorer.score(dice(values), rules if rules != null else _rules)

# --- singles ---------------------------------------------------------------

func test_a_single_one_scores_one_hundred() -> void:
	assert_eq(score_of([1]).total(), 100, "single 1")

func test_a_single_five_scores_fifty() -> void:
	assert_eq(score_of([5]).total(), 50, "single 5")

func test_two_ones_score_as_two_singles() -> void:
	assert_eq(score_of([1, 1]).total(), 200, "two 1s")

func test_one_and_five_together() -> void:
	assert_eq(score_of([1, 5]).total(), 150, "1 + 5")

## The deviation from the design document, pinned so it cannot drift back: a
## lone 2, 3, 4 or 6 is worth nothing. If these ever score, Farkle stops
## existing and the game loses its core.
func test_other_singles_do_not_score() -> void:
	for value in [2, 3, 4, 6]:
		var result := score_of([value])
		assert_eq(result.total(), 0, "single %d is worthless" % value)
		assert_false(result.is_valid(), "single %d is not a legal take" % value)

# --- sets ------------------------------------------------------------------

func test_triples_match_the_design_table() -> void:
	var expected := {1: 1000, 2: 200, 3: 300, 4: 400, 5: 500, 6: 600}
	for value in expected:
		assert_eq(
			score_of([value, value, value]).total(),
			int(expected[value]),
			"three %ds" % value
		)

func test_each_die_past_the_third_doubles_the_set() -> void:
	assert_eq(score_of([2, 2, 2, 2]).total(), 400, "four 2s")
	assert_eq(score_of([2, 2, 2, 2, 2]).total(), 800, "five 2s")
	assert_eq(score_of([2, 2, 2, 2, 2, 2]).total(), 1600, "six 2s")
	assert_eq(score_of([1, 1, 1, 1, 1, 1]).total(), 8000, "six 1s")

func test_a_set_beats_the_singles_it_contains() -> void:
	# Three 1s as a triple is 1000; as three singles it would be 300.
	assert_eq(score_of([1, 1, 1]).total(), 1000, "three 1s take the triple")

func test_a_set_and_a_single_together() -> void:
	assert_eq(score_of([4, 4, 4, 1]).total(), 500, "three 4s + a 1")

# --- whole-set shapes ------------------------------------------------------

func test_a_straight_scores_fifteen_hundred() -> void:
	assert_eq(score_of([1, 2, 3, 4, 5, 6]).total(), 1500, "straight")

func test_a_straight_beats_reading_it_as_a_one_and_a_five() -> void:
	# The ordinary reading is 150 with four dice left over, and invalid besides.
	var result := score_of([6, 5, 4, 3, 2, 1])
	assert_true(result.is_valid(), "the whole straight is takeable")
	assert_eq(result.parts.size(), 1, "scores as one shape")

func test_three_pairs_score_fifteen_hundred() -> void:
	assert_eq(score_of([2, 2, 3, 3, 4, 4]).total(), 1500, "three pairs")

func test_three_pairs_only_when_all_six_are_paired() -> void:
	# Two pairs and two singles is not three pairs, and nothing else scores.
	assert_false(score_of([2, 2, 3, 3, 4, 6]).is_valid(), "not three pairs")

func test_six_of_a_kind_beats_three_pairs() -> void:
	# Six 1s could not read as three pairs anyway, but six 2s at 1600 must beat
	# any temptation to call them something cheaper.
	assert_eq(score_of([2, 2, 2, 2, 2, 2]).total(), 1600, "six 2s over 1500")

func test_a_straight_is_only_a_straight_at_six_dice() -> void:
	assert_false(score_of([1, 2, 3, 4, 5]).is_valid(), "five of a straight is not one")

# --- validity --------------------------------------------------------------

func test_a_selection_with_a_dead_die_is_invalid() -> void:
	var result := score_of([1, 1, 3])
	assert_false(result.is_valid(), "the 3 cannot be kept")
	assert_eq(result.leftover_count, 1, "one die contributes nothing")
	assert_eq(result.total(), 0, "an invalid selection is worth nothing")

func test_an_empty_selection_is_invalid() -> void:
	assert_false(score_of([]).is_valid(), "nothing selected")

func test_a_valid_selection_beats_a_higher_invalid_one() -> void:
	# [1,1,1,2] could claim the 1000 from the triple, but the 2 makes it
	# untakeable, so the result has to report itself invalid rather than boast.
	assert_false(score_of([1, 1, 1, 2]).is_valid(), "the 2 spoils it")

# --- Farkle detection ------------------------------------------------------

func test_a_roll_with_no_ones_fives_or_sets_is_a_farkle() -> void:
	assert_false(
		FarkleScorer.has_scoring_dice(dice([2, 2, 3, 4, 6, 6]), _rules),
		"nothing scores"
	)

func test_a_lone_one_saves_a_roll_from_being_a_farkle() -> void:
	assert_true(
		FarkleScorer.has_scoring_dice(dice([2, 2, 3, 4, 6, 1]), _rules),
		"the 1 scores"
	)

func test_a_triple_saves_a_roll_from_being_a_farkle() -> void:
	assert_true(
		FarkleScorer.has_scoring_dice(dice([2, 2, 2, 4, 6, 3]), _rules),
		"the triple scores"
	)

func test_farkle_is_possible_at_all() -> void:
	# The guard on the whole design: with plain dice there must exist rolls that
	# score nothing, or push-your-luck has no teeth.
	assert_false(
		FarkleScorer.has_scoring_dice(dice([2, 3, 4, 6]), _rules),
		"a four-die Farkle"
	)
	assert_false(FarkleScorer.has_scoring_dice(dice([3]), _rules), "a one-die Farkle")

# --- best selection --------------------------------------------------------

func test_best_selection_takes_everything_that_scores() -> void:
	var pool := dice([1, 5, 3, 4, 4, 4])
	var best := FarkleScorer.best_selection(pool, _rules)
	assert_eq(best.size(), 5, "the 1, the 5 and the three 4s")
	assert_false(pool[2] in best, "the lone 3 is left behind")

func test_best_selection_is_empty_on_a_farkle() -> void:
	assert_eq(FarkleScorer.best_selection(dice([2, 3, 4, 6]), _rules).size(), 0, "nothing")

# --- elements: per-die bonuses ---------------------------------------------

func test_fire_adds_half_again_to_a_scored_six() -> void:
	# Three Fire 6s: 600 base, each die's share is 200, +50% each = +300.
	# Three Fire dice also fire the Fire trio (+200) and a x2.5 combo.
	var pool := dice([6, 6, 6], Element.FIRE)
	var result := FarkleScorer.score(pool, ElementRules.new(pool))
	assert_eq(result.base_points, 600, "base")
	assert_eq(int(round(result.element_bonus)), 300, "+50% per die")
	assert_eq(result.bonus_points, 200, "Fire trio flat bonus")
	assert_eq(result.total(), 2750, "(600 + 500) x2.5")

func test_crystal_triples_a_scored_one() -> void:
	# One Crystal 1 among plain dice: 100 base, +200% = +200.
	var pool := mixed([[1, Element.CRYSTAL], [3, Element.NONE]])
	var result := FarkleScorer.score([pool[0]] as Array[Die], ElementRules.new(pool))
	assert_eq(result.total(), 300, "a Crystal 1 pays triple")

func test_lightning_doubles_a_scored_five() -> void:
	var pool := mixed([[5, Element.LIGHTNING], [3, Element.NONE]])
	var result := FarkleScorer.score([pool[0]] as Array[Die], ElementRules.new(pool))
	assert_eq(result.total(), 100, "50 doubled")

func test_lightning_leaves_low_faces_alone() -> void:
	var pool := mixed([[1, Element.LIGHTNING], [3, Element.NONE]])
	var result := FarkleScorer.score([pool[0]] as Array[Die], ElementRules.new(pool))
	assert_eq(result.total(), 100, "a 1 is not a high face")

func test_ice_doubles_dice_inside_a_matched_set() -> void:
	# Three Ice 4s: 400 base, share 133.3 each, +100% each = +400.
	# Three Ice also means a x2.5 combo.
	var pool := dice([4, 4, 4], Element.ICE)
	var result := FarkleScorer.score(pool, ElementRules.new(pool))
	assert_eq(int(round(result.element_bonus)), 400, "+100% per die")
	assert_eq(result.total(), 2000, "(400 + 400) x2.5")

func test_ice_leaves_a_lone_single_alone() -> void:
	var pool := mixed([[1, Element.ICE], [3, Element.NONE]])
	var result := FarkleScorer.score([pool[0]] as Array[Die], ElementRules.new(pool))
	assert_eq(result.total(), 100, "a single is not a matched set")

# --- elements: trios -------------------------------------------------------

func test_the_ice_trio_makes_pairs_score() -> void:
	var pool := dice([2, 2, 3, 3, 6, 4], Element.ICE)
	var rules := ElementRules.new(pool)
	assert_true(rules.pairs_score(), "three Ice dice in play")
	assert_true(FarkleScorer.has_scoring_dice(pool, rules), "the pairs rescue the roll")

func test_without_the_ice_trio_the_same_roll_is_a_farkle() -> void:
	var pool := dice([2, 2, 3, 3, 6, 4])
	assert_false(
		FarkleScorer.has_scoring_dice(pool, ElementRules.new(pool)),
		"no Ice, no pairs, no score"
	)

func test_the_crystal_trio_pays_for_a_straight() -> void:
	var pool := dice([1, 2, 3, 4, 5, 6], Element.CRYSTAL)
	var result := FarkleScorer.score(pool, ElementRules.new(pool))
	assert_eq(result.bonus_points, 1000, "Crystal trio straight bonus")

func test_the_lightning_trio_triples_high_faces() -> void:
	# Three Lightning 6s: 600 base, share 200, +200% each = +1200.
	var pool := dice([6, 6, 6], Element.LIGHTNING)
	var result := FarkleScorer.score(pool, ElementRules.new(pool))
	assert_eq(int(round(result.element_bonus)), 1200, "tripled, not doubled")

# --- elements: combo ladder ------------------------------------------------

func test_the_combo_ladder_matches_the_design_table() -> void:
	var expected := {2: 1.5, 3: 2.5, 4: 4.0, 5: 6.0, 6: 10.0}
	for count in expected:
		var pool := dice([1, 1, 1, 1, 1, 1])
		# Make exactly `count` of them Fire and the rest elementless.
		for i in pool.size():
			pool[i].element = Element.FIRE if i < count else Element.NONE
		var result := FarkleScorer.score(pool, ElementRules.new(pool))
		assert_eq(
			result.combo_multiplier,
			float(expected[count]),
			"%d matching dice" % count
		)

func test_one_die_of_an_element_earns_no_combo() -> void:
	var pool := mixed([[1, Element.FIRE], [5, Element.ICE]])
	var result := FarkleScorer.score(pool, ElementRules.new(pool))
	assert_eq(result.combo_multiplier, 1.0, "nothing repeats")

func test_the_combo_counts_only_dice_that_scored() -> void:
	# Four Fire dice on the table, but only two of them score.
	var pool := dice([1, 5, 3, 4], Element.FIRE)
	var scored : Array[Die] = [pool[0], pool[1]]
	var result := FarkleScorer.score(scored, ElementRules.new(pool))
	assert_eq(result.combo_multiplier, 1.5, "two scored, not four")

func test_the_leading_element_carries_the_whole_selection() -> void:
	var pool := mixed([
		[1, Element.FIRE], [1, Element.FIRE], [1, Element.FIRE], [5, Element.ICE]
	])
	var result := FarkleScorer.score(pool, ElementRules.new(pool))
	assert_eq(result.combo_element, Element.FIRE, "Fire leads")
	assert_eq(result.combo_count, 3, "three of them")
	assert_eq(result.combo_multiplier, 2.5, "the Ice die rides along")

# --- Nature and Shadow, which pay in something other than points -----------

## Nature reads the pips on the scored dice, not the points they earned — see
## ElementRules.dice_restored for why. 1 + 5 is six pips, so a die comes back.
func test_nature_returns_a_die_on_an_even_pip_total() -> void:
	# Two Nature dice, deliberately one short of the trio.
	var pool := mixed([[1, Element.NATURE], [5, Element.NATURE], [4, Element.NONE]])
	var scored : Array[Die] = [pool[0], pool[1]]
	var result := FarkleScorer.score(scored, ElementRules.new(pool))
	assert_eq(result.dice_restored, 1, "one die back")

func test_the_nature_trio_returns_two() -> void:
	var pool := dice([1, 5, 4, 6], Element.NATURE)
	var scored : Array[Die] = [pool[0], pool[1]]
	var result := FarkleScorer.score(scored, ElementRules.new(pool))
	assert_eq(result.dice_restored, 2, "two dice back")

## One pip is odd, so nothing comes back — the condition has to be a real coin
## flip or Nature is just a free die every turn.
func test_nature_returns_nothing_on_an_odd_pip_total() -> void:
	var pool := mixed([[1, Element.NATURE], [5, Element.NATURE], [4, Element.NONE]])
	var scored : Array[Die] = [pool[0]]
	var result := FarkleScorer.score(scored, ElementRules.new(pool))
	assert_eq(result.dice_restored, 0, "no die back")

func test_nature_returns_nothing_without_a_nature_die_scoring() -> void:
	var pool := mixed([[1, Element.NATURE], [5, Element.NONE], [4, Element.NONE]])
	var scored : Array[Die] = [pool[1]]
	var result := FarkleScorer.score(scored, ElementRules.new(pool))
	assert_eq(result.dice_restored, 0, "the Nature die stayed on the table")

func test_shadow_halves_the_farkle_penalty() -> void:
	var pool := mixed([[2, Element.SHADOW], [3, Element.NONE], [4, Element.NONE]])
	assert_eq(ElementRules.new(pool).farkle_penalty(100), 50, "halved")

func test_the_shadow_trio_makes_a_farkle_pay() -> void:
	var pool := dice([2, 3, 4], Element.SHADOW)
	assert_eq(ElementRules.new(pool).farkle_penalty(100), -50, "a Farkle earns 50")

func test_no_shadow_means_the_full_penalty() -> void:
	var pool := dice([2, 3, 4])
	assert_eq(ElementRules.new(pool).farkle_penalty(100), 100, "unchanged")

# --- breakdown -------------------------------------------------------------

func test_the_breakdown_reads_as_the_player_sees_it() -> void:
	var pool := dice([6, 6, 6], Element.FIRE)
	var result := FarkleScorer.score(pool, ElementRules.new(pool))
	assert_eq(result.breakdown_text(), "(600 + 500) x2.5 = 2750", "the sum")

func test_a_plain_score_shows_just_the_number() -> void:
	assert_eq(score_of([1]).breakdown_text(), "100", "no bonus, no multiplier")

func test_parts_are_named() -> void:
	assert_eq(score_of([4, 4, 4, 1]).parts_text(), "Single 1 + Three 4s", "named")
