class_name CardLibrary
extends RefCounted
## Every card that exists, and where a deck comes from.
##
## Pure data and static lookups, the same shape as Element and MegaCombo. A view
## needs a card's name and colour without holding a game, and a saved hand is a
## list of ids that has to turn back into cards — both of those want a lookup
## that no instance owns.
##
## ## Why the cards are built here rather than authored as .tres
##
## Every die in the game is built by StarterDice rather than authored, for the
## same reason: ten .tres files that differ by two fields are ten chances for one
## of them to be wrong, and none of these need an artist. `resources/cards/`
## remains free for a card that turns out to need more than this.
##
## ## What is missing, and why
##
## Section 3 lists 28 cards across five rarities. This is the common and uncommon
## slice — Scrolls and Potions — and seven of the document's cards are not here
## at all because they do nothing in this build: rerolls are already free and
## unlimited, there is no currency, and death costs no items. The full accounting
## is in the deviations section of docs/DESIGN.md.

# --- ids -------------------------------------------------------------------

const EXTRA_DIE : StringName = &"extra_die"
const SHIELD : StringName = &"shield"
const DRAW_TWO : StringName = &"draw_two"
const DISCARD_SWAP : StringName = &"discard_swap"

const FIRE_BREW : StringName = &"fire_brew"
const FROST_SHIELD : StringName = &"frost_shield"
const STORM_CALL : StringName = &"storm_call"
const CRYSTAL_FOCUS : StringName = &"crystal_focus"
const EARTH_RESTORE : StringName = &"earth_restore"
const SHADOW_VEIL : StringName = &"shadow_veil"

## How many copies of each rarity go into a deck. Section 3.7 gives draw odds as
## percentages — 60% common, 25% uncommon — and a weighted deck is the same thing
## said in a way that cannot deal the same card six times in a row.
const COPIES_PER_RARITY : Dictionary = {
	Card.Rarity.COMMON: 3,
	Card.Rarity.UNCOMMON: 1,
}

## Built once and shared. Cards carry no per-play state, so one instance of each
## can safely be handed to every hand in the game.
static var _cards : Dictionary = {}

# --- lookups ---------------------------------------------------------------

## Every card, in a fixed order. Not the dictionary's own order, which would make
## a seeded deck depend on insertion details.
static func all() -> Array[Card]:
	_build()
	var result : Array[Card] = []
	for id in ORDER:
		result.append(_cards[id])
	return result

static func by_id(id : StringName) -> Card:
	_build()
	return _cards.get(id, null)

static func by_rarity(rarity : Card.Rarity) -> Array[Card]:
	var result : Array[Card] = []
	for card in all():
		if card.rarity == rarity:
			result.append(card)
	return result

## The order everything is listed in: scrolls before potions, and the potions in
## Element.ALL order so the guide and the deck agree with the rest of the game.
const ORDER : Array[StringName] = [
	EXTRA_DIE, SHIELD, DRAW_TWO, DISCARD_SWAP,
	FIRE_BREW, FROST_SHIELD, STORM_CALL, EARTH_RESTORE, SHADOW_VEIL, CRYSTAL_FOCUS,
]

# --- decks -----------------------------------------------------------------

## A shuffled deck, weighted by rarity. Shuffled through [param rng] rather than
## Array.shuffle(), which cannot be seeded per instance — a fixed seed has to
## reproduce a whole run, cards included.
static func build_deck(rng : RngService) -> Array[StringName]:
	var deck : Array[StringName] = []
	for card in all():
		for _copy in int(COPIES_PER_RARITY.get(card.rarity, 1)):
			deck.append(card.id)
	rng.shuffle(deck)
	return deck

# --- the cards themselves --------------------------------------------------

static func _build() -> void:
	if not _cards.is_empty():
		return

	_add(_scroll(ExtraDieCard.new(), EXTRA_DIE, "Extra Die",
		"One die comes back to the table.", 3))
	_add(_scroll(ShieldCard.new(), SHIELD, "Shield",
		"A Farkle costs you nothing this turn.", 5))
	_add(_scroll(DrawCard.new(), DRAW_TWO, "Draw 2",
		"Draw two more cards.", 3))
	_add(_scroll(DiscardSwapCard.new(), DISCARD_SWAP, "Discard Swap",
		"Throw the hand away and draw it again.", 4))

	_add(_boost(FIRE_BREW, "Fire Brew", Element.FIRE, 5))
	_add(_boost(FROST_SHIELD, "Frost Shield", Element.ICE, 6))
	_add(_boost(STORM_CALL, "Storm Call", Element.LIGHTNING, 7))
	_add(_boost(CRYSTAL_FOCUS, "Crystal Focus", Element.CRYSTAL, 8))

	var restore := NatureRestoreCard.new()
	_add(_potion(restore, EARTH_RESTORE, "Earth Restore", Element.NATURE,
		"Nature hands back one more die.", 5))
	var veil := ShadowVeilCard.new()
	_add(_potion(veil, SHADOW_VEIL, "Shadow Veil", Element.SHADOW,
		"A Farkle pays you this turn.", 6))

static func _scroll(card : Card, id : StringName, name : String,
		description : String, cost : int) -> Card:
	card.id = id
	card.display_name = name
	card.description = description
	card.rarity = Card.Rarity.COMMON
	card.energy_cost = cost
	return card

static func _potion(card : Card, id : StringName, name : String,
		element : StringName, description : String, cost : int) -> Card:
	card.id = id
	card.display_name = name
	card.description = description
	card.element = element
	card.rarity = Card.Rarity.UNCOMMON
	card.energy_cost = cost
	return card

## The four potions whose whole effect is doubling their element's bonus.
static func _boost(id : StringName, name : String, element : StringName, cost : int) -> Card:
	var card := ElementBoostCard.new()
	return _potion(card, id, name, element,
		"%s dice pay double their bonus this turn." % Element.get_display_name(element), cost)

static func _add(card : Card) -> void:
	_cards[card.id] = card
