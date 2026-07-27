class_name MinimumBankModifier
extends LevelModifier
## Nothing may be banked until the turn is worth enough. Farkle's classic
## opening rule, used here as a boss twist that forces the player to push.
##
## Ruleset.minimum_bank does the same thing for an ordinary level. This exists
## so a boss can raise the bar without the number reading as part of the level's
## baseline, and so the banner has something to name.

@export_range(0, 5000) var minimum : int = 500

func can_bank(context : GameContext) -> bool:
	return context.turn_score >= minimum

func get_requirement_text(_context : GameContext) -> String:
	return "Reach %d to bank" % minimum
