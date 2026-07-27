class_name ScoreTargetObjective
extends Objective
## Bank a target score before the level runs out of turns.

@export var target_score : int = 1000

func is_met(context : GameContext) -> bool:
	return context.banked_score >= target_score

## Out of turns and short of the target. Checked against the banked score alone,
## because this is asked once the turn is already over and nothing is riding.
func is_failed(context : GameContext) -> bool:
	return not context.has_turns_left() and context.banked_score < target_score

func get_description() -> String:
	return "Bank %d points" % target_score

## The projected score rather than the banked one, so the readout answers the
## question the player is actually asking mid-turn: would banking now be enough?
func get_progress_value(context : GameContext) -> int:
	return context.projected_score()

func get_progress_goal() -> int:
	return target_score

func format_progress(value : int) -> String:
	return "%d / %d" % [value, target_score]

func get_progress_ratio(context : GameContext) -> float:
	if target_score <= 0:
		return 1.0
	return clampf(float(context.projected_score()) / float(target_score), 0.0, 1.0)
