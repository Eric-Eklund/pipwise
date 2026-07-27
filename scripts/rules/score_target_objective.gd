class_name ScoreTargetObjective
extends Objective
## Reach a score before the plays run out.

@export var target_score : int = 300

func is_met(context : GameContext) -> bool:
	return context.score >= target_score

func is_failed(context : GameContext) -> bool:
	return context.plays_left <= 0 and context.score < target_score

func get_description() -> String:
	return "Reach %d points" % target_score

func get_progress_text(context : GameContext) -> String:
	return "%d / %d" % [context.score, target_score]
