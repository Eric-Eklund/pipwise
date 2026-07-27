class_name ScoreBanner
extends Control
## The line that announces what just happened, over the dice.
##
## Every event in a turn is a number changing somewhere on the HUD, and a number
## changing is not something you feel. The banner is what turns "the score went
## up" into "🔥 FIRE ×2.5", and it is the only place a Farkle is allowed to be
## loud.
##
## Sits as a free-floating overlay rather than a row in the level's layout, for
## two reasons: a container would overwrite the position this animates, and the
## banner has to be able to sit *over* the dice rather than push them down.
##
## One banner, reused. A queue of overlapping labels would be more flexible and
## would also let a hot dice announcement land on top of the score that earned
## it — those two events arrive in the same frame, so the last one has to win
## outright.

## Colours for the events that are not element-flavoured.
const NEUTRAL_COLOR := Color(0.98, 0.95, 0.88)
const FARKLE_COLOR := Color(0.94, 0.38, 0.32)
const HOT_COLOR := Color(0.99, 0.78, 0.30)
const BANK_COLOR := Color(0.42, 0.85, 0.55)

const RISE_PIXELS := 40.0
const POP_TIME := 0.22
const HOLD_TIME := 0.55
const FADE_TIME := 0.45
const POP_SCALE := Vector2(1.25, 1.25)

@onready var _body : VBoxContainer = %Body
@onready var _title : Label = %TitleLabel
@onready var _amount : Label = %AmountLabel

var _tween : Tween
## Where the body rests when nothing is playing. Captured after the first layout
## pass, because anchors decide it and they have not run at _ready().
var _home := Vector2.ZERO

func _ready() -> void:
	# An overlay that swallowed taps would make the dice unclickable for the
	# second after every take, which is exactly when the player wants to tap.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.modulate.a = 0.0
	_body.resized.connect(_on_body_resized)
	_on_body_resized()

func _on_body_resized() -> void:
	_body.pivot_offset = _body.size / 2.0
	if _tween == null or not _tween.is_running():
		_home = _body.position

## Announces a scoring take. Named by its combo when it has one, because
## "🔥 Fire ×2.5" is the thing the player *did*, and "Three 6s" is merely what
## the dice said.
func show_score(score : DiceScore) -> void:
	if score == null or not score.is_valid():
		return
	var combo := score.combo_text()
	if combo.is_empty():
		_play(score.parts_text(), "+%d" % score.total(), NEUTRAL_COLOR)
	else:
		_play(combo, "+%d" % score.total(), Element.get_color(score.combo_element))

func show_farkle(points_lost : int) -> void:
	_play("FARKLE", "-%d" % points_lost if points_lost > 0 else "", FARKLE_COLOR)

func show_hot_dice() -> void:
	_play("HOT DICE", "all six back", HOT_COLOR)

func show_banked(points : int) -> void:
	_play("BANKED", str(points), BANK_COLOR)

## Pops, rises, holds, fades. Killing the previous tween first is what makes the
## newest event win: a take that clears the table fires a score and hot dice
## within the same frame, and the player should see the hot dice.
func _play(title : String, amount : String, color : Color) -> void:
	_title.text = title
	_amount.text = amount
	_amount.visible = not amount.is_empty()
	_title.add_theme_color_override(&"font_color", color)
	_amount.add_theme_color_override(&"font_color", color)

	if _tween != null and _tween.is_running():
		_tween.kill()

	_body.modulate.a = 1.0
	_body.scale = POP_SCALE
	_body.position = _home

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_body, "scale", Vector2.ONE, POP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(
		_body, "position:y", _home.y - RISE_PIXELS, HOLD_TIME + FADE_TIME
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_body, "modulate:a", 0.0, FADE_TIME).set_delay(HOLD_TIME)
