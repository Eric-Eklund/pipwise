class_name DiceCollection
extends Resource
## The dice the player owns, across runs.
##
## The one thing that survives a death. Everything else about a run — which
## level, what was banked, how many Farkles — is thrown away; this is not, and
## that is the whole of the meta-progression.
##
## ## Keyed by element, not by die type
##
## A save file that reads `{"fire": 2}` is one anybody can debug; one that reads
## `{"fire_d6@1": 2}` is not, and the level dimension does not exist yet — every
## die is level 1. When per-die levelling arrives the key becomes
## "element@level" and this class grows a parser; nothing else has to change,
## because nothing else looks inside the dictionary.

## Element to how many of them are owned. Element.NONE is the plain die.
@export var counts : Dictionary = {}

func _init() -> void:
	# Assigned here rather than left to the property default, so two collections
	# can never end up sharing one dictionary.
	counts = {}

## What a new player starts with: six plain dice and nothing else. Elements are
## earned, which is the point.
static func create_starting() -> DiceCollection:
	var collection := DiceCollection.new()
	collection.counts[Element.NONE] = 6
	return collection

func count_of(element : StringName) -> int:
	return int(counts.get(element, 0))

func owns(element : StringName, amount : int = 1) -> bool:
	return count_of(element) >= amount

func total() -> int:
	var sum := 0
	for element in counts:
		sum += int(counts[element])
	return sum

## The elements owned, in Element.ALL order with the plain die first. Sorted so
## the loadout screen never reshuffles itself between visits.
func owned_elements() -> Array[StringName]:
	var result : Array[StringName] = []
	if count_of(Element.NONE) > 0:
		result.append(Element.NONE)
	for element in Element.ALL:
		if count_of(element) > 0:
			result.append(element)
	return result

# --- granting --------------------------------------------------------------

func grant(element : StringName, amount : int = 1) -> void:
	if amount <= 0:
		return
	counts[element] = count_of(element) + amount

## Tops the collection up so it holds at least as many of each element as
## [param bag] does, and returns what that took as element to how many.
##
## This is what clearing a level pays. Topping up rather than adding means
## clearing level 3 twice does not hand out four Fire dice — the reward is
## reaching a level for the first time, not grinding it.
func grant_up_to(bag : BagDefinition) -> Dictionary:
	var wanted := count_bag(bag)
	var granted : Dictionary = {}
	for element in wanted:
		var missing := int(wanted[element]) - count_of(element)
		if missing > 0:
			grant(element, missing)
			granted[element] = missing
	return granted

# --- lending ---------------------------------------------------------------

## How many of each element the player may bring to a level whose measured
## target assumed [param reference].
##
## The union, not the collection: whatever the player owns, plus enough of the
## reference bag to match it. Campaign.TARGETS were measured against those exact
## bags — level 9 asks 13000 of four Ice dice — so without this floor a player
## could equip themselves into a level that is arithmetically unwinnable and
## never understand why. With it, nobody can ever be under-equipped, only better
## equipped.
func available_counts(reference : BagDefinition) -> Dictionary:
	var wanted := count_bag(reference)
	var available := counts.duplicate()
	for element in wanted:
		if int(available.get(element, 0)) < int(wanted[element]):
			available[element] = int(wanted[element])
	return available

## How many of each element are on loan rather than owned — what the loadout
## screen marks as borrowed. Empty once the player owns the whole reference bag.
func lent_counts(reference : BagDefinition) -> Dictionary:
	var wanted := count_bag(reference)
	var lent : Dictionary = {}
	for element in wanted:
		var missing := int(wanted[element]) - count_of(element)
		if missing > 0:
			lent[element] = missing
	return lent

# --- helpers ---------------------------------------------------------------

## What a reference bag actually *requires*, which is its elements and not its
## plain dice.
##
## A reference bag is padded out to six with plain dice — three Ice and three
## plain, say — but those three plain are filler, not a demand. Treating them as
## one would mean "you must bring three weak dice", which would make an all
## element build illegal and is the opposite of what the floor is for. A plain
## die contributes nothing but its face, so swapping one for any elemental die
## can only help.
static func required_counts(reference : BagDefinition) -> Dictionary:
	var required := count_bag(reference)
	required.erase(Element.NONE)
	return required

## Element to how many of it a bag holds.
static func count_bag(bag : BagDefinition) -> Dictionary:
	var tally : Dictionary = {}
	if bag == null:
		return tally
	for die_type in bag.dice:
		tally[die_type.element] = int(tally.get(die_type.element, 0)) + 1
	return tally

## Turns a chosen list of elements into the bag a level is played with.
static func build_bag(elements : Array, id : StringName = &"loadout") -> BagDefinition:
	var bag := BagDefinition.new()
	bag.id = id
	for element in elements:
		bag.dice.append(StarterDice.create_d6(element))
	return bag

## Raises [param loadout] until it holds at least as many of each element as
## [param reference] does, evicting whatever the player had most to spare.
##
## This is where the loan is actually enforced, and it has to be here rather than
## only on the loadout screen. A loadout is chosen at a checkpoint and then
## carried through every level until the next one, while the reference bags keep
## escalating behind it — so six plain dice picked on level 1 would otherwise
## walk into level 9's target of 13000, which four Ice dice were measured
## against. That is not a hard level; it is an arithmetically impossible one, and
## the player would have no way to see why.
##
## Eviction takes from the elements furthest above what this level needs, plain
## dice first, so the player keeps as much of their own build as the six slots
## allow.
static func apply_floor(loadout : BagDefinition, reference : BagDefinition) -> BagDefinition:
	if loadout == null:
		return reference
	var needed := required_counts(reference)
	var have := count_bag(loadout)

	var missing : Dictionary = {}
	var slots_wanted := 0
	for element in needed:
		var short := int(needed[element]) - int(have.get(element, 0))
		if short > 0:
			missing[element] = short
			slots_wanted += short
	if slots_wanted == 0:
		return loadout

	for element in _eviction_order(have, needed):
		if slots_wanted <= 0:
			break
		# Never evict below what this level needs of that element, or freeing a
		# slot for one shortfall would open another.
		var spare := mini(int(have[element]) - int(needed.get(element, 0)), slots_wanted)
		if spare <= 0:
			continue
		have[element] = int(have[element]) - spare
		slots_wanted -= spare

	for element in missing:
		have[element] = int(have.get(element, 0)) + int(missing[element])

	var elements : Array[StringName] = []
	for element in have:
		for _i in int(have[element]):
			elements.append(element)
	return build_bag(elements, loadout.id)

## Which dice to give up first: plain ones, then whatever is furthest above what
## the level asks of it. Ties break in Element.ALL order so a seeded run stays
## reproducible.
static func _eviction_order(have : Dictionary, needed : Dictionary) -> Array[StringName]:
	var order : Array[StringName] = []
	if int(have.get(Element.NONE, 0)) > 0:
		order.append(Element.NONE)
	var elements : Array[StringName] = []
	for element in Element.ALL:
		if int(have.get(element, 0)) > 0:
			elements.append(element)
	elements.sort_custom(func(first : StringName, second : StringName) -> bool:
		var first_spare := int(have[first]) - int(needed.get(first, 0))
		var second_spare := int(have[second]) - int(needed.get(second, 0))
		if first_spare == second_spare:
			return Element.ALL.find(first) < Element.ALL.find(second)
		return first_spare > second_spare
	)
	order.append_array(elements)
	return order
