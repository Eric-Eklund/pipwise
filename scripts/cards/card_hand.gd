class_name CardHand
extends RefCounted
## The cards the player is holding and the deck they come off.
##
## RefCounted rather than a Resource, because this is runtime state: it is
## rebuilt from RunState's saved ids at the start of every level and written back
## when it changes. RunState stays what it is — a small bag of exported values
## with no behaviour in it — and the drawing lives here where a test can reach it
## without a scene.
##
## ## Ids, not resources
##
## Everything in here is a StringName that CardLibrary can look up. That is the
## same shape GameState.loadout already uses for dice, and it is what lets a hand
## survive a save without serialising a pile of sub-resources into the save file.
##
## ## The deck does not run out
##
## Drawing from an empty deck reshuffles the whole library rather than failing.
## Section 3.7 describes draws and never describes exhaustion, and a run that
## silently stops paying cards at level 6 would look like a bug to the only
## person who could report it.

## How many cards the player may hold. Not in the design document; it is the
## width of a 540px row divided by a thumb.
const MAX_HAND := 5

## What the player is holding, as card ids.
var hand : Array[StringName] = []
## What is left to draw from, in order. The top of the deck is the front.
var deck : Array[StringName] = []

var _rng : RngService

func _init(rng : RngService = null) -> void:
	_rng = rng if rng != null else RngService.new()

## A fresh hand for a new run: a shuffled deck and section 3.7's opening five.
static func create(rng : RngService, opening_draw : int = 5) -> CardHand:
	var card_hand := CardHand.new(rng)
	card_hand.deck = CardLibrary.build_deck(rng)
	card_hand.draw(opening_draw)
	return card_hand

## Rebuilds a hand from what RunState saved. The deck is restored as it was
## rather than reshuffled, so quitting between levels does not reroll the run's
## future — which is the one thing a player would notice and call cheating.
static func restore(saved_hand : Array, saved_deck : Array, rng : RngService) -> CardHand:
	var card_hand := CardHand.new(rng)
	for id in saved_hand:
		card_hand.hand.append(StringName(id))
	for id in saved_deck:
		card_hand.deck.append(StringName(id))
	if card_hand.deck.is_empty():
		card_hand.deck = CardLibrary.build_deck(rng)
	return card_hand

# --- drawing ---------------------------------------------------------------

## Draws up to [param count] cards, stopping at MAX_HAND. Returns what was
## actually drawn, so the level can say "drew 2" and mean it.
func draw(count : int) -> Array[StringName]:
	var drawn : Array[StringName] = []
	for _i in count:
		if is_full():
			break
		if deck.is_empty() and not _refill():
			break
		var id : StringName = deck.pop_front()
		hand.append(id)
		drawn.append(id)
	return drawn

## Shuffles a fresh deck in when the old one is spent. Returns whether there is
## anything to draw afterwards.
func _refill() -> bool:
	deck = CardLibrary.build_deck(_rng)
	return not deck.is_empty()

# --- playing ---------------------------------------------------------------

func holds(id : StringName) -> bool:
	return id in hand

func size() -> int:
	return hand.size()

func is_full() -> bool:
	return hand.size() >= MAX_HAND

## The Card resources the player is holding, in hand order. Null ids are skipped
## rather than crashing the row: an id from an older save whose card has since
## been renamed is a card that no longer exists, not a reason to lose the run.
func get_cards() -> Array[Card]:
	var cards : Array[Card] = []
	for id in hand:
		var card := CardLibrary.by_id(id)
		if card != null:
			cards.append(card)
	return cards

## Removes one copy of [param id] from the hand. Returns whether it was there.
func discard(id : StringName) -> bool:
	var index := hand.find(id)
	if index < 0:
		return false
	hand.remove_at(index)
	return true
