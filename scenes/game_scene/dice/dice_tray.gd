class_name DiceTray
extends VBoxContainer
## The dice on the table, in two rows: the ones still being rolled, and the ones
## already committed to this turn.
##
## The views are built once, when the dice are bound, and reparented between the
## rows from then on. Rebuilding them would restart every roll animation from
## nothing and lose the sense that these are physical objects being shaken
## again — and the dice really are the same six objects all level, so the nodes
## should be too.

signal die_pressed(die : Die)

## Dice never draw larger than this, but they shrink to fit. Sized in design
## pixels against a 540-wide viewport, which on a 1440-wide phone puts a die at
## roughly 60dp — comfortably above the 48dp Android asks of a tap target, and
## six of them still fit a row.
const MAX_DIE_SIZE := 96.0
const MIN_DIE_SIZE := 44.0

@export var die_view_scene : PackedScene

@onready var _in_play_row : HBoxContainer = %InPlayRow
@onready var _set_aside_row : HBoxContainer = %SetAsideRow
@onready var _set_aside_label : Label = %SetAsideLabel

var _die_views : Array[DieView] = []

func _ready() -> void:
	resized.connect(_update_die_sizes)

## Builds one view per die, from nothing. Call once per round.
func show_dice(dice : Array[Die]) -> void:
	for view in _die_views:
		_discard(view)
	_die_views.clear()
	_sync_dice(dice)

## Brings the views into line with the dice the game is holding, and returns
## whether anything moved.
##
## Called on every refresh rather than only from show_dice(), because Extra Die
## puts a die on the table mid-turn and the turn boundary takes it away again.
## The views that were already there are kept: rebuilding all of them to add one
## would restart six roll animations, and these are supposed to look like the
## same physical objects all level.
func _sync_dice(dice : Array[Die]) -> bool:
	if die_view_scene == null:
		return false
	var changed := false

	var wanted : Dictionary = {}
	for die in dice:
		wanted[die] = true
	for index in range(_die_views.size() - 1, -1, -1):
		if wanted.has(_die_views[index].die):
			continue
		_discard(_die_views[index])
		_die_views.remove_at(index)
		changed = true

	var drawn : Dictionary = {}
	for view in _die_views:
		drawn[view.die] = true
	for die in dice:
		if drawn.has(die):
			continue
		var view := die_view_scene.instantiate() as DieView
		_in_play_row.add_child(view)
		view.set_die(die)
		view.die_pressed.connect(_on_die_pressed)
		_die_views.append(view)
		changed = true

	if changed:
		_update_die_sizes()
	return changed

## Unparented before it is freed: queue_free() alone leaves the view in the row
## until the end of the frame, so a row that shed a die would spend that frame
## asking for the width of both. See _update_die_sizes for what a row wider than
## the screen costs.
func _discard(view : DieView) -> void:
	view.get_parent().remove_child(view)
	view.queue_free()

## Replays the roll animation. Dice already set aside sit it out on their own.
func play_roll() -> void:
	for view in _die_views:
		view.play_roll()

## Replays the roll animation for some of the dice and leaves the rest still.
## What a card that turned a die over asks for: play_roll() would shake six dice
## to show that one of them changed, which reads as a roll that did not happen.
func play_roll_for(dice : Array[Die]) -> void:
	for view in _die_views:
		if view.die in dice:
			view.play_roll()

## Bursts the dice that were just taken. Takes the dice rather than reading the
## pool, because by the time this is called every die in the pool looks the same
## and only the caller knows which ones the player just chose.
func play_take(dice : Array[Die]) -> void:
	for view in _die_views:
		if view.die in dice:
			view.play_take()

## Re-evaluates which dice are tappable, and moves any that changed rows.
func refresh_state(game : FarkleGame) -> void:
	var moved := _sync_dice(game.get_dice())
	for view in _die_views:
		view.refresh_state(game)
		var wanted : HBoxContainer = _set_aside_row if view.die.is_set_aside else _in_play_row
		if view.get_parent() != wanted:
			# reparent() rather than remove + add: it keeps the node alive, so a
			# roll tween mid-flight is not left holding a freed object.
			view.reparent(wanted)
			moved = true

	var has_set_aside := _set_aside_row.get_child_count() > 0
	_set_aside_row.visible = has_set_aside
	_set_aside_label.visible = has_set_aside
	if moved:
		_update_die_sizes()

## Divides the available width between the dice so neither row overflows and the
## faces stay square. Sized against the fuller row, so a die does not change
## size when it moves between them.
##
## ## Why the size is floored
##
## A die's size is its minimum size, and a row's minimum size is what its dice
## add up to — so this decides how much width the tray demands of the board.
## Demand a pixel more than the tray was given and the board grows to supply it,
## which makes the tray wider, which lets the next pass demand more still: the
## dice run up to MAX_DIE_SIZE and hang off both edges of the screen. Flooring
## keeps the sum at or under the width the tray already has, which is what stops
## that loop from having a first step.
func _update_die_sizes() -> void:
	if _die_views.is_empty():
		return
	var count := maxi(
		1, maxi(_in_play_row.get_child_count(), _set_aside_row.get_child_count())
	)
	var separation := _in_play_row.get_theme_constant(&"separation")
	var available := size.x - float(separation * (count - 1))
	var extent := clampf(floorf(available / float(count)), MIN_DIE_SIZE, MAX_DIE_SIZE)
	for view in _die_views:
		view.custom_minimum_size = Vector2(extent, extent)

func _on_die_pressed(die : Die) -> void:
	die_pressed.emit(die)
