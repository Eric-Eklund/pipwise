class_name EnergyHud
extends VBoxContainer
## Shows the white energy the dice produced and what is left of it.
##
## Two numbers rather than one: the total never drops when energy is spent, so
## showing only what remains would hide the fact that the same pips are also
## going into the score. Seeing "9 / 21" makes the double duty legible.

const LOW_ENERGY_COLOR := Color(0.90, 0.44, 0.36)
const NORMAL_ENERGY_COLOR := Color(0.98, 0.83, 0.36)

var _game : CardDiceGame

@onready var _amount_label : Label = %AmountLabel
@onready var _cost_label : Label = %CostLabel

## Endless mode rebinds this every round, so the previous game is released the
## same way HandView releases a previous hand.
func bind_game(game : CardDiceGame) -> void:
	if _game == game:
		return
	if _game != null:
		_game.energy_changed.disconnect(_refresh)
		_game.progress_changed.disconnect(_refresh)
	_game = game
	if _game == null:
		return
	_game.energy_changed.connect(_refresh)
	_game.progress_changed.connect(_refresh)
	_cost_label.text = "Swap %d⚡   Lock %d⚡" % [_game.swap_cost(), _game.lock_cost()]
	_refresh()

func _refresh() -> void:
	if _game == null:
		return
	var available := _game.context.available_energy()
	_amount_label.text = "⚡ %d / %d" % [available, _game.context.total_energy()]
	# Red once the player can no longer do the cheapest thing on the board.
	var affordable := mini(_game.swap_cost(), _game.lock_cost())
	_amount_label.add_theme_color_override(
		&"font_color",
		NORMAL_ENERGY_COLOR if available >= affordable else LOW_ENERGY_COLOR
	)
