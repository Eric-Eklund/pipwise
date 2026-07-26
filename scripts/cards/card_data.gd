class_name CardData
extends Resource
## The identity of a single card: what it is, not what state it is in.
##
## Runtime state (selected, locked) lives on Card instead, so the same
## CardData resource can back many cards without them sharing state.

const CLUBS : StringName = &"clubs"
const DIAMONDS : StringName = &"diamonds"
const HEARTS : StringName = &"hearts"
const SPADES : StringName = &"spades"

const SUITS : Array[StringName] = [CLUBS, DIAMONDS, HEARTS, SPADES]

const SUIT_SYMBOLS : Dictionary = {
	CLUBS: "♣",
	DIAMONDS: "♦",
	HEARTS: "♥",
	SPADES: "♠",
}

## Suits that read as red. Used by the view layer only.
const RED_SUITS : Array[StringName] = [DIAMONDS, HEARTS]

const RANK_NAMES : Dictionary = {
	1: "A", 11: "J", 12: "Q", 13: "K",
}

## 1 (Ace) through 13 (King).
@export_range(1, 13) var rank : int = 1
@export var suit : StringName = SPADES
## Free-form markers rules can match on, so special cards need no schema change.
@export var tags : Array[StringName] = []

static func create(card_rank : int, card_suit : StringName) -> CardData:
	var card := CardData.new()
	card.rank = card_rank
	card.suit = card_suit
	return card

## Stable identity, e.g. &"hearts_12".
func get_id() -> StringName:
	return StringName("%s_%d" % [suit, rank])

## Short label for the card face, e.g. "Q♥".
func get_display_name() -> String:
	return get_rank_name() + get_suit_symbol()

func get_rank_name() -> String:
	return String(RANK_NAMES.get(rank, str(rank)))

func get_suit_symbol() -> String:
	return String(SUIT_SYMBOLS.get(suit, "?"))

func is_red() -> bool:
	return suit in RED_SUITS

func has_tag(tag : StringName) -> bool:
	return tag in tags
