class_name DieView
extends Button
## A die the player can mark and take.
##
## Input and state feedback only — the face is drawn by the DieFaceView child.
## Rolling is a tween: the die spins through a few random faces, then settles
## with a bounce on the one the engine actually rolled.

signal die_pressed(die : Die)

const HELD_MODULATE := Color(1, 1, 1, 1)
## Dice that cannot be part of a scoring selection. Faded, but nowhere near
## invisible: seeing the 2 and the 4 that did not help is how a player learns
## what a Farkle is, and a die whose pips have washed out teaches nothing.
const UNAFFORDABLE_MODULATE := Color(1, 1, 1, 0.78)
const ROLL_STEPS := 5
const ROLL_STEP_TIME := 0.055
const SETTLE_TIME := 0.3
const START_ANGLE := -0.5
const START_SCALE := Vector2(1.25, 1.25)

@export var skin : DieSkin

var die : Die

var _settle_tween : Tween
var _flicker_tween : Tween

@onready var _face_view : DieFaceView = %DieFaceView

func _ready() -> void:
	_centre_pivot()
	resized.connect(_centre_pivot)
	pressed.connect(_on_pressed)
	if die != null:
		play_roll()

func set_die(new_die : Die) -> void:
	die = new_die
	if is_node_ready():
		play_roll()

## Spins through a few faces before landing on the rolled one. Held dice do not
## animate — the point of paying to keep one is that it visibly stays put.
func play_roll() -> void:
	if die == null:
		return
	_kill_tweens()
	_show_face(die.current_face)
	if die.is_held() or die.type == null or die.type.faces.size() < 2:
		return

	rotation = START_ANGLE
	scale = START_SCALE
	_settle_tween = create_tween()
	_settle_tween.set_parallel(true)
	_settle_tween.tween_property(self, "rotation", 0.0, SETTLE_TIME) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_settle_tween.tween_property(self, "scale", Vector2.ONE, SETTLE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_flicker_tween = create_tween()
	for _i in ROLL_STEPS:
		_flicker_tween.tween_callback(_show_random_face).set_delay(ROLL_STEP_TIME)
	_flicker_tween.tween_callback(func() -> void: _show_face(die.current_face))

## Fades the dice that cannot be part of a scoring selection, and badges the
## ones the player has marked or already taken.
func refresh_state(game : FarkleGame) -> void:
	if not is_node_ready() or die == null:
		return
	var marked := game.is_selected(die)
	var selectable := marked or game.can_select(die)
	disabled = not selectable
	modulate = HELD_MODULATE if selectable or die.is_set_aside else UNAFFORDABLE_MODULATE
	_face_view.set_badges(die.is_set_aside, marked)
	_face_view.set_dimmed(disabled and not die.is_set_aside)

	if die.is_set_aside:
		tooltip_text = "Set aside. These points are yours unless you Farkle."
	elif marked:
		tooltip_text = "Tap to unmark. %s" % _element_hint()
	elif selectable:
		tooltip_text = "Tap to mark. %s" % _element_hint()
	else:
		tooltip_text = "Scores nothing on its own."

func _element_hint() -> String:
	if die.element == Element.NONE:
		return ""
	return "%s — %s" % [die.get_element_label(), Element.get_description(die.element)]

func _show_face(face : DieFace) -> void:
	_face_view.set_face(face, skin, die.element if die != null else Element.NONE)

## Deliberately the global RNG, not RngService — these frames are visual noise
## and must not consume the seeded stream the engine's determinism relies on.
func _show_random_face() -> void:
	if die == null or die.type == null or die.type.faces.is_empty():
		return
	var faces := die.type.faces
	_face_view.set_face(faces[randi() % faces.size()], skin, die.element)

func _kill_tweens() -> void:
	if _settle_tween != null and _settle_tween.is_running():
		_settle_tween.kill()
	if _flicker_tween != null and _flicker_tween.is_running():
		_flicker_tween.kill()

func _centre_pivot() -> void:
	pivot_offset = size / 2.0

func _on_pressed() -> void:
	if die != null:
		die_pressed.emit(die)
