class_name FrozenDieModifier
extends LevelModifier
## Freezes dice so the player can neither keep them nor shake them off.
##
## The Frost King. A frozen die is worse than a bad die: it still counts towards
## the score and the energy, but it is dead weight the player cannot pay to fix.
## Freezing after the opening roll rather than before is deliberate — the player
## sees what they are stuck with.

@export_range(1, 6) var count : int = 1

func on_level_start(context : GameContext) -> void:
	context.pool.freeze_random(count)

func get_requirement_text(_context : GameContext) -> String:
	return ""
