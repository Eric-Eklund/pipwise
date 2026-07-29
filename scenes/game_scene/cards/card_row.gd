class_name CardRow
extends VBoxContainer
## The hand, under the dice: what is holdable, what this turn can pay for, and —
## while a card is waiting for a die — what that card is asking.
##
## Its own row rather than more buttons beside Take, Roll and Bank. Those three
## are deliberately nailed in place — see the class comment on FarkleLevel — so
## that a thumb finds them in the same spot all the way through a turn, and a
## fourth action appearing among them would undo exactly that.
##
## Rebuilt on every change rather than reparented like the dice. A card leaves
## the hand for good when it is played, so there is no object to keep alive, and
## a hand of five is cheap to redraw.
##
## ## The targeting bar
##
## Value Shift and Value Converter ask for a die after they are tapped, and the
## row is where that conversation happens: the hand is replaced by the card's
## prompt, whatever choices it offers, and a way out. Replaced rather than added
## to, because the two cannot both be live — no other card may be played while
## one is waiting — and because a row that grew a second line would push the
## board taller mid-turn.

signal card_pressed(card : Card)
## A card was held down. The level answers it with the card's detail window.
signal card_held(card : Card)
## One of the waiting card's choices was armed, by index.
signal target_choice_picked(index : int)
## The player backed out of a targeting step.
signal target_cancelled

## Shown above the row so the cost on each card means something.
const ENERGY_COLOR := Color(0.98, 0.85, 0.42)
const SPENT_COLOR := Color(0.55, 0.58, 0.64)
## The armed choice, against the muted look of the one that is not.
const ARMED_COLOR := Color(0.13, 0.15, 0.20)

var _energy_label : Label
var _cards_box : HBoxContainer
var _views : Array[CardView] = []

var _target_box : HBoxContainer
var _target_label : Label
var _choices_box : HBoxContainer
var _choice_buttons : Array[Button] = []
## The card the choice buttons were built for, so they are rebuilt when it
## changes and not on every refresh.
var _target_card : Card

func _ready() -> void:
	add_theme_constant_override(&"separation", 4)

	_energy_label = Label.new()
	# Named so the playthrough probe can read the number the player reads. The
	# budget is set after the roll that refreshes this row, so a stale figure
	# here is invisible to every test that talks to the engine instead.
	_energy_label.name = "EnergyLabel"
	_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy_label.add_theme_font_size_override(&"font_size", 13)
	add_child(_energy_label)

	_cards_box = HBoxContainer.new()
	# Named because the probes report layout trouble by node name, and "the second
	# HBoxContainer" is not something anyone can act on.
	_cards_box.name = "Cards"
	_cards_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_box.add_theme_constant_override(&"separation", 5)
	add_child(_cards_box)

	_build_target_box()

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

	var targeting := game.is_targeting()
	_cards_box.visible = not targeting
	_target_box.visible = targeting
	if targeting:
		_refresh_target(game)
		_refresh_energy(game)
		return

	_target_card = null
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
		# Unparented before it is freed, not merely queued. queue_free() leaves the
		# node in the row until the end of the frame, so a hand of five being
		# replaced by three spent a frame as a row of eight — 800px of minimum
		# width on a 540px screen. The board is grown to whatever its contents
		# demand, and a full-rect Control that has outgrown its parent is centred
		# on it, so the whole layout stayed hanging off both edges from then on:
		# the dice half off the screen, the buttons cut in half.
		_cards_box.remove_child(view)
		view.queue_free()
	_views.clear()
	for card in cards:
		var view := CardView.new()
		_cards_box.add_child(view)
		view.set_card(card)
		view.card_pressed.connect(func(pressed_card : Card) -> void:
			card_pressed.emit(pressed_card))
		view.card_held.connect(func(held_card : Card) -> void:
			card_held.emit(held_card))
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

# --- targeting --------------------------------------------------------------

func _build_target_box() -> void:
	_target_box = HBoxContainer.new()
	_target_box.name = "Targeting"
	_target_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_target_box.add_theme_constant_override(&"separation", 6)
	_target_box.visible = false
	add_child(_target_box)

	_target_label = Label.new()
	_target_label.name = "TargetPrompt"
	_target_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_target_label.add_theme_font_size_override(&"font_size", 13)
	_target_box.add_child(_target_label)

	_choices_box = HBoxContainer.new()
	_choices_box.name = "Choices"
	_choices_box.add_theme_constant_override(&"separation", 4)
	_target_box.add_child(_choices_box)

	# Named so the probe can back a level out of a targeting step it could not
	# finish. A card waiting for a die refuses Take, Roll and Bank, so this is
	# the only way off the board — and a way off the board that nothing checks is
	# how the game ends up with a dead one.
	var cancel := Button.new()
	cancel.name = "CancelTargetButton"
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(74, CardView.CARD_HEIGHT * 0.5)
	cancel.pressed.connect(func() -> void: target_cancelled.emit())
	_target_box.add_child(cancel)

func _refresh_target(game : FarkleGame) -> void:
	var card := game.get_targeting_card()
	_target_label.text = card.target_prompt()
	_target_label.add_theme_color_override(&"font_color", card.get_color())
	if _target_card != card:
		_target_card = card
		_rebuild_choices(card)
	var armed := game.get_target_choice()
	for i in _choice_buttons.size():
		_choice_buttons[i].button_pressed = i == armed
		_choice_buttons[i].add_theme_color_override(
			&"font_color", card.get_color() if i == armed else SPENT_COLOR
		)

## One toggle per choice the card offers, and none at all for a card whose only
## question is which die.
func _rebuild_choices(card : Card) -> void:
	for button in _choice_buttons:
		# Unparented before freeing, like every other row in this project: a
		# queued node still asks the layout for its width. See _rebuild().
		_choices_box.remove_child(button)
		button.queue_free()
	_choice_buttons.clear()

	var choices := card.target_choices()
	for i in choices.size():
		var button := Button.new()
		button.text = choices[i]
		button.toggle_mode = true
		# Wide enough for a thumb: 48px against a 540 viewport is about 36dp on a
		# 1440-wide phone, and these sit between two other targets.
		button.custom_minimum_size = Vector2(52, CardView.CARD_HEIGHT * 0.5)
		var index := i
		button.pressed.connect(func() -> void: target_choice_picked.emit(index))
		_choices_box.add_child(button)
		_choice_buttons.append(button)
