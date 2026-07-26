class_name Hand
extends RefCounted
## The cards the player is holding, and which of them are picked to play.
##
## The hand owns no drawing logic — it is filled by whoever holds the Deck.
## That keeps the refill policy (draw to full, draw a fixed amount, draw
## nothing) a rule decision rather than something baked in here.

signal changed
signal selection_changed

var cards : Array[Card] = []
var max_size : int = 5

func _init(hand_size : int = 5) -> void:
	max_size = hand_size

func size() -> int:
	return cards.size()

func is_full() -> bool:
	return cards.size() >= max_size

## How many cards are needed to fill the hand back up.
func missing_count() -> int:
	return maxi(0, max_size - cards.size())

func add(new_cards : Array[Card]) -> void:
	if new_cards.is_empty():
		return
	cards.append_array(new_cards)
	changed.emit()

func remove(removed_cards : Array[Card]) -> void:
	var removed_any := false
	for card in removed_cards:
		var index := cards.find(card)
		if index >= 0:
			cards.remove_at(index)
			removed_any = true
	if removed_any:
		changed.emit()

## Removes and returns the selected cards, leaving the hand short by that many.
func take_selected() -> Array[Card]:
	var selected := get_selected()
	remove(selected)
	return selected

func get_selected() -> Array[Card]:
	var result : Array[Card] = []
	for card in cards:
		if card.is_selected:
			result.append(card)
	return result

func get_unselected() -> Array[Card]:
	var result : Array[Card] = []
	for card in cards:
		if not card.is_selected:
			result.append(card)
	return result

func get_unlocked() -> Array[Card]:
	var result : Array[Card] = []
	for card in cards:
		if not card.is_locked:
			result.append(card)
	return result

func selected_count() -> int:
	return get_selected().size()

func toggle_selection(card : Card) -> void:
	card.is_selected = not card.is_selected
	selection_changed.emit()

func clear_selection() -> void:
	for card in cards:
		card.is_selected = false
	selection_changed.emit()

func clear() -> void:
	cards.clear()
	changed.emit()
