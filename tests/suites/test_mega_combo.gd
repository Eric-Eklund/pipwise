extends TestCase
## Section 2.3's mega combos, as pure detection — what shape of selection fires
## which combo, with no scorer and no points involved.
##
## Kept apart from test_farkle_scorer.gd because these are predicates over a list
## of dice and nothing else. What the combos are *worth* is scoring, and lives
## over there.

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

## Dice from pairs of [value, element].
func mixed(spec : Array) -> Array[Die]:
	var result : Array[Die] = []
	for entry in spec:
		result.append(die(int(entry[0]), entry[1]))
	return result

## One die of every element, all showing [param value].
func rainbow(value : int = 1) -> Array[Die]:
	var result : Array[Die] = []
	for element in Element.ALL:
		result.append(die(value, element))
	return result

# --- elemental master ------------------------------------------------------

func test_all_six_elements_fire_elemental_master() -> void:
	assert_eq(MegaCombo.detect(rainbow(1)), MegaCombo.ELEMENTAL_MASTER, "one of each")

func test_five_elements_are_not_enough() -> void:
	var dice := rainbow(1)
	dice.remove_at(0)
	assert_eq(MegaCombo.detect(dice), MegaCombo.NONE, "five of the six")

## The rainbow bag's whole point: one die per element repeats nothing, so the
## section 2.1 ladder never leaves x1 and no trio ever fires. Master is the only
## rule that pays it anything at all.
func test_elemental_master_needs_no_repeats() -> void:
	var dice := rainbow(1)
	assert_eq(dice.size(), 6, "six dice, six elements, no pair among them")
	assert_eq(MegaCombo.detect(dice), MegaCombo.ELEMENTAL_MASTER, "and it still fires")

# --- universal overload ----------------------------------------------------

func test_every_element_showing_a_six_fires_universal_overload() -> void:
	assert_eq(MegaCombo.detect(rainbow(6)), MegaCombo.UNIVERSAL_OVERLOAD, "six 6s, six elements")

## Overload is Master plus a condition, so a selection that satisfies both has to
## read as the rarer one or the flat bonus is silently lost.
func test_universal_overload_outranks_elemental_master() -> void:
	var dice := rainbow(6)
	assert_eq(MegaCombo.detect(dice), MegaCombo.UNIVERSAL_OVERLOAD, "not Master")
	assert_eq(MegaCombo.flat_bonus_for(MegaCombo.detect(dice)), 5000, "and it pays")

func test_one_die_off_six_drops_overload_back_to_master() -> void:
	var dice := rainbow(6)
	dice[2].current_face = DieFace.create(&"pip", 1, "1")
	assert_eq(MegaCombo.detect(dice), MegaCombo.ELEMENTAL_MASTER, "still every element")

# --- chaos mode ------------------------------------------------------------

func test_two_of_each_of_two_elements_fires_chaos() -> void:
	var dice := mixed([
		[1, Element.CRYSTAL], [1, Element.CRYSTAL],
		[5, Element.LIGHTNING], [5, Element.LIGHTNING],
	])
	assert_eq(MegaCombo.detect(dice), MegaCombo.CHAOS_MODE, "two Crystal, two Lightning")

## The rule that makes the take a decision: one lone element die is enough to
## break the combo, and dropping it is what wins it back.
func test_a_lone_element_die_breaks_chaos() -> void:
	var dice := mixed([
		[1, Element.CRYSTAL], [1, Element.CRYSTAL],
		[5, Element.LIGHTNING], [5, Element.LIGHTNING],
		[6, Element.FIRE],
	])
	assert_eq(MegaCombo.detect(dice), MegaCombo.NONE, "the single Fire spoils it")
	dice.remove_at(4)
	assert_eq(MegaCombo.detect(dice), MegaCombo.CHAOS_MODE, "and dropping it restores it")

