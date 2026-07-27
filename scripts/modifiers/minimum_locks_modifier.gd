class_name MinimumLocksModifier
extends LevelModifier
## Refuses to let the hand be saved until enough dice have been paid for.
##
## The Gambler. Forcing locks is a tax rather than a wall: at 4 energy each it
## takes the budget that would otherwise have bought card swaps, so the player
## has to win with a worse hand or a luckier roll.

@export_range(1, 6) var minimum : int = 2

func can_save_hand(context : GameContext) -> bool:
	return context.pool.locked_count() >= minimum

func get_requirement_text(context : GameContext) -> String:
	var short := minimum - context.pool.locked_count()
	if short <= 0:
		return ""
	return "Lock %d more %s" % [short, "die" if short == 1 else "dice"]
