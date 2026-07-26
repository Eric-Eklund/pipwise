class_name DeckDefinition
extends Resource
## The cards a deck starts with.
##
## This is the deck-building seam. A level points at one of these today; a
## future progression system can hand the player a modified copy instead,
## without the engine knowing the difference.

@export var id : StringName = &"standard_52"
@export var cards : Array[CardData] = []

## Builds a standard 52-card deck: ace through king in all four suits.
## Cheaper and less error-prone than authoring 52 .tres files by hand.
static func create_standard_52() -> DeckDefinition:
	var definition := DeckDefinition.new()
	definition.id = &"standard_52"
	for suit in CardData.SUITS:
		for rank in range(1, 14):
			definition.cards.append(CardData.create(rank, suit))
	return definition

func size() -> int:
	return cards.size()
