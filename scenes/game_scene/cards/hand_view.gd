class_name HandView
extends HBoxContainer
## Renders a Hand and reports which card the player tapped.
##
## Entirely signal-driven: bind_hand() subscribes to the Hand and the view redraws
## itself from there. It never mutates the hand — the level decides what a tap
## means, so selection rules stay in the engine.

signal card_pressed(card : Card)

## Cards never draw larger than this, but they shrink to fit. DrawExtraCardAction
## widens the hand permanently, and eight cards at full width overflow a 720px
## portrait screen.
const MAX_CARD_WIDTH := 104.0
const MIN_CARD_WIDTH := 40.0
const CARD_ASPECT := 148.0 / 104.0

@export var card_view_scene : PackedScene

var _hand : Hand
var _card_views : Array[CardView] = []

func _ready() -> void:
	resized.connect(_update_card_sizes)

func bind_hand(hand : Hand) -> void:
	if _hand == hand:
		return
	if _hand != null:
		_hand.changed.disconnect(_rebuild)
		_hand.selection_changed.disconnect(_refresh_selection)
	_hand = hand
	if _hand != null:
		_hand.changed.connect(_rebuild)
		_hand.selection_changed.connect(_refresh_selection)
	_rebuild()

func _rebuild() -> void:
	for view in _card_views:
		view.queue_free()
	_card_views.clear()
	if _hand == null or card_view_scene == null:
		return
	for card in _hand.cards:
		var view := card_view_scene.instantiate() as CardView
		add_child(view)
		view.set_card(card)
		view.card_pressed.connect(_on_card_pressed)
		_card_views.append(view)
	_update_card_sizes()

## Divides the available width between the cards so the row never overflows.
func _update_card_sizes() -> void:
	if _card_views.is_empty():
		return
	var count := _card_views.size()
	var separation := get_theme_constant(&"separation")
	var available := size.x - float(separation * (count - 1))
	var width := clampf(available / float(count), MIN_CARD_WIDTH, MAX_CARD_WIDTH)
	for view in _card_views:
		view.custom_minimum_size = Vector2(width, width * CARD_ASPECT)

func _refresh_selection() -> void:
	for view in _card_views:
		view.refresh_selection()

func _on_card_pressed(card : Card) -> void:
	card_pressed.emit(card)
