class_name CategoryBonusModifier
extends LevelModifier
## Pays extra for particular hand shapes.
##
## The other half of Mirror Master: with the pair ruled out, the straight and
## the flush are worth chasing, and this is what makes chasing them pay. Sits
## apart from CategoryBanModifier so a level can have either without the other.

## PokerHandClassifier.Category values that earn the bonus.
@export var categories : Array[int] = []
## Added to the shape's multiplier as a fraction: 0.5 is "+50%".
@export_range(0.0, 3.0, 0.05) var bonus : float = 0.5

func on_level_start(context : GameContext) -> void:
	for category in categories:
		var current := float(context.category_bonuses.get(category, 0.0))
		context.category_bonuses[category] = current + bonus
