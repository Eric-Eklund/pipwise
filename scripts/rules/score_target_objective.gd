class_name ScoreTargetObjective
extends Objective
## Reach a score with the one hand the level gives you.

@export var target_score : int = 300

func is_met(context : GameContext) -> bool:
	return context.score >= target_score

func get_description() -> String:
	return "Reach %d points" % target_score

func get_progress_text(context : GameContext) -> String:
	return "%d / %d" % [context.score, target_score]
