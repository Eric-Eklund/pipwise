class_name CardRow
extends VBoxContainer
## The hand, under the dice: what is holdable and what this turn can pay for.
##
## Its own row rather than more buttons beside Take, Roll and Bank. Those three
## are deliberately nailed in place — see the class comment on FarkleLevel — so
## that a thumb finds them in the same spot all the way through a turn, and a
## fourth action appearing among them would undo exactly that.
##
## Rebuilt on every change rather than reparented like the dice. A card leaves
## the hand for good when it is played, so there is no object to keep alive, and
## a hand of five is cheap to redraw.

signal card_pressed(card : Card)

## Shown above the row so the cost on each card means something.
const ENERGY_COLOR := Color(0.98, 0.85, 0.42)
const SPENT_COLOR := Color(0.55, 0.58, 0.64)

var _energy_label : Label
var _cards_box : HBoxContainer
var _views : Array[CardView] = []

func _ready() -> void:
	add_theme_constant_override(&"separation", 4)

	_energy_label = Label.new()
	_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy_label.add_theme_font_size_override(&"font_size", 13)
	add_child(_energy_label)

	_cards_box = HBoxContainer.new()
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.add_theme_constant_override(&"separation", 5)
	add_child(_cards_box)

## Redraws the hand and its state. One call, because the hand and what it can
## afford change together — playing a card moves both.
func refresh(game : FarkleGame) -> void:
	if game == null:
		visible = false
		return
	var cards := game.get_hand()
	# Endless mode is not part of a run and has no hand. An empty row would be a
	# strip of dead space above the buttons, so the whole thing goes.
	visible = not cards.is_empty()
	if not visible:
		return

	if _views.size() != cards.size():
		_rebuild(cards)
	else:
		for i in cards.size():
			_views[i].set_card(cards[i])

	for view in _views:
		view.refresh_state(game)
	_refresh_energy(game)

func _rebuild(cards : Array[Card]) -> void:
	for view in _views:
		view.queue_free()
	_views.clear()
	for card in cards:
		var view := CardView.new()
		_cards_box.add_child(view)
		view.set_card(card)
		view.card_pressed.connect(func(pressed_card : Card) -> void:
			card_pressed.emit(pressed_card))
		_views.append(view)

## What the turn has left to spend. Says "spent" rather than "0 energy" when the
## budget is gone, because the number alone reads like a bug.
func _refresh_energy(game : FarkleGame) -> void:
	var left := game.context.available_energy()
	var total := game.context.total_energy()
	if left <= 0:
		_energy_label.text = "Energy spent"
		_energy_label.add_theme_color_override(&"font_color", SPENT_COLOR)
		return
	_energy_label.text = "⚡ %d of %d" % [left, total]
	_energy_label.add_theme_color_override(&"font_color", ENERGY_COLOR)
