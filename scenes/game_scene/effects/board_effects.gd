class_name BoardEffects
extends Control
## Shake and flash for the whole board.
##
## Sits over the level as an overlay and drives the board's own container, so
## the level does not have to know how a shake is done — it says "hard" or
## "soft" and this decides what that means.
##
## ## Why it shakes a child and not the level
##
## The level's root is anchored to the full viewport, so its position is
## recomputed from those anchors on every layout pass and anything tweened into
## it is thrown away. The board container inside it is an ordinary child with a
## fixed rect, which is the thing that can actually be moved. Whoever owns this
## node hands it that container.

## How far the board moves at full strength, in pixels.
const SOFT := 4.0
const MEDIUM := 9.0
const HARD := 16.0

const SHAKE_TIME := 0.32
## Steps per shake. Few enough to read as a jolt rather than a blur.
const STEPS := 7

@onready var _flash : ColorRect = %Flash

## The node that actually moves. Set by the level.
var board : Control

var _shake_tween : Tween
var _flash_tween : Tween
## Where the board sits at rest. Anything that moves it has to put it back
## exactly, or a run of shakes walks the layout off the screen.
var _home := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color.a = 0.0

## Just stores the reference. Where the board rests is captured at the first
## shake instead of here, because at bind time the anchors have not run and the
## board is still sitting at the origin — a rest position read now would snap
## the whole layout to the top-left the first time anything happened.
func bind_board(target : Control) -> void:
	board = target

## Jolts the board and settles it. Amplitude decays across the steps so it lands
## rather than stops, which is the difference between a hit and a glitch.
func shake(strength : float) -> void:
	if board == null:
		return
	if _shake_tween != null and _shake_tween.is_running():
		# Put the board back before starting again, so two shakes in quick
		# succession cannot compound into a permanent offset.
		_shake_tween.kill()
		board.position = _home

	_home = board.position
	_shake_tween = create_tween()
	for step in STEPS:
		var decay := 1.0 - float(step) / float(STEPS)
		var offset := Vector2(
			randf_range(-strength, strength), randf_range(-strength, strength)
		) * decay
		_shake_tween.tween_property(
			board, "position", _home + offset, SHAKE_TIME / float(STEPS)
		)
	_shake_tween.tween_property(board, "position", _home, SHAKE_TIME / float(STEPS))

## Washes the screen in a colour and fades it out. A Farkle needs to be felt
## somewhere other than the scoreboard.
func flash(color : Color, peak_alpha : float = 0.34) -> void:
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()
	_flash.color = Color(color, peak_alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
