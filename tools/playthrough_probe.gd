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
## It also watches how wide the board asks to be. A board that asks for more
## width than the screen has is given it — Godot grows a Control to its minimum
## size whatever its anchors say — and a full-rect Control that has outgrown its
## parent is centred on it, so the whole layout ends up hanging off both edges
## with the dice half off the screen. Nothing else here would notice: the rules
## are fine, every button works, and the game is simply drawn somewhere the
## player cannot reach. See _check_width().
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
## The width every size in the project is drawn against. Read from the project
## rather than from the window, because a headless run gets whatever window the
## platform felt like giving it and the answer has to be the phone's.
var _design_width : float = float(
	ProjectSettings.get_setting("display/window/size/viewport_width", 540)
)

func _ready() -> void:
	# The probe measures widths, so it has to lay the levels out at the size the
	# game ships at rather than at whatever a headless window defaults to.
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = Vector2i(
		int(_design_width),
		int(ProjectSettings.get_setting("display/window/size/viewport_height", 960))
	)
	window.size = window.content_scale_size
	await get_tree().process_frame

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
## and dumb — it takes whatever is offered, plays whatever it can afford and
## banks the moment it can, which makes the clear rates here a lower bound and
## not a balance measurement. Use tools/balance_probe.gd for that.
##
## It plays cards because the hand is the one thing on the board that changes
## shape: cards are spent and drawn, and the row is rebuilt around whatever is
## left. A bot that only pressed Take, Roll and Bank would play every level with
## the hand it started with and never see the row redrawn at all.
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
		var too_wide := _check_width(level)
		if not too_wide.is_empty():
			return too_wide
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

		if _play_a_card(level):
			continue
		if not take.disabled:
			take.pressed.emit()
		elif not bank.disabled:
			bank.pressed.emit()
		elif not roll.disabled:
			roll.pressed.emit()
		else:
			return "deadlocked on turn %d — every button disabled" % game.context.turn
	return "did not reach a verdict in %d steps" % MAX_STEPS

## Presses the first card the row is offering, and says whether it pressed one.
## Through the button like everything else here: a card the engine would allow
## but the row draws as greyed out is exactly the kind of gap this probe is for.
func _play_a_card(level : FarkleLevel) -> bool:
	var row : Control = level.find_child("CardRow", true, false)
	if row == null or not row.visible:
		return false
	for view in row.find_children("*", "Button", true, false):
		var button := view as Button
		if not button.disabled:
			button.pressed.emit()
			return true
	return false

## Whether the board is asking for more room than the screen has.
##
## Checked on the minimum size rather than on the drawn size, because the minimum
## is what does the damage and it is computed on demand — this loop presses
## buttons without waiting for frames, so the drawn sizes are a layout pass or
## two behind while the minimums are current.
##
## Only the width. The height is allowed to run over: the stretch is 540 wide and
## as tall as the phone, so the board is measured against a height nobody knows.
func _check_width(level : FarkleLevel) -> String:
	var board : Control = level.find_child("Board", true, false)
	if board == null:
		return ""
	var wanted := board.get_combined_minimum_size().x
	if wanted <= _design_width:
		return ""
	return "board wants %.0fpx of a %.0fpx screen — %s" % [
		wanted, _design_width, _widest_child(board)
	]

## Names what is doing the asking, so a failure points at a row rather than at
## the board as a whole.
func _widest_child(board : Control) -> String:
	var worst := ""
	var worst_width := 0.0
	for node in board.find_children("*", "Control", true, false):
		var child := node as Control
		var width := child.get_combined_minimum_size().x
		if width > worst_width:
			worst_width = width
			worst = "%s wants %.0f" % [child.name, width]
	return worst if not worst.is_empty() else "nothing in it admits to it"
