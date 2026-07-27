class_name DieView
extends Button
## A die the player can pay to keep.
##
## Input and state feedback only — the face is drawn by the DieFaceView child.
## Rolling is a tween: the die spins through a few random faces, then settles
## with a bounce on the one the engine actually rolled.

signal die_pressed(die : Die)

const HELD_MODULATE := Color(1, 1, 1, 1)
const UNAFFORDABLE_MODULATE := Color(1, 1, 1, 0.45)
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

## Greys out dice the player cannot currently afford to lock, and badges the
## ones that are already held.
func refresh_state(game : CardDiceGame) -> void:
	if not is_node_ready() or die == null:
		return
	disabled = not game.can_toggle_lock(die)
	modulate = UNAFFORDABLE_MODULATE if disabled and not die.is_held() else HELD_MODULATE
	_face_view.set_badges(die.is_locked, die.is_frozen)
	_face_view.set_dimmed(disabled and not die.is_held())
	if die.is_frozen:
		tooltip_text = "Frozen: this die cannot be locked or rerolled."
	elif die.is_locked:
		tooltip_text = "Locked. Tap to unlock and get %d energy back." % game.lock_cost()
	else:
		tooltip_text = "Tap to lock for %d energy." % game.lock_cost()

func _show_face(face : DieFace) -> void:
	_face_view.set_face(face, skin)

## Deliberately the global RNG, not RngService — these frames are visual noise
## and must not consume the seeded stream the engine's determinism relies on.
func _show_random_face() -> void:
	if die == null or die.type == null or die.type.faces.is_empty():
		return
	var faces := die.type.faces
	_face_view.set_face(faces[randi() % faces.size()], skin)

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
