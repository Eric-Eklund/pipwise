extends Node
## Plays every shipped level scene through its own buttons.
##
##     godot --headless res://tools/playthrough_probe.tscn
##
## The engine suite proves the rules work. This proves the *scenes* do. It
## instantiates each level, drives it with the same bot the balance probe uses —
## but through the actual Take, Roll and Bank buttons — and checks that every run
## reaches a win or a loss without deadlocking.
##
## That is the failure this catches and nothing else can: a state where the rules
## are fine and every button happens to be disabled, so the player is stuck
## looking at a board they cannot act on. The headless tests will never see it,
## because they call the engine directly and never ask what the UI is offering.
##
## A scene rather than a `--script`, because the levels reach GameState on ready
## and the autoloads only exist when a scene is run.
##
## Development tool. Nothing in the game references it.

const LEVEL_DIR := "res://scenes/game_scene/levels"
const ENDLESS := "res://scenes/game_scene/levels/endless_level.tscn"
const SEEDS : Array[int] = [1, 2, 3, 7, 11]
## A level is five turns of a handful of rolls. Anything approaching this is a
## loop that is not going to end on its own.
const MAX_STEPS := 3000

var _failures : Array[String] = []

func _ready() -> void:
	for level in range(1, 11):
		await _play_scene("%s/level_%d.tscn" % [LEVEL_DIR, level], "level %d" % level)
	await _play_scene(ENDLESS, "endless")

	print("")
	if _failures.is_empty():
		print("every level scene played to a verdict, through its own buttons.")
		get_tree().quit(0)
	else:
		for failure in _failures:
			print("  FAIL  %s" % failure)
		get_tree().quit(1)

func _play_scene(path : String, label : String) -> void:
	var packed : PackedScene = load(path)
	if packed == null:
		_failures.append("%s: cannot load %s" % [label, path])
		return

	var wins := 0
	for seed_value in SEEDS:
		var scene := packed.instantiate()
		if not scene is FarkleLevel:
			_failures.append("%s: not a FarkleLevel" % label)
			return
		var level := scene as FarkleLevel
		level.rng_seed = seed_value
		add_child(level)
		await get_tree().process_frame
		_dismiss_loadout(level)
		await get_tree().process_frame

		var outcome := _drive(level)
		if outcome == "won":
			wins += 1
		elif outcome != "lost":
			_failures.append("%s seed %d: %s" % [label, seed_value, outcome])
		remove_child(level)
		level.queue_free()

	print("  %-10s %d/%d cleared" % [label, wins, SEEDS.size()])

## Presses Start on the loadout screen, which levels 1, 5 and 10 open before the
## round begins.
##
## Goes through the real button rather than calling the level's handler, because
## the thing worth catching here is a loadout screen that cannot be dismissed —
## if the preselected dice ever failed to add up to six, Start would be disabled
## and the player would be stuck on a screen with no way out. That is exactly the
## kind of dead end this probe exists for, and _drive() would only report "no
## game" without saying why.
func _dismiss_loadout(level : FarkleLevel) -> void:
	var window := level.find_child("LoadoutWindow", true, false)
	if window == null:
		return
	var start : Button = window.find_child("CloseButton", true, false)
	if start == null or start.disabled:
		return
	start.pressed.emit()

## The bot, pressing buttons instead of calling the engine. Deliberately greedy
## and dumb — it takes whatever is offered and banks the moment it can, which
## makes the clear rates here a lower bound and not a balance measurement. Use
## tools/balance_probe.gd for that.
func _drive(level : FarkleLevel) -> String:
	var take : Button = level.find_child("TakeButton", true, false)
	var roll : Button = level.find_child("RollButton", true, false)
	var bank : Button = level.find_child("BankButton", true, false)
	if take == null or roll == null or bank == null:
		return "buttons missing"

	for _step in MAX_STEPS:
		var game := level.game
		if game == null:
			return "no game — are the autoloads loaded?"
		match game.state:
			FarkleGame.State.WON:
				return "won"
			FarkleGame.State.LOST:
				return "lost"
			FarkleGame.State.FARKLED:
				roll.pressed.emit()
				continue
			_:
				pass

		if not take.disabled:
			take.pressed.emit()
		elif not bank.disabled:
			bank.pressed.emit()
		elif not roll.disabled:
			roll.pressed.emit()
		else:
			return "deadlocked on turn %d — every button disabled" % game.context.turn
	return "did not reach a verdict in %d steps" % MAX_STEPS
