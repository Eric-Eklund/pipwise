class_name DiceTray
extends HBoxContainer
## Shows the dice on the table and reports which one was tapped.
##
## The views are built once, when the dice are bound, and reused from then on.
## The dice are the same six objects all level — throwing the nodes away on
## every reroll would restart each roll animation from nothing and lose the
## sense that these are physical objects being shaken again.

signal die_pressed(die : Die)

## Dice never draw larger than this, but they shrink to fit. Six dice at full
## size overflow a 720px portrait screen, and a later ruleset could ask for more.
const MAX_DIE_SIZE := 88.0
const MIN_DIE_SIZE := 34.0

@export var die_view_scene : PackedScene

var _die_views : Array[DieView] = []

func _ready() -> void:
	resized.connect(_update_die_sizes)

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
	_update_die_sizes()

## Divides the available width between the dice so the row never overflows and
## the faces stay square.
func _update_die_sizes() -> void:
	if _die_views.is_empty():
		return
	var count := _die_views.size()
	var separation := get_theme_constant(&"separation")
	var available := size.x - float(separation * (count - 1))
	var extent := clampf(available / float(count), MIN_DIE_SIZE, MAX_DIE_SIZE)
	for view in _die_views:
		view.custom_minimum_size = Vector2(extent, extent)

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
