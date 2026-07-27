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

const BOSS_COLOR := Color(0.85, 0.45, 0.62)

var _game : CardDiceGame

@onready var _boss_label : Label = %BossLabel
@onready var _objective_label : Label = %ObjectiveLabel
@onready var _progress_label : Label = %ProgressLabel
@onready var _hand_label : Label = %HandLabel
@onready var _breakdown_label : Label = %BreakdownLabel

## Endless mode rebinds this every round, so the previous game is released the
## same way HandView releases a previous hand.
func bind_game(game : CardDiceGame) -> void:
	if _game == game:
		return
	if _game != null:
		_game.progress_changed.disconnect(_refresh)
	_game = game
	if _game == null:
		return
	_game.progress_changed.connect(_refresh)
	_objective_label.text = _game.get_objective().get_description()
	_show_boss()
	_refresh()

## Names the boss and its twist above the objective. Hidden entirely on an
## ordinary level rather than left as an empty row, so the layout does not
## reserve space for something that is not there.
func _show_boss() -> void:
	var ruleset := _game.ruleset
	_boss_label.visible = not ruleset.boss_name.is_empty()
	if not _boss_label.visible:
		return
	_boss_label.text = ruleset.boss_name
	if not ruleset.boss_description.is_empty():
		_boss_label.text += "\n" + ruleset.boss_description
	_boss_label.add_theme_color_override(&"font_color", BOSS_COLOR)

func _refresh() -> void:
	if _game == null:
		return
	_progress_label.text = _game.get_objective().get_progress_text(_game.context)
	var score := _game.preview_score()
	_hand_label.text = score.label
	_breakdown_label.text = score.breakdown_text()
