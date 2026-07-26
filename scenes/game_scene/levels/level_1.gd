extends Level
## Placeholder level that exercises the card layer end to end.
##
## It owns a Deck and a Hand directly. From M5 the CardDiceGame state machine
## takes that over and this script becomes a thin adapter onto it — the views
## and the engine classes below stay exactly as they are.

@export var hand_size : int = 5
## Non-zero reproduces the same shuffle every run. Handy while testing.
@export var rng_seed : int = 0

var _rng : RngService
var _deck : Deck
var _hand : Hand

@onready var _hand_view : HandView = %HandView
@onready var _deck_label : Label = %DeckLabel

func _ready() -> void:
	super()
	_rng = RngService.new(rng_seed)
	_deck = Deck.new(DeckDefinition.create_standard_52(), _rng)
	_hand = Hand.new(hand_size)
	_hand_view.bind_hand(_hand)
	_hand_view.card_pressed.connect(_on_card_pressed)
	_deal()

## Fills the hand back up to its maximum size.
func _deal() -> void:
	_hand.add(_deck.draw(_hand.missing_count()))
	_update_counts()

func _update_counts() -> void:
	_deck_label.text = "Deck %d    Discard %d" % [
		_deck.draw_pile_size(), _deck.discard_pile_size()
	]

func _on_card_pressed(card : Card) -> void:
	_hand.toggle_selection(card)

## Plays the selected cards. Scoring arrives in M5; for now they just leave.
func _on_play_button_pressed() -> void:
	var played := _hand.take_selected()
	if played.is_empty():
		return
	_deck.discard(played)
	_deal()

## Returns every unlocked card and draws a fresh hand.
func _on_redraw_button_pressed() -> void:
	var returned := _hand.get_unlocked()
	_hand.remove(returned)
	_deck.discard(returned)
	_deal()
