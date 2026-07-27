class_name DiceTray
extends HBoxContainer
## Shows the dice on the table and reports which one was tapped.
##
## The views are built once, when the dice are bound, and reused from then on.
## The dice are the same six objects all level — throwing the nodes away on
## every reroll would restart each roll animation from nothing and lose the
## sense that these are physical objects being shaken again.

signal die_pressed(die : Die)

@export var die_view_scene : PackedScene

var _die_views : Array[DieView] = []

## Builds one view per die. Call once per level.
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

## Replays the roll animation. Held dice sit it out on their own.
func play_roll() -> void:
	for view in _die_views:
		view.play_roll()

## Re-evaluates which dice are tappable against the current state.
func refresh_state(game : CardDiceGame) -> void:
	for view in _die_views:
		view.refresh_state(game)

func _on_die_pressed(die : Die) -> void:
	die_pressed.emit(die)
