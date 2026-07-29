class_name CardView
extends Button
## One card in the row: what it is, what it costs, and whether it can be played.
##
## Built in code rather than as a scene. A card is a button with two labels and a
## border, all of which have to be tinted per card anyway — a .tscn would be six
## nodes of boilerplate whose every visual property this script overwrites on the
## first frame.
##
## Like DieView, it renders and reports a press. It never plays the card itself;
## the level asks the engine, and the engine decides.

signal card_pressed(card : Card)
## The card was held down rather than tapped. What opens its detail window.
signal card_held(card : Card)

## How long a press has to last to count as a hold. Roughly Android's own long
## press: much shorter and a slow tap opens a window nobody asked for.
const HOLD_TIME := 0.45

## Sized in design pixels against a 540-wide viewport. The board keeps 22px of
## margin either side, so the row has 496 to spend: a full hand of five plus the
## 5px between them fits at 92, which on a 1440-wide phone is roughly 70dp — well
## over the 48dp Android asks of a tap target.
##
## This is a floor, not the drawn width. The views expand to fill the row, so a
## hand of three still draws three wide cards. It was 96, which is 4px too much
## across a full hand: the row asked for 500, the board grew past the screen to
## give it, and everything on it shifted left by the overhang.
const CARD_WIDTH := 92.0
const CARD_HEIGHT := 74.0

## How far an unaffordable card fades. Still readable: the player needs to know
## what they are saving up for, not merely that they cannot have it.
const UNAFFORDABLE_MODULATE := Color(1, 1, 1, 0.38)

var card : Card

var _name_label : Label
var _cost_label : Label
var _panel : PanelContainer
var _hold_timer : Timer
## Set when a hold has already been answered with a window, so the release that
## follows does not also play the card. A press is either a tap or a hold.
var _held := false

func _init() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_text = true
	# The button is the hit box; everything visible is drawn by the panel under
	# it, so the default button styling has to get out of the way entirely.
	for style in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())

func _ready() -> void:
	_build()
	pressed.connect(_on_pressed)

## The hold is timed off raw input rather than off button_down and button_up.
##
## A disabled Button emits neither — and a card the row has greyed out is
## exactly the card whose explanation the player wants, because "why not?" is
## the only question a greyed card raises. _gui_input still arrives, because
## disabling a button does not stop it being hit: it only stops it acting.
##
## The event is not accepted. The Button's own press handling has to run after
## this, or a tap would stop playing the card.
func _gui_input(event : InputEvent) -> void:
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT:
			_set_pressing(click.pressed)
	elif event is InputEventScreenTouch:
		_set_pressing((event as InputEventScreenTouch).pressed)

## Touch is emulated onto mouse as well as delivered raw, so both arrive for one
## finger. Restarting a running timer and stopping a stopped one are both
## harmless, which is what lets this stay this short.
func _set_pressing(down : bool) -> void:
	if down:
		_held = false
		_hold_timer.start()
	else:
		_hold_timer.stop()

func _on_hold() -> void:
	if card == null:
		return
	_held = true
	card_held.emit(card)

func _on_pressed() -> void:
	# The hold has already been answered with a window. Playing the card on the
	# way out of it would be two actions bought with one press.
	if _held:
		_held = false
		return
	card_pressed.emit(card)

func _build() -> void:
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = HOLD_TIME
	_hold_timer.timeout.connect(_on_hold)
	add_child(_hold_timer)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override(&"font_size", 13)
	box.add_child(_name_label)

	_cost_label = Label.new()
	_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost_label.add_theme_font_size_override(&"font_size", 12)
	box.add_child(_cost_label)

func set_card(new_card : Card) -> void:
	card = new_card
	if not is_node_ready() or card == null:
		return
	_name_label.text = card.get_label()
	_cost_label.text = "%d⚡" % card.energy_cost
	tooltip_text = card.description
	_paint(card.get_color())

## Border and name in the card's own colour, so a row of potions can be scanned
## by element the same way the dice are.
func _paint(color : Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.14)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(4)
	_panel.add_theme_stylebox_override(&"panel", style)
	_name_label.add_theme_color_override(&"font_color", color)
	_cost_label.add_theme_color_override(&"font_color", color)

## Greyed when it cannot be played, whether that is the energy or the board.
## Disabled rather than hidden, because a card that vanishes when you cannot
## afford it is a card you never learn the cost of.
func refresh_state(game : FarkleGame) -> void:
	if not is_node_ready() or card == null or game == null:
		return
	var playable := game.can_play_card(card)
	disabled = not playable
	modulate = Color.WHITE if playable else UNAFFORDABLE_MODULATE
