class_name ScoreMultiplierAction
extends DieAction
## Raises the multiplier applied to the next scored hand.
##
## The multiplier only has teeth once scoring lands in M5; until then the
## action is still valid, it just has nothing to multiply.

@export_range(0.1, 5.0, 0.1) var bonus : float = 0.5

func apply(context : GameContext) -> void:
	context.score_multiplier += bonus
