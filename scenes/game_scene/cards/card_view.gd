class_name CardView
extends Button
## Placeholder card face: rank and suit drawn as text.
##
## A pure view. It reads a Card and reports presses; it never touches rules.
## Swapping in real art means giving this node a texture per card id — nothing
## under scripts/cards/ changes.

signal card_pressed(card : Card)

const RED_INK := Color(0.83, 0.18, 0.24)
const BLACK_INK := Color(0.11, 0.12, 0.15)
const SELECTED_SCALE := Vector2(1.06, 1.06)
const SELECTED_TINT := Color(1.0, 0.94, 0.72)

var card : Card

@onready var _rank_label : Label = %RankLabel
@onready var _suit_label : Label = %SuitLabel

func _ready() -> void:
	# Scale around the card's own centre so selection does not shift the row.
	pivot_offset = size / 2.0
	resized.connect(func() -> void: pivot_offset = size / 2.0)
	pressed.connect(_on_pressed)
	_refresh()

func set_card(new_card : Card) -> void:
	card = new_card
	if is_node_ready():
		_refresh()

## Called by HandView when selection changes without the hand being rebuilt.
func refresh_selection() -> void:
	if not is_node_ready():
		return
	var selected := card != null and card.is_selected
	scale = SELECTED_SCALE if selected else Vector2.ONE
	self_modulate = SELECTED_TINT if selected else Color.WHITE

func _refresh() -> void:
	if card == null:
		_rank_label.text = ""
		_suit_label.text = ""
		return
	var ink := RED_INK if card.data.is_red() else BLACK_INK
	_rank_label.text = card.data.get_rank_name()
	_suit_label.text = card.data.get_suit_symbol()
	_rank_label.add_theme_color_override(&"font_color", ink)
	_suit_label.add_theme_color_override(&"font_color", ink)
	refresh_selection()

func _on_pressed() -> void:
	if card != null:
		card_pressed.emit(card)
