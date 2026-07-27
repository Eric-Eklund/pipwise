class_name ScoreHud
extends VBoxContainer
## Shows the objective, where the level stands against it, and what the turn on
## the table is worth.
##
## Everything is live. The player sees what marking a die did before committing
## to anything, which is what makes the push-or-bank decision something you make
## rather than guess at.
##
## ## Two scores, shown as two things
##
## Banked points are safe and turn points are not, and the whole game is a bet
## of the second against the first. So the progress line shows what banking
## right now would give — the number the decision actually turns on — and the
## line under it says how much of that would vanish on a Farkle.
##
## Reads the objective for its own progress text rather than assuming a score
## target, so a future objective displays correctly without this file changing.

## Asks the level to open the guide. The HUD does not open it itself: the window
## has to cover the whole board, and a view that reaches outside its own rect to
## parent something is how the level and the HUD stop being separable.
signal guide_requested

const BOSS_COLOR := Color(0.85, 0.45, 0.62)
const RIDING_COLOR := Color(0.98, 0.73, 0.24)
const SAFE_COLOR := Color(0.62, 0.66, 0.72)

## How long the counter takes to roll to a new score, and how hard it swells on
## the way. Long enough to read as a climb, short enough that a player tapping
## quickly is never waiting for it.
const COUNT_TIME := 0.42
const PUNCH_SCALE := Vector2(1.14, 1.14)

var _game : FarkleGame
## What the counter is currently displaying, which lags the real score while it
## rolls. Tweened rather than assigned: a score that snaps from 400 to 3150 is a
## number, and one that rolls up to 3150 is an event.
var _shown_value : float = 0.0
var _count_tween : Tween
var _punch_tween : Tween

@onready var _boss_label : Label = %BossLabel
@onready var _objective_label : Label = %ObjectiveLabel
@onready var _progress_label : Label = %ProgressLabel
@onready var _turn_label : Label = %TurnLabel
@onready var _breakdown_label : Label = %BreakdownLabel
@onready var _guide_button : Button = %GuideButton

func _ready() -> void:
	_guide_button.pressed.connect(func() -> void: guide_requested.emit())
	_progress_label.resized.connect(_centre_progress_pivot)
	_centre_progress_pivot()

## The counter swells from its own centre, so a punch does not shove the number
## sideways under the objective line.
func _centre_progress_pivot() -> void:
	_progress_label.pivot_offset = _progress_label.size / 2.0

## Endless mode rebinds this every round, so a previous game is released rather
## than left connected to a HUD it no longer owns.
func bind_game(game : FarkleGame) -> void:
	if _game == game:
		return
	if _game != null:
		_game.score_changed.disconnect(_refresh)
		_game.turn_started.disconnect(_on_turn_started)
	_game = game
	if _game == null:
		return
	_game.score_changed.connect(_refresh)
	_game.turn_started.connect(_on_turn_started)
	_objective_label.text = _game.get_objective().get_description()
	_show_boss()
	# A new game starts from its own score rather than counting up from the last
	# one's, which in endless mode would mean rolling backwards from 12000 to 0.
	_shown_value = float(_game.get_objective().get_progress_value(_game.context))
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

func _on_turn_started(_turn : int) -> void:
	_refresh()

func _refresh() -> void:
	if _game == null:
		return
	var context := _game.context
	_count_to(_game.get_objective().get_progress_value(context))
	_turn_label.text = _turn_text(context)
	_turn_label.add_theme_color_override(
		&"font_color", RIDING_COLOR if context.turn_score > 0 else SAFE_COLOR
	)
	_breakdown_label.text = _breakdown_text()

## Rolls the counter to [param value]. A drop — a Farkle taking the turn away —
## is not animated: the points are gone, and watching them tick down politely
## would soften exactly the moment that is supposed to hurt.
func _count_to(value : int) -> void:
	if _count_tween != null and _count_tween.is_running():
		_count_tween.kill()

	if float(value) <= _shown_value:
		_shown_value = float(value)
		_render_progress()
		return

	_count_tween = create_tween()
	_count_tween.tween_method(_set_shown_value, _shown_value, float(value), COUNT_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_punch()

func _set_shown_value(value : float) -> void:
	_shown_value = value
	_render_progress()

func _render_progress() -> void:
	if _game == null:
		return
	_progress_label.text = _game.get_objective().format_progress(int(round(_shown_value)))

## A quick swell as the number starts climbing. Half the reason the counter
## reads as an event rather than a readout.
func _punch() -> void:
	if _punch_tween != null and _punch_tween.is_running():
		_punch_tween.kill()
	_progress_label.scale = PUNCH_SCALE
	_punch_tween = create_tween()
	_punch_tween.tween_property(_progress_label, "scale", Vector2.ONE, COUNT_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## What is safe, what is at risk, and how long the level has left. One line,
## because three would be a dashboard and the player is looking at the dice.
func _turn_text(context : GameContext) -> String:
	var parts : Array[String] = ["Banked %d" % context.banked_score]
	if context.turn_score > 0:
		parts.append("risking %d" % context.turn_score)
	var left := context.turns_left()
	if left >= 0:
		parts.append("%d turn%s left" % [left, "" if left == 1 else "s"])
	return "  ·  ".join(parts)

## What the marked dice would add, named and totalled. Falls back to the trios
## the table is offering when nothing is marked, so the line is never blank and
## never stale.
func _breakdown_text() -> String:
	var score := _game.selection_score
	if score == null or not score.is_valid():
		return _trio_text()
	var combo := score.combo_text()
	if combo.is_empty():
		return "%s   %s" % [score.parts_text(), score.breakdown_text()]
	return "%s   %s   %s" % [score.parts_text(), combo, score.breakdown_text()]

## Which element trios are live. The one thing a player cannot work out by
## looking at the dice, because it depends on a rule rather than a face.
func _trio_text() -> String:
	var trios := _game.rules.active_trios()
	if trios.is_empty():
		return ""
	var labels : Array[String] = []
	for element in trios:
		labels.append("%s trio" % Element.get_label(element))
	return "  ·  ".join(labels)
