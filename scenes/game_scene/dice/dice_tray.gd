class_name DiceTray
extends HBoxContainer
## Shows the dice drawn for this turn and reports which one was tapped.
##
## Unlike HandView this is driven explicitly rather than by signals: the drawn
## dice are a plain array the level owns, not an object that emits changes.

signal die_pressed(die : Die)

@export var die_view_scene : PackedScene

var _die_views : Array[DieView] = []

func show_dice(dice : Array[Die]) -> void:
	for view in _die_views:
		view.queue_free()
	_die_views.clear()
	if die_view_scene == null:
		return
	for die in dice:
		var view := die_view_scene.instantiate() as DieView
		add_child(view)
		view.set_die(die)
		view.die_pressed.connect(_on_die_pressed)
		_die_views.append(view)

## Re-evaluates which dice are usable against the current state.
func refresh_state(context : GameContext) -> void:
	for view in _die_views:
		view.refresh_state(context)

func _on_die_pressed(die : Die) -> void:
	die_pressed.emit(die)
