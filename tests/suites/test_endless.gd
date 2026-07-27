extends TestCase
## Endless mode escalates without a ceiling. The campaign caps its target
## because a level the player cannot clear is a broken level; endless is the
## opposite, and how long it takes to outrun them is the score.

var _endless : EndlessRun

func before_each() -> void:
	_endless = EndlessRun.new()

func test_the_first_round_opens_at_the_base_target() -> void:
	assert_eq(_endless.target_for(1), _endless.base_target)

func test_the_target_never_stops_climbing() -> void:
	assert_true(_endless.target_for(50) > _endless.target_for(20), "no ceiling")
	assert_true(_endless.target_for(500) > _endless.target_for(50), "still none")

func test_turns_are_cut_as_the_rounds_go_on() -> void:
	assert_eq(_endless.turns_for(1), _endless.base_turns)
	assert_true(
		_endless.turns_for(1 + _endless.rounds_per_turn_cut) < _endless.base_turns,
		"a turn goes"
	)

func test_turns_never_fall_below_the_floor() -> void:
	assert_eq(_endless.turns_for(9999), _endless.minimum_turns, "a run stays playable")

func test_the_farkle_penalty_grows() -> void:
	assert_eq(_endless.penalty_for(1), _endless.base_penalty)
	assert_true(_endless.penalty_for(10) > _endless.penalty_for(1), "pushing costs more")

## What the player gets in exchange for the escalation is a bag worth playing
## with: two live trios from round one. Not the rainbow bag, which reaches no
## trio at all and would be the weakest thing in the game.
func test_every_round_hands_out_two_trios() -> void:
	var bag := _endless.get_ruleset(1).get_bag_definition()
	var counts : Dictionary = {}
	for die_type in bag.dice:
		counts[die_type.element] = int(counts.get(die_type.element, 0)) + 1
	assert_eq(int(counts.get(Element.ICE, 0)), 3, "three Ice")
	assert_eq(int(counts.get(Element.FIRE, 0)), 3, "three Fire")

func test_a_round_is_playable() -> void:
	for round_number in [1, 5, 20, 100]:
		var game := FarkleGame.new(
			_endless.get_ruleset(round_number), RngService.new(round_number + 1)
		)
		game.start()
		assert_eq(game.get_dice().size(), 6, "round %d has six dice" % round_number)

func test_a_round_carries_the_target_into_its_objective() -> void:
	var ruleset := _endless.get_ruleset(7)
	assert_eq(ruleset.get_target_score(), _endless.target_for(7), "the same number")
