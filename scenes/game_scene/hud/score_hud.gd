class_name ScoreHud
extends VBoxContainer
## Shows the objective, where the hand stands against it right now, and how that
## number was arrived at.
##
## Everything is live. The player sees what a swap or a reroll did before
## committing to anything else, which is what makes a fifteen-second round
## something you play rather than guess at.
##
## Reads the objective for its own progress text rather than assuming a score
## target, so a future shape-based objective displays correctly without this
## file changing.

var _game : CardDiceGame

@onready var _objective_label : Label = %ObjectiveLabel
@onready var _progress_label : Label = %ProgressLabel
@onready var _hand_label : Label = %HandLabel
@onready var _breakdown_label : Label = %BreakdownLabel

func bind_game(game : CardDiceGame) -> void:
	_game = game
	_game.progress_changed.connect(_refresh)
	_objective_label.text = _game.get_objective().get_description()
	_refresh()

func _refresh() -> void:
	if _game == null:
		return
	_progress_label.text = _game.get_objective().get_progress_text(_game.context)
	var score := _game.preview_score()
	_hand_label.text = score.label
	_breakdown_label.text = score.breakdown_text()
