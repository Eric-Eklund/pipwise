class_name DieView
extends Button
## Placeholder die: the current face's label drawn as text.
##
## A pure view. This is where the "3D look, 2D tech" art lands later — an
## AnimatedSprite2D playing a pre-rendered tumble that settles on the rolled
## face. Nothing under scripts/dice/ changes when that happens.

signal die_pressed(die : Die)

const SPENT_MODULATE := Color(1, 1, 1, 0.35)

var die : Die

@onready var _label : Label = %FaceLabel

func _ready() -> void:
	pressed.connect(_on_pressed)
	_refresh()

func set_die(new_die : Die) -> void:
	die = new_die
	if is_node_ready():
		_refresh()

## Greys out dice that are spent or whose action cannot run right now.
func refresh_state(context : GameContext) -> void:
	if not is_node_ready() or die == null:
		return
	var action := die.get_action()
	var usable := not die.is_spent and action != null and action.can_apply(context)
	disabled = not usable
	modulate = SPENT_MODULATE if die.is_spent else Color.WHITE

func _refresh() -> void:
	if die == null:
		_label.text = ""
		tooltip_text = ""
		return
	_label.text = die.get_label()
	var action := die.get_action()
	tooltip_text = action.description if action != null else ""

func _on_pressed() -> void:
	if die != null and not die.is_spent:
		die_pressed.emit(die)
