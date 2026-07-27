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

## Asks the level to open the hand guide. The HUD does not open it itself: the
## window has to cover the whole board, and a view that reaches outside its own
## rect to parent something is how the level and the HUD stop being separable.
signal guide_requested

const BOSS_COLOR := Color(0.85, 0.45, 0.62)

var _game : CardDiceGame

@onready var _boss_label : Label = %BossLabel
@onready var _objective_label : Label = %ObjectiveLabel
@onready var _progress_label : Label = %ProgressLabel
@onready var _breakdown_label : Label = %BreakdownLabel
@onready var _guide_button : Button = %GuideButton

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

func _ready() -> void:
	_guide_button.pressed.connect(func() -> void: guide_requested.emit())

## The hand's name is not shown here. It lives under the cards, next to the ones
## it is naming, so the frame and the name read as one thing.
func _refresh() -> void:
	if _game == null:
		return
	_progress_label.text = _game.get_objective().get_progress_text(_game.context)
	if _game.preview != null:
		_breakdown_label.text = _game.preview.breakdown_text()
