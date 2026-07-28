extends TestCase
## What the player owns, what clearing a level pays, and the loan that keeps a
## measured target reachable.

var _collection : DiceCollection

func before_each() -> void:
	_collection = DiceCollection.create_starting()

func bag(spec : Array) -> BagDefinition:
	return StarterDice.create_mixed_bag(spec)

# --- what you start with ---------------------------------------------------

func test_a_new_player_owns_six_plain_dice() -> void:
	assert_eq(_collection.count_of(Element.NONE), 6, "six plain")
	assert_eq(_collection.total(), 6, "and nothing else")

## Elements are earned, not given. If a new player already owned Fire, clearing
## level 3 would pay nothing and the whole progression would start empty.
func test_a_new_player_owns_no_elements() -> void:
	for element in Element.ALL:
		assert_eq(_collection.count_of(element), 0, "no %s" % element)

func test_two_collections_do_not_share_a_dictionary() -> void:
	var other := DiceCollection.create_starting()
	_collection.grant(Element.FIRE, 3)
	assert_eq(other.count_of(Element.FIRE), 0, "the other one is untouched")

# --- granting --------------------------------------------------------------

func test_granting_adds_to_the_collection() -> void:
	_collection.grant(Element.FIRE, 2)
	assert_eq(_collection.count_of(Element.FIRE), 2)
	assert_true(_collection.owns(Element.FIRE, 2), "owns two")
	assert_false(_collection.owns(Element.FIRE, 3), "but not three")

func test_clearing_a_level_pays_what_it_showed_you() -> void:
	var granted := _collection.grant_up_to(bag([[Element.FIRE, 2]]))
	assert_eq(int(granted.get(Element.FIRE, 0)), 2, "two Fire")
	assert_eq(_collection.count_of(Element.FIRE), 2, "and they are owned")

## Topping up rather than adding. The reward is reaching a level for the first
## time; replaying level 3 must not be a Fire dice farm.
func test_clearing_a_level_twice_pays_once() -> void:
	var level_bag := bag([[Element.FIRE, 2]])
	_collection.grant_up_to(level_bag)
	var second := _collection.grant_up_to(level_bag)
	assert_true(second.is_empty(), "nothing new the second time")
	assert_eq(_collection.count_of(Element.FIRE), 2, "still two")

func test_a_later_level_pays_only_the_difference() -> void:
	_collection.grant_up_to(bag([[Element.FIRE, 2]]))
	var granted := _collection.grant_up_to(bag([[Element.FIRE, 3]]))
	assert_eq(int(granted.get(Element.FIRE, 0)), 1, "one more Fire")
	assert_eq(_collection.count_of(Element.FIRE), 3, "three in total")

func test_granting_nothing_is_harmless() -> void:
	_collection.grant(Element.FIRE, 0)
	_collection.grant(Element.FIRE, -5)
	assert_eq(_collection.count_of(Element.FIRE), 0)

# --- the loan --------------------------------------------------------------

## The rule the whole difficulty curve rests on. Campaign.TARGETS were measured
## against exact bags, so a player must never be able to bring less than one.
func test_a_level_lends_up_to_its_reference_bag() -> void:
	var reference := bag([[Element.ICE, 4]])
	var available := _collection.available_counts(reference)
	assert_eq(int(available.get(Element.ICE, 0)), 4, "four Ice on loan")
	assert_eq(int(available.get(Element.NONE, 0)), 6, "and the six you own")

func test_the_loan_covers_only_what_you_lack() -> void:
	_collection.grant(Element.ICE, 3)
	var lent := _collection.lent_counts(bag([[Element.ICE, 4]]))
	assert_eq(int(lent.get(Element.ICE, 0)), 1, "you own three, so one is lent")

func test_nothing_is_lent_once_you_own_the_reference() -> void:
	_collection.grant(Element.ICE, 4)
	assert_true(_collection.lent_counts(bag([[Element.ICE, 4]])).is_empty(), "all yours")

func test_the_loan_never_takes_anything_away() -> void:
	# Six Fire owned, a level whose reference has none of them: the Fire stays.
	_collection.grant(Element.FIRE, 6)
	var available := _collection.available_counts(bag([[Element.ICE, 3]]))
	assert_eq(int(available.get(Element.FIRE, 0)), 6, "still six Fire")
	assert_eq(int(available.get(Element.ICE, 0)), 3, "plus the lent Ice")

## Stated as the guarantee itself: for every level of the campaign, whatever the
## player owns, they can always field at least the bag the target was measured
## against. If this ever fails, some level has become unwinnable.
func test_every_campaign_level_can_always_field_its_reference_bag() -> void:
	var campaign := Campaign.new()
	var empty := DiceCollection.new()
	for level in range(1, campaign.level_count + 1):
		var reference := campaign.reference_bag_for(level)
		var wanted := DiceCollection.required_counts(reference)
		var available := empty.available_counts(reference)
		for element in wanted:
			assert_true(
				int(available.get(element, 0)) >= int(wanted[element]),
				"level %d can field its %s" % [level, element]
			)

# --- building a bag --------------------------------------------------------

