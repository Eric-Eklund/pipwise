class_name StarterDice
extends RefCounted
## Factories for the die types the game ships with.
##
## Kept separate from DieType so the data classes stay free of concrete content.
## Once dice are authored as .tres files in the editor this becomes a fallback
## rather than the source of truth — which is what the shop will need, since
## buying a die means handing the level a different BagDefinition, not running
## different code.

## A plain six-sided die of [param element]: faces 1 through 6, uniform.
static func create_d6(element : StringName = Element.NONE, level : int = 1) -> DieType:
	var die := DieType.new()
	die.id = StringName("%s_d6" % element)
	die.element = element
	die.level = level
	var faces : Array[DieFace] = []
	for value in range(1, 7):
		faces.append(DieFace.create(StringName("pip_%d" % value), value, str(value)))
	die.faces = faces
	return die

## The elementless die the scoring table is balanced around.
static func create_basic_d6() -> DieType:
	return create_d6(Element.NONE)

## The dice the player owns at the start: six plain ones. Elements are earned
## rather than given, so the first levels teach the Farkle loop with nothing
## else going on.
static func create_starter_bag(count : int = 6) -> BagDefinition:
	var definition := BagDefinition.create_uniform(create_basic_d6(), count)
	definition.id = &"starter_bag"
	return definition

## A bag of [param count] dice, the first [param element_count] of them of
## [param element] and the rest plain. How the campaign introduces one element
## at a time without authoring a resource per level.
static func create_element_bag(
	element : StringName,
	element_count : int,
	count : int = 6,
	level : int = 1
) -> BagDefinition:
	var definition := BagDefinition.new()
	definition.id = StringName("%s_bag_%d" % [element, element_count])
	var elemental := create_d6(element, level)
	var plain := create_basic_d6()
	for i in count:
		definition.dice.append(elemental if i < element_count else plain)
	return definition

## One die of every element, in Element.ALL order. The design document's
## "Elemental Balanced" build, and the bag the mega combos will need.
static func create_rainbow_bag(level : int = 1) -> BagDefinition:
	var definition := BagDefinition.new()
	definition.id = &"rainbow_bag"
	for element in Element.ALL:
		definition.dice.append(create_d6(element, level))
	return definition
