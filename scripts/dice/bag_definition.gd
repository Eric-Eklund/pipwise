class_name BagDefinition
extends Resource
## The dice a bag starts with.
##
## The bag-building seam, mirroring DeckDefinition. A level points at one of
## these today; a progression system can hand over a modified copy later.

@export var id : StringName = &"starter_bag"
@export var dice : Array[DieType] = []

## Builds a bag holding [param count] copies of one die type.
static func create_uniform(die_type : DieType, count : int = 6) -> BagDefinition:
	var definition := BagDefinition.new()
	for _i in count:
		definition.dice.append(die_type)
	return definition

func size() -> int:
	return dice.size()
