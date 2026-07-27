class_name EndlessRun
extends Resource
## Builds the ruleset for round N of endless mode, escalating without limit.
##
## The campaign caps its target because a level the player cannot clear is a
## broken level. Endless is the opposite: the target is *meant* to outrun them
## eventually, and how long that takes is the score. So there is no ceiling
## here, and the resource cuts keep coming.
##
## Rounds are one hand each, exactly like a campaign level. What carries over
## between them is the running total, which the endless level owns.

@export_group("Score target")
@export var base_target : int = 80
## Added per round. Steep enough that a run ends in minutes, not hours.
@export var target_step : float = 12.0

@export_group("Tightening")
## A reroll goes every this many rounds, down to the floor.
@export_range(1, 50) var rounds_per_reroll_cut : int = 8
@export_range(1, 6) var minimum_rerolls : int = 1
## A die goes every this many rounds, down to the floor.
@export_range(1, 50) var rounds_per_die_cut : int = 12
@export_range(1, 6) var minimum_dice : int = 3

@export_group("Shape demands")
@export var pair_from_round : int = 10
@export var two_pair_from_round : int = 20

func target_for(round_number : int) -> int:
	return base_target + int(round(maxi(0, round_number - 1) * target_step))

func rerolls_for(round_number : int) -> int:
	var cuts := maxi(0, round_number - 1) / rounds_per_reroll_cut
	return maxi(minimum_rerolls, 3 - cuts)

func dice_for(round_number : int) -> int:
	var cuts := maxi(0, round_number - 1) / rounds_per_die_cut
	return maxi(minimum_dice, 6 - cuts)

## The shape this round demands, or -1 when a number is enough.
func demand_for(round_number : int) -> int:
	if round_number >= two_pair_from_round:
		return PokerHandClassifier.Category.TWO_PAIR
	if round_number >= pair_from_round:
		return PokerHandClassifier.Category.PAIR
	return -1

func get_ruleset(round_number : int) -> Ruleset:
	var ruleset := Ruleset.new()
	ruleset.id = StringName("endless_%d" % round_number)
	ruleset.hand_size = 5
	ruleset.dice_count = dice_for(round_number)
	ruleset.max_rerolls = rerolls_for(round_number)
	ruleset.card_swap_cost = 3
	ruleset.die_lock_cost = 4
	ruleset.evaluator = PokerHandEvaluator.new()

	var demand := demand_for(round_number)
	if demand < 0:
		var simple := ScoreTargetObjective.new()
		simple.target_score = target_for(round_number)
		ruleset.objective = simple
	else:
		var demanding := RequiredCategoryObjective.new()
		demanding.target_score = target_for(round_number)
		demanding.minimum_category = demand
		ruleset.objective = demanding
	return ruleset