func test_a_loadout_becomes_a_bag_of_the_right_size() -> void:
	var elements : Array[StringName] = [
		Element.FIRE, Element.FIRE, Element.ICE, Element.NONE, Element.NONE, Element.NONE
	]
	var built := DiceCollection.build_bag(elements)
	assert_eq(built.size(), 6, "six dice")
	var tally := DiceCollection.count_bag(built)
	assert_eq(int(tally.get(Element.FIRE, 0)), 2, "two Fire")
	assert_eq(int(tally.get(Element.ICE, 0)), 1, "one Ice")

func test_a_built_bag_is_playable() -> void:
	var ruleset := Ruleset.new()
	ruleset.bag_definition = DiceCollection.build_bag(
		[Element.ICE, Element.ICE, Element.ICE, Element.FIRE, Element.FIRE, Element.FIRE]
	)
	var game := FarkleGame.new(ruleset, RngService.new(3))
	game.start()
	assert_eq(game.get_dice().size(), 6, "six dice on the table")
	assert_true(game.rules.has_trio(Element.ICE), "and the Ice trio is live")

# --- the floor at level start ----------------------------------------------

func loadout(elements : Array) -> BagDefinition:
	return DiceCollection.build_bag(elements)

func test_a_loadout_that_already_meets_the_reference_is_untouched() -> void:
	var chosen := loadout([Element.ICE, Element.ICE, Element.ICE,
		Element.FIRE, Element.FIRE, Element.FIRE])
	var played := DiceCollection.apply_floor(chosen, bag([[Element.ICE, 3]]))
	var tally := DiceCollection.count_bag(played)
	assert_eq(int(tally.get(Element.ICE, 0)), 3, "three Ice kept")
	assert_eq(int(tally.get(Element.FIRE, 0)), 3, "and the Fire build survives")

## The bug the playthrough probe caught: a loadout chosen at one checkpoint is
## carried through every level until the next, while the reference bags escalate
## behind it. Six plain dice picked on level 1 must not reach level 9's target.
func test_a_stale_loadout_is_raised_to_the_reference() -> void:
	var chosen := loadout([Element.NONE, Element.NONE, Element.NONE,
		Element.NONE, Element.NONE, Element.NONE])
	var played := DiceCollection.apply_floor(chosen, bag([[Element.ICE, 4]]))
	var tally := DiceCollection.count_bag(played)
	assert_eq(int(tally.get(Element.ICE, 0)), 4, "four Ice lent in")
	assert_eq(int(tally.get(Element.NONE, 0)), 2, "two plain dice evicted")

func test_the_floor_keeps_the_bag_at_six_dice() -> void:
	var chosen := loadout([Element.FIRE, Element.FIRE, Element.FIRE,
		Element.NONE, Element.NONE, Element.NONE])
	var played := DiceCollection.apply_floor(chosen, bag([[Element.ICE, 3]]))
	assert_eq(played.size(), 6, "still six")

## Plain dice are the ones the player has least invested in, so they go first.
func test_the_floor_evicts_plain_dice_before_a_build() -> void:
	var chosen := loadout([Element.FIRE, Element.FIRE, Element.FIRE,
		Element.FIRE, Element.NONE, Element.NONE])
	var played := DiceCollection.apply_floor(chosen, bag([[Element.ICE, 2]]))
	var tally := DiceCollection.count_bag(played)
	assert_eq(int(tally.get(Element.FIRE, 0)), 4, "the Fire trio is untouched")
	assert_eq(int(tally.get(Element.NONE, 0)), 0, "the plain dice went instead")

## The guarantee, stated over the whole campaign and every loadout a player could
## plausibly be carrying. If this fails, some level has become unwinnable.
func test_no_loadout_can_underequip_any_campaign_level() -> void:
	var campaign := Campaign.new()
	var candidates : Array[BagDefinition] = [
		loadout([Element.NONE, Element.NONE, Element.NONE,
			Element.NONE, Element.NONE, Element.NONE]),
		loadout([Element.SHADOW, Element.SHADOW, Element.SHADOW,
			Element.SHADOW, Element.SHADOW, Element.SHADOW]),
		loadout([Element.FIRE, Element.ICE, Element.LIGHTNING,
			Element.NATURE, Element.SHADOW, Element.CRYSTAL]),
	]
	for level in range(1, campaign.level_count + 1):
		var reference := campaign.reference_bag_for(level)
		var needed := DiceCollection.required_counts(reference)
		for candidate in candidates:
			var played := DiceCollection.apply_floor(candidate, reference)
			assert_eq(played.size(), 6, "level %d keeps six dice" % level)
			var tally := DiceCollection.count_bag(played)
			for element in needed:
				assert_true(
					int(tally.get(element, 0)) >= int(needed[element]),
					"level %d always fields its %s" % [level, element]
				)

# --- ordering --------------------------------------------------------------

## The loadout screen must not reshuffle itself between visits.
func test_owned_elements_come_back_in_a_stable_order() -> void:
	_collection.grant(Element.CRYSTAL, 1)
	_collection.grant(Element.FIRE, 1)
	var first := _collection.owned_elements()
	assert_eq(first[0], Element.NONE, "plain dice lead")
	assert_true(
		first.find(Element.FIRE) < first.find(Element.CRYSTAL),
		"then Element.ALL order, not insertion order"
	)
	assert_eq(_collection.owned_elements(), first, "and the same again")
