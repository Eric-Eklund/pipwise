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

## A bag built from [param spec], a list of [element, count] pairs, padded out
## to [param count] with plain dice. Two elements at three dice each is the
## interesting case: both trios fire, and the player has to choose which one to
## chase on any given roll.
static func create_mixed_bag(spec : Array, count : int = 6, level : int = 1) -> BagDefinition:
	var definition := BagDefinition.new()
	var parts : Array[String] = []
	for entry in spec:
		var element : StringName = entry[0]
		parts.append(String(element))
		for _i in int(entry[1]):
			if definition.dice.size() < count:
				definition.dice.append(create_d6(element, level))
	while definition.dice.size() < count:
		definition.dice.append(create_basic_d6())
	definition.id = StringName("mixed_%s" % "_".join(parts))
	return definition

## One die of every element, in Element.ALL order. The design document's
## "Elemental Balanced" build.
##
## Weak in the MVP, and knowingly unused by the campaign because of it: with one
## die per element nothing reaches a trio and nothing repeats, so the section
## 2.1 combo ladder never leaves x1. The build only works once the section 2.3
## mega combos exist, which is what Elemental Master is for.
static func create_rainbow_bag(level : int = 1) -> BagDefinition:
	var definition := BagDefinition.new()
	definition.id = &"rainbow_bag"
	for element in Element.ALL:
		definition.dice.append(create_d6(element, level))
	return definition
