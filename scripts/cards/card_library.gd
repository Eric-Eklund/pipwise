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
## same reason: seven .tres files that differ by four fields are seven chances
## for one of them to be wrong, and none of these need an artist.
## `resources/cards/` remains free for a card that turns out to need more than
## this.
##
## ## Seven cards, and why they are these seven
##
## This replaced the ten scrolls and potions the first pass transcribed out of
## section 3 of docs/DESIGN.md. Those were an element system bolted onto a card
## system: five of them were "double what your element pays", which is a number
## the player cannot see moving, on a board that has to be carrying the right
## element before the card does anything at all. A hand of them read as a hand
## of cards that did nothing.
##
## These seven are the base set: one thing each, visible the moment it is
## played, and none of them needing an element to be on the table. Between them
## they touch every part of a turn — the dice on it, what a selection is worth,
## what a bust costs, and what the buttons will let you do — which is what makes
## them a set rather than a list. See deviation 8 of docs/DESIGN.md.

# --- ids -------------------------------------------------------------------

const EXTRA_DIE : StringName = &"extra_die"
const SCORE_BOOST : StringName = &"score_boost"
const VALUE_SHIFT : StringName = &"value_shift"
const LOCK_ALL : StringName = &"lock_all"
const VALUE_CONVERTER : StringName = &"value_converter"
const FARKLE_SHIELD : StringName = &"farkle_shield"
const FORCED_REROLL : StringName = &"forced_reroll"

## The order everything is listed in: cheapest first, which is roughly the order
## a new player will understand them in. Fixed rather than the dictionary's own
## key order, so a seeded deck cannot depend on insertion details.
const ORDER : Array[StringName] = [
	LOCK_ALL, EXTRA_DIE, SCORE_BOOST, VALUE_CONVERTER,
	VALUE_SHIFT, FORCED_REROLL, FARKLE_SHIELD,
]

## Copies of each card in a deck. Seven kinds at three copies is twenty-one, and
## a whole campaign draws about twenty-three — so the deck is reshuffled once in
## a long run and the player sees every card more than once in a short one.
const COPIES_PER_CARD := 3

## Built once and shared. Cards carry no per-play state, so one instance of each
## can safely be handed to every hand in the game.
static var _cards : Dictionary = {}

# --- lookups ---------------------------------------------------------------

## Every card, in ORDER.
static func all() -> Array[Card]:
	_build()
	var result : Array[Card] = []
	for id in ORDER:
		result.append(_cards[id])
	return result

static func by_id(id : StringName) -> Card:
	_build()
	return _cards.get(id, null)

# --- decks -----------------------------------------------------------------

## A shuffled deck. Shuffled through [param rng] rather than Array.shuffle(),
## which cannot be seeded per instance — a fixed seed has to reproduce a whole
## run, cards included.
static func build_deck(rng : RngService) -> Array[StringName]:
	var deck : Array[StringName] = []
	for card in all():
		for _copy in COPIES_PER_CARD:
			deck.append(card.id)
	rng.shuffle(deck)
	return deck

# --- the cards themselves --------------------------------------------------

static func _build() -> void:
	if not _cards.is_empty():
		return

	_add(_card(LockAllCard.new(), LOCK_ALL, "🔒", "Lock All",
		"Sets aside every die worth taking and banks their points into the turn.",
		2, Color(0.55, 0.78, 0.98)))

	_add(_card(ExtraDieCard.new(), EXTRA_DIE, "🎲", "Extra Die",
		"Rolls one more die onto the table for the rest of the turn.",
		3, Color(0.98, 0.85, 0.42)))

	var boost := _card(ScoreBoostCard.new(), SCORE_BOOST, "✨", "Score Boost",
		"Matched sets pay +50% until you roll again.",
		4, Color(0.72, 0.50, 0.95))
	boost.duration = Card.Duration.ROLL
	_add(boost)

	_add(_card(ValueConverterCard.new(), VALUE_CONVERTER, "🔁", "Value Converter",
		"Turns a die that scores nothing into a 1 or a 5. Which one is the dice's call.",
		4, Color(0.45, 0.82, 0.60)))

	_add(_card(ValueShiftCard.new(), VALUE_SHIFT, "↕", "Value Shift",
		"Moves one die a single pip, up or down.",
		5, Color(0.40, 0.78, 0.76)))

	var reroll := _card(ForcedRerollCard.new(), FORCED_REROLL, "🎯", "Forced Reroll",
		"Roll again with nothing set aside — but you cannot bank until you do.",
		5, Color(0.95, 0.55, 0.35))
	reroll.duration = Card.Duration.ROLL
	_add(reroll)

	var shield := _card(FarkleShieldCard.new(), FARKLE_SHIELD, "🛡", "Farkle Shield",
		"The next Farkle costs you nothing — the turn's points are safe.",
		6, Color(0.90, 0.44, 0.36))
	shield.duration = Card.Duration.TURN
	_add(shield)

static func _card(card : Card, id : StringName, icon : String, name : String,
		description : String, cost : int, color : Color) -> Card:
	card.id = id
	card.icon = icon
	card.display_name = name
	card.description = description
	card.energy_cost = cost
	card.color = color
	return card

static func _add(card : Card) -> void:
	_cards[card.id] = card
