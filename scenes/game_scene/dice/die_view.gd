class_name DieView
extends Button
## A die the player can spend.
##
## Input and state feedback only — the face is drawn by the DieFaceView child.
## Rolling is a tween: the die spins through a few random faces, then settles
## with a bounce on the one the engine actually rolled.

signal die_pressed(die : Die)

const SPENT_MODULATE := Color(1, 1, 1, 0.35)
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

## Spins through a few faces before landing on the rolled one.
func play_roll() -> void:
	if die == null:
		return
	_kill_tweens()
	_show_face(die.current_face)
	if die.type == null or die.type.faces.size() < 2:
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

## Greys out dice that are spent or whose action cannot run right now.
func refresh_state(context : GameContext) -> void:
	if not is_node_ready() or die == null:
		return
	var action := die.get_action()
	var usable := not die.is_spent and action != null and action.can_apply(context)
	disabled = not usable
	modulate = SPENT_MODULATE if die.is_spent else Color.WHITE
	_face_view.set_dimmed(not usable)

func _show_face(face : DieFace) -> void:
	_face_view.set_face(face, skin)
	var action := face.action if face != null else null
	tooltip_text = action.description if action != null else ""

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
	if die != null and not die.is_spent:
		die_pressed.emit(die)
