class_name Campaign
extends Resource
## Builds the ruleset for any level of the campaign.
##
## Thirty levels are too many to author by hand and too few to leave to a bare
## formula, so this does both: it computes an ordinary level from a curve, and
## hands over an authored .tres when one exists. The boss levels are the
## authored ones. Dropping a level_N.tres into resources/rulesets/ overrides
## level N and needs no code change.
##
## The curve deliberately does *not* lean on a rising score target. The player's
## scoring power is fixed — no upgrades yet — so the spread of what a hand is
## worth is the same on level 30 as on level 1. Past roughly 155 points a higher
## target stops being difficult and starts being impossible. Difficulty
## therefore comes from taking resources away, which is also what the design
## spec's own progression table asks for from level 21 on.

const RULESET_DIR := "res://resources/rulesets"

@export_range(1, 200) var level_count : int = 30

@export_group("Score target")
## The target climbs gently across the whole campaign rather than steeply early.
@export var base_target : int = 68
@export var target_step : float = 3.0
## Above this a target is not hard, it is unreachable. Measured with
## tools/balance_probe.gd, not guessed.
@export var target_ceiling : int = 150

@export_group("Tightening")
## From this level on the player gets one reroll fewer, and from the second one
## fewer again.
@export var first_reroll_cut : int = 13
@export var second_reroll_cut : int = 23
## From this level on a number is not enough: the hand has to reach a shape.
@export var shape_demand_level : int = 21
## The shape demanded from that level on.
@export var demanded_category : int = PokerHandClassifier.Category.PAIR
## The last stretch asks for a harder shape instead of a bigger number, because
## by then the target has hit its ceiling and has nowhere left to go.
@export var hard_shape_level : int = 28
@export var hard_demanded_category : int = PokerHandClassifier.Category.TWO_PAIR
## From this level on the player rolls one die fewer, which cuts both the energy
## and the score.
@export var die_cut_level : int = 27

## Whether this level is a boss, answered by what the level actually is rather
## than by counting in fives. The design spec puts bosses on 5, 10, 15, 20 and
## 25 but not on 30, so an interval would claim a boss that does not exist.
func is_boss(level : int) -> bool:
	return not get_ruleset(level).boss_name.is_empty()

## The authored ruleset for [param level] if there is one, otherwise a computed
## ordinary level. Never returns null.
func get_ruleset(level : int) -> Ruleset:
	var authored := "%s/level_%d.tres" % [RULESET_DIR, level]
	if ResourceLoader.exists(authored):
		var ruleset : Ruleset = load(authored)
		if ruleset != null:
			return ruleset
	return build_ruleset(level)

func target_for(level : int) -> int:
	return mini(target_ceiling, base_target + int(round(level * target_step)))

func rerolls_for(level : int) -> int:
	var rerolls := 3
	if level >= first_reroll_cut:
		rerolls -= 1
	if level >= second_reroll_cut:
		rerolls -= 1
	return rerolls

func dice_for(level : int) -> int:
	return 5 if level >= die_cut_level else 6

## An ordinary level. Bosses come from files, so nothing here knows about them.
func build_ruleset(level : int) -> Ruleset:
	var ruleset := Ruleset.new()
	ruleset.id = StringName("level_%d" % level)
	ruleset.hand_size = 5
	ruleset.dice_count = dice_for(level)
	ruleset.max_rerolls = rerolls_for(level)
	ruleset.card_swap_cost = 3
	ruleset.die_lock_cost = 4
	ruleset.evaluator = PokerHandEvaluator.new()
	ruleset.objective = _objective_for(level)
	return ruleset

## The shape a level demands, or -1 when it only asks for a number.
func demand_for(level : int) -> int:
	if level >= hard_shape_level:
		return hard_demanded_category
	if level >= shape_demand_level:
		return demanded_category
	return -1

func _objective_for(level : int) -> Objective:
	var demand := demand_for(level)
	if demand < 0:
		var simple := ScoreTargetObjective.new()
		simple.target_score = target_for(level)
		return simple
	var demanding := RequiredCategoryObjective.new()
	demanding.target_score = target_for(level)
	demanding.minimum_category = demand
	return demanding
