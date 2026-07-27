class_name EndlessRun
extends Resource
## Builds the ruleset for round N of endless mode, escalating without limit.
##
## The campaign teaches; endless does not. It is meant to outrun the player
## eventually, and how long that takes is the score. So the target climbs
## without a ceiling, the turns shrink, and the Farkle penalty grows.
##
## What the player gets in exchange is dice: a rainbow bag from the start, so
## every element rule is live and a run is about finding the combo the rolls are
## offering rather than the one the level handed out.

@export_group("Score target")
@export var base_target : int = 800
## Added per round. Steep enough that a run ends in minutes, not hours.
@export var target_step : float = 320.0

@export_group("Turns")
@export_range(1, 30) var base_turns : int = 5
## A turn goes every this many rounds, down to the floor.
@export_range(1, 50) var rounds_per_turn_cut : int = 4
@export_range(1, 10) var minimum_turns : int = 2

@export_group("Farkle")
@export var base_penalty : int = 100
## Added to the penalty per round, so pushing gets steadily more expensive.
@export var penalty_step : int = 40

func target_for(round_number : int) -> int:
	return base_target + int(round(maxi(0, round_number - 1) * target_step))

func turns_for(round_number : int) -> int:
	var cuts := maxi(0, round_number - 1) / rounds_per_turn_cut
	return maxi(minimum_turns, base_turns - cuts)

func penalty_for(round_number : int) -> int:
	return base_penalty + maxi(0, round_number - 1) * penalty_step

func get_ruleset(round_number : int) -> Ruleset:
	var ruleset := Ruleset.new()
	ruleset.id = StringName("endless_%d" % round_number)
	ruleset.bag_definition = StarterDice.create_rainbow_bag()
	ruleset.turns = turns_for(round_number)
	ruleset.farkle_penalty = penalty_for(round_number)

	var objective := ScoreTargetObjective.new()
	objective.target_score = target_for(round_number)
	ruleset.objective = objective
	return ruleset
