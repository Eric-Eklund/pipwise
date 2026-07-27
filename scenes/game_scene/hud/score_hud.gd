class_name ScoreHud
extends VBoxContainer
## Shows the objective, progress towards it, plays left, and what the last
## hand scored.
##
## Reads the objective for its own progress text rather than assuming a score
## target, so a future combination or checklist objective displays correctly
## without touching this file.

var _game : CardDiceGame

@onready var _objective_label : Label = %ObjectiveLabel
@onready var _progress_label : Label = %ProgressLabel
@onready var _plays_label : Label = %PlaysLabel
@onready var _last_hand_label : Label = %LastHandLabel

func bind_game(game : CardDiceGame) -> void:
	_game = game
	_game.progress_changed.connect(_refresh)
	_game.hand_played.connect(_on_hand_played)
	_objective_label.text = _game.get_objective().get_description()
	_last_hand_label.text = ""
	_refresh()

func _refresh() -> void:
	if _game == null:
		return
	_progress_label.text = _game.get_objective().get_progress_text(_game.context)
	var multiplier := _game.context.score_multiplier
	if is_equal_approx(multiplier, 1.0):
		_plays_label.text = "Plays left: %d" % _game.context.plays_left
	else:
		_plays_label.text = "Plays left: %d    Next hand x%.1f" % [
			_game.context.plays_left, multiplier
		]

func _on_hand_played(score : HandScore) -> void:
	_last_hand_label.text = "%s   %d x %.1f = %d" % [
		score.label, score.base_points, score.multiplier, score.total()
	]
