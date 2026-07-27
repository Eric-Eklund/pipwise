extends TestCase
## The ten-level curve: what each level asks for, what it hands the player, and
## the guarantee that every one of them is actually playable.

var _campaign : Campaign

func before_each() -> void:
	_campaign = Campaign.new()

# --- the curve -------------------------------------------------------------

## Targets are measured, not computed, so every level in the campaign has to be
## in the table. The curve is only a fallback for a level past the end of it.
func test_every_level_has_an_authored_target() -> void:
	for level in range(1, _campaign.level_count + 1):
		assert_true(Campaign.TARGETS.has(level), "level %d is measured" % level)

func test_the_fallback_curve_takes_over_past_the_table() -> void:
	assert_eq(_campaign.target_for(11), _campaign.base_target + int(10 * _campaign.target_step))

## Only across the ordinary levels. A boss can and does ask for less — the Fire
## Lord lets a fifth of the table score, so 2600 there is harder than 13000 on
## level 9, and comparing the two numbers means nothing.
func test_the_target_climbs_across_the_ordinary_levels() -> void:
	var previous := 0
	for level in range(1, _campaign.level_count + 1):
		if Campaign.BOSSES.has(level):
			continue
		var target := _campaign.target_for(level)
		assert_true(target > previous, "level %d asks for more than the last" % level)
		previous = target

func test_the_turn_count_is_cut_once_and_late() -> void:
	assert_eq(_campaign.turns_for(1), _campaign.base_turns)
	assert_eq(
		_campaign.turns_for(_campaign.turn_cut_level),
		_campaign.base_turns - 1,
		"one turn fewer"
	)

func test_a_level_never_drops_below_one_turn() -> void:
	for level in range(1, _campaign.level_count + 1):
		assert_true(_campaign.turns_for(level) >= 1, "level %d is playable" % level)

## Losing the turn is punishment enough while the player is still learning what
## a Farkle is, so the points penalty starts late.
func test_the_farkle_penalty_starts_at_zero() -> void:
	assert_eq(_campaign.penalty_for(1), 0, "no penalty on level 1")
	assert_eq(
		_campaign.penalty_for(_campaign.penalty_from_level),
		_campaign.farkle_penalty,
		"and arrives later"
	)

# --- what each level hands out ---------------------------------------------

func test_the_opening_levels_are_plain_dice() -> void:
	for level in [1, 2]:
		for die_type in _campaign.bag_for(level).dice:
			assert_eq(die_type.element, Element.NONE, "level %d is elementless" % level)

func test_elements_arrive_on_level_three() -> void:
	var elements := _elements_in(_campaign.bag_for(3))
	assert_true(elements.has(Element.FIRE), "Fire shows up")

## A trio is where the interesting element rules switch on, so the campaign has
## to hand out three of something before it can teach them.
func test_a_trio_is_first_possible_on_level_four() -> void:
	assert_true(_count_of(_campaign.bag_for(3), Element.FIRE) < 3, "not yet on 3")
	assert_true(_count_of(_campaign.bag_for(4), Element.FIRE) >= 3, "a trio on 4")

## Two trios at once is the most interesting bag in the MVP: both element rules
## are live and the player has to pick which one a given roll is for.
func test_a_late_level_hands_out_two_trios() -> void:
	var bag := _campaign.bag_for(8)
	assert_eq(_count_of(bag, Element.ICE), 3, "three Ice")
	assert_eq(_count_of(bag, Element.FIRE), 3, "three Fire")

## The rainbow bag reaches no trio and repeats no element, so the combo ladder
## never leaves x1 — it is the weakest bag in the game until the mega combos
## exist. Pinned so it does not get dropped into the campaign as an upgrade.
func test_no_level_hands_out_the_rainbow_bag() -> void:
	for level in range(1, _campaign.level_count + 1):
		assert_true(
			_elements_in(_campaign.bag_for(level)).size() <= 3,
			"level %d does not spread itself across every element" % level
		)

func test_every_level_hands_out_six_dice() -> void:
	for level in range(1, _campaign.level_count + 1):
		assert_eq(_campaign.bag_for(level).size(), 6, "level %d" % level)

# --- bosses ----------------------------------------------------------------

func test_the_bosses_are_where_the_campaign_says_they_are() -> void:
	for level in range(1, _campaign.level_count + 1):
		var expected : bool = Campaign.BOSSES.has(level)
		assert_eq(_campaign.is_boss(level), expected, "level %d" % level)

func test_a_boss_is_named_and_explained() -> void:
	for level in Campaign.BOSSES:
		var ruleset := _campaign.get_ruleset(int(level))
		assert_false(ruleset.boss_name.is_empty(), "level %s has a name" % level)
		assert_false(ruleset.boss_description.is_empty(), "and a description")

func test_an_ordinary_level_has_no_boss_name() -> void:
	assert_true(_campaign.get_ruleset(1).boss_name.is_empty())

func test_the_fire_lord_locks_scoring_to_fire() -> void:
	var ruleset := _campaign.get_ruleset(10)
	assert_eq(ruleset.modifiers.size(), 1, "one twist")
	assert_true(ruleset.modifiers[0] is ElementLockModifier, "and it is the lock")

func test_the_ember_warden_gates_banking() -> void:
	var ruleset := _campaign.get_ruleset(5)
	assert_true(ruleset.modifiers[0] is MinimumBankModifier, "a bank gate")

# --- every level is playable ------------------------------------------------

## The guarantee that matters most: no level in the campaign can be built into
## something that crashes or cannot be started.
func test_every_level_starts_and_rolls() -> void:
	for level in range(1, _campaign.level_count + 1):
		var game := FarkleGame.new(_campaign.get_ruleset(level), RngService.new(level + 1))
		game.start()
		assert_eq(game.get_dice().size(), 6, "level %d has six dice" % level)
		assert_true(
			game.state == FarkleGame.State.CHOOSING or game.state == FarkleGame.State.FARKLED,
			"level %d reaches a playable state" % level
		)

func test_every_level_asks_for_a_positive_target() -> void:
	for level in range(1, _campaign.level_count + 1):
		assert_true(_campaign.get_ruleset(level).get_target_score() > 0, "level %d" % level)

# --- helpers ---------------------------------------------------------------

func _count_of(bag : BagDefinition, element : StringName) -> int:
	var count := 0
	for die_type in bag.dice:
		if die_type.element == element:
			count += 1
	return count

func _elements_in(bag : BagDefinition) -> Array[StringName]:
	var found : Array[StringName] = []
	for die_type in bag.dice:
		if die_type.element not in found:
			found.append(die_type.element)
	return found
