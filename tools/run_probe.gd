extends Node
## Loses a level on purpose and checks the player can still get out.
##
##     godot --headless res://tools/run_probe.tscn
##
## The one thing neither other probe can see. `playthrough_probe` drives level
## scenes in isolation, so it never reaches LevelManager, and the headless suite
## never builds a scene tree at all — which is how a crash in the loss handler
## shipped and left the board frozen with every button dead and no window.
##
## What this asserts, in order of how badly it hurt to be missing:
##
##   1. A loss produces a window. If the handler throws before instantiating it,
##      the player is stranded on a dead board and the game is over for good.
##   2. That window's button actually navigates.
##   3. The dice collection survives and the run does not.
##
## Development tool. Nothing in the game references it.

const GAME_UI := "res://scenes/game_scene/game_ui.tscn"
const LEVEL_DIR := "res://scenes/game_scene/levels"
## Long enough for the loading screen and the level's own ready to finish.
const LOAD_FRAMES := 30

var _failures : Array[String] = []
var _manager : LevelManager

func _ready() -> void:
	# One frame before touching the root, which is still setting up its children
	# while this _ready runs and refuses an add_child until it has finished.
	await get_tree().process_frame

	var ui : Node = load(GAME_UI).instantiate()
	# Parented to the root rather than to the probe, because current_scene only
	# accepts a direct child of the root — and it has to be the game UI, since
	# that is what the loss handler adds its window to. Assigned rather than
	# switched to with change_scene_to_file, which frees the running scene, and
	# the running scene here is the probe.
	get_tree().root.add_child(ui)
	get_tree().current_scene = ui
	for _i in LOAD_FRAMES:
		await get_tree().process_frame

	_manager = ui.find_child("LevelManager", true, false)
	if _manager == null:
		_fail("no LevelManager in %s" % GAME_UI)
		return _report()

	# Every level, not just the first. A boss carries a modifier and a loadout
	# screen that an ordinary level does not, and the report that started this
	# was a loss against the Ember Warden rather than against level 1.
	# Both exits from the last turn, on every level. Banking out of it and
	# pressing on through a Farkle reach the loss through different code, and the
	# report that started this came from the Farkle one.
	var campaign : Campaign = load("res://resources/campaign.tres")
	for level_number in range(1, campaign.level_count + 1):
		await _lose_on(level_number, false)
		await _lose_on(level_number, true)
	_report()

func _lose_on(level_number : int, via_farkle : bool) -> void:
	_manager.load_level("%s/level_%d.tscn" % [LEVEL_DIR, level_number])
	for _i in LOAD_FRAMES:
		await get_tree().process_frame

	var level : FarkleLevel = _find_level()
	if level == null:
		_fail("level %d never loaded" % level_number)
		return

	# A checkpoint opens the loadout, and the round waits for it to close.
	_dismiss_loadout(level)
	await get_tree().process_frame

	var owned_before := GameState.get_dice_collection().total()
	_force_loss(level, level_number, via_farkle)
	for _i in 10:
		await get_tree().process_frame

	_check_window(level_number, via_farkle, owned_before)
	_clear_windows()
	await get_tree().process_frame

## Runs the turns out on the last turn, which is the way a level is actually
## lost. Both exits are driven: banking out of the final turn, and pressing on
## through a Farkle — the second is the one the bug report came from.
func _force_loss(level : FarkleLevel, level_number : int, via_farkle : bool) -> void:
	if level.game == null:
		_fail("level %d never built a game" % level_number)
		return
	level.game.context.turn = maxi(1, level.game.ruleset.turns)
	level.game.context.banked_score = 0

	if not via_farkle:
		level.game._end_turn()
		return

	# Forced rather than rolled for, because a Farkle on the final turn is what
	# the player hit and waiting for one to happen would make this probe
	# depend on the dice.
	if level.game.state != FarkleGame.State.FARKLED:
		level.game._farkle()
	# Through the real button. "Next turn" is what was pressed, and pressing it
	# is the whole of what went wrong.
	var roll : Button = level.find_child("RollButton", true, false)
	if roll == null:
		_fail("level %d: no Roll button to acknowledge the Farkle with" % level_number)
		return
	if roll.disabled:
		_fail("level %d: a Farkle on the last turn left every button dead" % level_number)
		return
	roll.pressed.emit()

func _dismiss_loadout(level : FarkleLevel) -> void:
	var window := level.find_child("LoadoutWindow", true, false)
	if window == null:
		return
	var start : Button = window.find_child("CloseButton", true, false)
	if start != null and not start.disabled:
		start.pressed.emit()

## The check that would have caught the frozen board.
func _check_window(level_number : int, via_farkle : bool, owned_before : int) -> void:
	var how := "after a Farkle" if via_farkle else "out of turns"
	var window := get_tree().root.find_child("LevelLostWindow", true, false)
	if window == null:
		_fail(
			("level %d %s: losing produced no window — the player is stranded"
			+ " on a dead board. Something in the loss handler threw before the"
			+ " window was made.") % [level_number, how]
		)
		return

	var button : Button = window.find_child("CloseButton", true, false)
	if button == null:
		_fail("level %d %s: the loss window has no button to leave by" % [level_number, how])
	elif button.pressed.get_connections().is_empty():
		_fail("level %d %s: the loss window's button is connected to nothing" % [level_number, how])

	# The window has to actually say what happened. This is the only way a probe
	# can see a script error inside the loss handler: GDScript errors cannot be
	# caught, and one that fires after the window is built leaves the window
	# looking fine while everything it was supposed to fill in never ran. Asserts
	# the observable outcome rather than the error.
	if not _describes_the_run(window):
		_fail(
			("level %d %s: the loss window still shows its placeholder text —"
			+ " whatever fills it in did not run") % [level_number, how]
		)

	var owned_after := GameState.get_dice_collection().total()
	if owned_after < owned_before:
		_fail("level %d %s: a loss took %d dice away"
			% [level_number, how, owned_before - owned_after])

	if _manager.get_checkpoint_level_path().is_empty():
		_fail("level %d %s: a lost run has nowhere to restart from" % [level_number, how])

## Whether the window says anything about the run that just ended. Reads the
## node rather than assuming its class — the description is a RichTextLabel, not
## a Label, which is exactly the assumption that broke the loss handler.
func _describes_the_run(window : Node) -> bool:
	var node := window.find_child("DescriptionLabel", true, false)
	if node == null:
		return false
	var shown := ""
	if node is RichTextLabel:
		shown = (node as RichTextLabel).text
	elif node is Label:
		shown = (node as Label).text
	return shown.contains("Run over")

## Windows are freed between levels rather than left to pile up, or the next
## level's check would find the previous level's window and pass on it.
func _clear_windows() -> void:
	var window := get_tree().root.find_child("LevelLostWindow", true, false)
	while window != null:
		window.get_parent().remove_child(window)
		window.queue_free()
		window = get_tree().root.find_child("LevelLostWindow", true, false)

func _find_level() -> FarkleLevel:
	if _manager.current_level is FarkleLevel:
		return _manager.current_level
	return get_tree().root.find_child("FarkleLevel", true, false)

func _fail(message : String) -> void:
	_failures.append(message)

func _report() -> void:
	print("")
	if _failures.is_empty():
		print("a lost run leaves the player a way out.")
		get_tree().quit(0)
		return
	for failure in _failures:
		print("  FAIL  %s" % failure)
	get_tree().quit(1)