func test_one_element_however_many_dice_is_not_chaos() -> void:
	var dice := mixed([
		[1, Element.CRYSTAL], [1, Element.CRYSTAL],
		[1, Element.CRYSTAL], [1, Element.CRYSTAL],
	])
	assert_eq(MegaCombo.detect(dice), MegaCombo.NONE, "four Crystal is one element")

## The trap. Element.NONE is the absence of an element, not a seventh one — if it
## counted, Chaos would fire on two Fire dice and some padding, which is a hand
## every level from 3 on can roll, and the player would be asked to drop plain
## dice that have nothing elemental about them to dilute.
func test_plain_dice_are_invisible_to_chaos() -> void:
	var dice := mixed([
		[6, Element.FIRE], [6, Element.FIRE],
		[1, Element.NONE], [1, Element.NONE],
	])
	assert_eq(MegaCombo.detect(dice), MegaCombo.NONE, "padding is not an element")

## Padding must not break a combo either, for the same reason.
func test_plain_dice_do_not_break_chaos() -> void:
	var dice := mixed([
		[6, Element.FIRE], [6, Element.FIRE],
		[1, Element.CRYSTAL], [1, Element.CRYSTAL],
		[5, Element.NONE],
	])
	assert_eq(MegaCombo.detect(dice), MegaCombo.CHAOS_MODE, "the plain 5 is beside the point")

func test_nothing_fires_on_an_empty_selection() -> void:
	assert_eq(MegaCombo.detect([] as Array[Die]), MegaCombo.NONE, "no dice, no combo")

func test_nothing_fires_on_plain_dice_alone() -> void:
	var dice := mixed([[1, Element.NONE], [1, Element.NONE], [5, Element.NONE]])
	assert_eq(MegaCombo.detect(dice), MegaCombo.NONE, "no elements at all")

# --- what they pay ---------------------------------------------------------

func test_only_the_master_combos_move_the_multiplier() -> void:
	assert_almost_eq(MegaCombo.multiplier_floor_for(MegaCombo.ELEMENTAL_MASTER), 5.0, 0.001, "Master")
	assert_almost_eq(MegaCombo.multiplier_floor_for(MegaCombo.UNIVERSAL_OVERLOAD), 5.0, 0.001, "Overload")
	assert_almost_eq(MegaCombo.multiplier_floor_for(MegaCombo.CHAOS_MODE), 1.0, 0.001, "Chaos leaves it")
	assert_almost_eq(MegaCombo.multiplier_floor_for(MegaCombo.NONE), 1.0, 0.001, "and so does nothing")

func test_only_chaos_moves_the_element_bonus() -> void:
	assert_almost_eq(
		MegaCombo.element_bonus_multiplier_for(MegaCombo.CHAOS_MODE), 2.0, 0.001, "Chaos doubles"
	)
	assert_almost_eq(
		MegaCombo.element_bonus_multiplier_for(MegaCombo.ELEMENTAL_MASTER), 1.0, 0.001, "Master does not"
	)

func test_only_overload_pays_flat() -> void:
	assert_eq(MegaCombo.flat_bonus_for(MegaCombo.UNIVERSAL_OVERLOAD), 5000, "Overload")
	assert_eq(MegaCombo.flat_bonus_for(MegaCombo.ELEMENTAL_MASTER), 0, "Master")
	assert_eq(MegaCombo.flat_bonus_for(MegaCombo.CHAOS_MODE), 0, "Chaos")

# --- how they read ---------------------------------------------------------

func test_every_combo_names_itself() -> void:
	for id in MegaCombo.ALL:
		assert_false(MegaCombo.get_label(id).is_empty(), "%s has a label" % id)
		assert_false(MegaCombo.get_effect_text(id).is_empty(), "%s says what it pays" % id)
		assert_false(MegaCombo.get_description(id).is_empty(), "%s explains itself" % id)

func test_nothing_names_nothing() -> void:
	assert_eq(MegaCombo.get_label(MegaCombo.NONE), "", "NONE is not a combo")
