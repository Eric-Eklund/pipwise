class_name StarterDice
extends RefCounted
## Factory for the starting die type.
##
## Kept separate from DieType so the data classes stay free of any concrete
## content. Once dice are authored as .tres files in the editor this becomes a
## fallback rather than the source of truth — which is what iteration 2's shop
## will need, since buying a die means handing the level a different
## BagDefinition, not running different code.

## The plain white d6 the whole game is balanced around: faces 1 through 6, each
## worth its own pips in white energy.
static func create_white_d6() -> DieType:
	var die := DieType.new()
	die.id = &"white_d6"
	var faces : Array[DieFace] = []
	for value in range(1, 7):
		faces.append(DieFace.create(StringName("pip_%d" % value), value, str(value)))
	die.faces = faces
	return die

## The dice the player owns at the start: six identical white ones.
static func create_starter_bag(count : int = 6) -> BagDefinition:
	var definition := BagDefinition.create_uniform(create_white_d6(), count)
	definition.id = &"starter_bag"
	return definition
