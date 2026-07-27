extends TestCase
## The thirty-level campaign: the shape of the curve, and that every level it
## produces is actually playable.
##
## The exact tuning numbers are not pinned here — they move whenever
## tools/balance_probe.gd says they should. What is pinned is the structure: the
## target never goes backwards, never exceeds what a hand can reach, resources
## only ever tighten, and no level is malformed.

const C := PokerHandClassifier.Category

var _campaign : Campaign

func before_each() -> void:
	_campaign = load("res://resources/campaign.tres")

func _levels() -> Array:
	return range(1, _campaign.level_count + 1)

# --- the curve ----------------------------------------------------------

func test_the_campaign_is_thirty_levels() -> void:
	assert_eq(_campaign.level_count, 30)

func test_the_target_never_goes_backwards() -> void:
	var previous := 0
	for level in _levels():
		var target := _campaign.target_for(level)
		if target < previous:
			fail("level %d asks for %d after %d" % [level, target, previous])
			return
		previous = target
	assert_true(true, "the target climbs or holds")

## Past the ceiling a target stops being difficult and starts being impossible,
## because the player's scoring power does not grow with the level number.
func test_the_target_stops_at_the_ceiling() -> void:
	for level in _levels():
		if _campaign.target_for(level) > _campaign.target_ceiling:
			fail("level %d exceeds the ceiling" % level)
			return
	assert_eq(
		_campaign.target_for(_campaign.level_count), _campaign.target_ceiling,
		"and the last level reaches it"
	)

func test_rerolls_only_ever_decrease() -> void:
	var previous := 99
	for level in _levels():
		var rerolls := _campaign.rerolls_for(level)
		if rerolls > previous:
			fail("level %d hands back a reroll" % level)
			return
		previous = rerolls
	assert_true(true, "resources only tighten")

func test_the_player_always_keeps_at_least_one_reroll() -> void:
	for level in _levels():
		if _campaign.rerolls_for(level) < 1:
			fail("level %d has no rerolls at all" % level)
			return
	assert_true(true)

func test_dice_only_ever_decrease() -> void:
	assert_eq(_campaign.dice_for(1), 6)
	assert_eq(_campaign.dice_for(_campaign.level_count), 5)
	var previous := 99
	for level in _levels():
		var dice := _campaign.dice_for(level)
		if dice > previous:
			fail("level %d hands back a die" % level)
			return
		previous = dice
	assert_true(true)

func test_shape_demands_only_ever_harden() -> void:
	var previous := -1
	for level in _levels():
		var demand := _campaign.demand_for(level)
		if demand < previous:
			fail("level %d asks for less than level %d did" % [level, level - 1])
			return
		previous = demand
	assert_true(true)

func test_early_levels_ask_only_for_a_number() -> void:
	assert_eq(_campaign.demand_for(1), -1)
	assert_eq(_campaign.demand_for(_campaign.shape_demand_level - 1), -1)

func test_the_late_levels_ask_for_a_shape() -> void:
	assert_eq(_campaign.demand_for(_campaign.shape_demand_level), C.PAIR)
	assert_eq(_campaign.demand_for(_campaign.hard_shape_level), C.TWO_PAIR)

# --- bosses -------------------------------------------------------------

func test_the_five_bosses_are_where_the_spec_puts_them() -> void:
	for level in [5, 10, 15, 20, 25]:
		assert_true(_campaign.is_boss(level), "level %d should be a boss" % level)

func test_ordinary_levels_are_not_bosses() -> void:
	for level in [1, 4, 6, 11, 19, 26, 30]:
		assert_false(_campaign.is_boss(level), "level %d should be ordinary" % level)

func test_an_authored_ruleset_overrides_the_curve() -> void:
	var boss := _campaign.get_ruleset(5)
	assert_eq(boss.boss_name, "Frost King")
	assert_eq(boss.modifiers.size(), 1, "the file's modifier survived")

func test_an_ordinary_level_is_computed() -> void:
	var ruleset := _campaign.get_ruleset(7)
	assert_eq(ruleset.id, &"level_7")
	assert_true(ruleset.modifiers.is_empty())
	assert_eq(ruleset.get_objective().target_score, _campaign.target_for(7))

# --- every level ---------------------------------------------------------

func test_every_level_produces_a_usable_ruleset() -> void:
	for level in _levels():
		var ruleset := _campaign.get_ruleset(level)
		if ruleset == null:
			fail("level %d has no ruleset" % level)
			return
		if ruleset.hand_size < 4 or ruleset.dice_count < 1:
			fail("level %d is malformed: %d cards, %d dice" % [
				level, ruleset.hand_size, ruleset.dice_count
			])
			return
		if ruleset.get_objective().target_score <= 0:
			fail("level %d has no target" % level)
			return
	assert_true(true, "all %d levels are well formed" % _campaign.level_count)

## Drives every level to a verdict with a fixed seed. Catches a level that
## cannot be finished at all, which no amount of tuning would show up as.
func test_every_level_can_be_played_to_a_verdict() -> void:
	for level in _levels():
		var game := CardDiceGame.new(_campaign.get_ruleset(level), RngService.new(level * 31))
		game.start()
		while not game.can_save_hand():
			var locked := false
			for die in game.get_dice():
				if not die.is_locked and game.toggle_lock(die):
					locked = true
					break
			if not locked:
				break
		if not game.can_save_hand():
			fail("level %d can never be saved" % level)
			return
		game.save_hand()
		if game.state != CardDiceGame.State.WON and game.state != CardDiceGame.State.LOST:
			fail("level %d reached no verdict" % level)
			return
	assert_true(true, "all %d levels reach a verdict" % _campaign.level_count)

func test_every_level_has_a_scene() -> void:
	for level in _levels():
		var path := "res://scenes/game_scene/levels/level_%d.tscn" % level
		if not ResourceLoader.exists(path):
			fail("no scene for level %d" % level)
			return
	assert_true(true, "all %d level scenes exist" % _campaign.level_count)
