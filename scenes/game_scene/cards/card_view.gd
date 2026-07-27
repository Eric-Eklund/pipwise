class_name CardView
extends Button
## A card the player can tap.
##
## Handles input and selection feedback only — the face itself is drawn by the
## CardFace child. Being a Button gives touch and focus handling for free.

signal card_pressed(card : Card)

const LIFT_HEIGHT := 14.0
const LIFT_TIME := 0.12

@export var skin : CardSkin

var card : Card

var _lift_tween : Tween

@onready var _face : CardFace = %CardFace

func _ready() -> void:
	pressed.connect(_on_pressed)
	_refresh()

func set_card(new_card : Card) -> void:
	card = new_card
	if is_node_ready():
		_refresh()

## Called by HandView when the card's state changes without the hand being
## rebuilt — either the player marked it for swapping, or it started or stopped
## carrying the hand.
func refresh_state() -> void:
	if not is_node_ready():
		return
	var selected := card != null and card.is_selected
	if _lift_tween != null and _lift_tween.is_running():
		_lift_tween.kill()
	_lift_tween = create_tween()
	_lift_tween.tween_property(_face, "lift", LIFT_HEIGHT if selected else 0.0, LIFT_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Borders and the scoring bar change without the lift moving, so redraw even
	# when the tween has nothing to do.
	_face.queue_redraw()

func _refresh() -> void:
	_face.set_card(card, skin)
	refresh_state()

func _on_pressed() -> void:
	if card != null:
		card_pressed.emit(card)
