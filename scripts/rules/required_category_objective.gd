class_name RequiredCategoryObjective
extends Objective
## Reach a score *and* do it with a particular shape or better.
##
## What the design spec's levels 21-30 ask for. Pairs a number with a demand,
## so the player cannot grind a high card into a win on a lucky roll.

## The PokerHandClassifier.Category the hand must reach. The enum is ordered
## weakest to strongest, so "or better" is a comparison.
@export var minimum_category : int = PokerHandClassifier.Category.PAIR
@export var target_score : int = 300

func is_met(context : GameContext) -> bool:
	return context.score >= target_score and context.current_category >= minimum_category

func get_description() -> String:
	return "Reach %d points with %s or better" % [
		target_score, PokerHandClassifier.category_name(minimum_category)
	]

## Just the numbers. The shape the level wants is already spelled out in
## get_description(), which the HUD prints directly above this, and repeating it
## here overflows the line the score is set in.
func get_progress_text(context : GameContext) -> String:
	return "%d / %d" % [context.score, target_score]
