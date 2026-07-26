extends Level
## Placeholder level that exercises the card and dice layers end to end.
##
## It owns the deck, bag and hand directly. From M5 the CardDiceGame state
## machine takes that over and this script becomes a thin adapter onto it —
## the views and the engine classes below stay exactly as they are.

@export var hand_size : int = 5
@export var dice_per_turn : int = 2
## Non-zero reproduces the same shuffle and rolls every run. Handy while testing.
@export var rng_seed : int = 0

var _rng : RngService
var _deck : Deck
var _bag : DiceBag
var _hand : Hand
var _context : GameContext
var _drawn_dice : Array[Die] = []

@onready var _hand_view : HandView = %HandView
@onready var _dice_tray : DiceTray = %DiceTray
@onready var _deck_label : Label = %DeckLabel
@onready var _dice_label : Label = %DiceLabel

func _ready() -> void:
	super()
	_rng = RngService.new(rng_seed)
	_deck = Deck.new(DeckDefinition.create_standard_52(), _rng)
	_bag = DiceBag.new(StarterDice.create_starter_bag(), _rng)
	_hand = Hand.new(hand_size)
	_context = GameContext.new(_deck, _hand, _rng)

	_hand_view.bind_hand(_hand)
	_hand_view.card_pressed.connect(_on_card_pressed)
	_dice_tray.die_pressed.connect(_on_die_pressed)
	# Dice enable and disable as the selection changes, since most actions
	# need cards picked before they can do anything.
	_hand.changed.connect(_refresh)
	_hand.selection_changed.connect(_refresh)

	_refill_hand()
	_start_turn()

func _refill_hand() -> void:
	_context.refill_hand()

## Returns whatever dice went unspent and draws a fresh set.
func _start_turn() -> void:
	var unspent : Array[Die] = []
	for die in _drawn_dice:
		if not die.is_spent:
			unspent.append(die)
	_bag.return_dice(unspent)
	_drawn_dice = _bag.draw(dice_per_turn)
	_dice_tray.show_dice(_drawn_dice)
	_refresh()

func _refresh() -> void:
	_deck_label.text = "Deck %d    Discard %d" % [
		_deck.draw_pile_size(), _deck.discard_pile_size()
	]
	_dice_label.text = "Bag %d    Used %d    Mult x%.1f" % [
		_bag.bag_size(), _bag.used_size(), _context.score_multiplier
	]
	_dice_tray.refresh_state(_context)

func _on_card_pressed(card : Card) -> void:
	_hand.toggle_selection(card)

## Spending a die runs its face's action. Redrawing costs a die — there is no
## free redraw, which is the whole point of dice being currency.
func _on_die_pressed(die : Die) -> void:
	var action := die.get_action()
	if action == null or not action.can_apply(_context):
		return
	action.apply(_context)
	_bag.spend(die)
	_refresh()

## Plays the selected cards and ends the turn. Scoring arrives in M5; for now
## the cards just leave and the hand refills.
func _on_play_button_pressed() -> void:
	var played := _hand.take_selected()
	if played.is_empty():
		return
	_deck.discard(played)
	_refill_hand()
	_start_turn()
