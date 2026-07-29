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
## Two more things it watches, both of them things only a scene can be wrong
## about. The hand is tapped through the input system rather than by emitting
## `pressed`, so a card that is drawn where no finger can reach it fails here
## instead of shipping — see _play_a_card(). And the energy the row shows is
## compared against the energy the turn holds, because that number is written
## by a view and read by nobody else, so it can drift from the engine without a
## single test noticing — see _check_energy(). And holding a card down has to
## open its detail window even when the card is greyed out, which is the only
## place the game says *why* it is greyed out — see _check_card_hold().
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
## Windows the level may stack over the board before a round starts. Two today —
## the loadout and the walkthrough behind it — with room for a third.
const MAX_OVERLAYS := 4
## Fixes the run's cards. Any value; what matters is that it is the same one on
## every machine, so a card-dependent failure reproduces off a git checkout.
const DECK_SEED := 4242

var _failures : Array[String] = []
## The width every size in the project is drawn against. Read from the project
## rather than from the window, because a headless run gets whatever window the
## platform felt like giving it and the answer has to be the phone's.
var _design_width : float = float(
	ProjectSettings.get_setting("display/window/size/viewport_width", 540)
)
## What CardRow writes when there is anything left to spend. Built once: this is
## read on every step of every run.
var _energy_text := RegEx.create_from_string("(\\d+) of (\\d+)")

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
	_reset_save()
	await get_tree().process_frame

	await _check_card_hold()

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

## Holding a card down has to open its detail window, and a greyed out card most
## of all — that window carries the only sentence in the game that says why a
## card will not go, and a player who cannot reach it is left with a dim
## rectangle and no explanation.
##
## Worth a check of its own because Godot ignores input on a disabled Button:
## the hold is timed off _gui_input for exactly that reason, and a later hand
## that moved it to button_down would break the greyed case only — the case
## nobody tests by hand, because bright cards are the ones you reach for.
##
## Run once, on level 1. It costs a real second of waiting, and the affordance
## is the same on every level.
func _check_card_hold() -> void:
	var packed : PackedScene = load("%s/level_1.tscn" % LEVEL_DIR)
	var level := packed.instantiate() as FarkleLevel
	level.rng_seed = 3
	add_child(level)
	await get_tree().process_frame
	await _dismiss_overlays(level, "card hold")
	await get_tree().process_frame
	await get_tree().process_frame

	var row : Control = level.find_child("CardRow", true, false)
	var target : Button = null
	var greyed := false
	for view in row.find_children("*", "Button", true, false):
		var button := view as Button
		# A refused card first, an offered one only as a fallback: the hand is
		# dealt from a seeded deck and need not contain one of each.
		if button.disabled and not greyed:
			target = button
			greyed = true
		elif target == null:
			target = button

	if target == null:
		_failures.append("card hold: the hand drew no cards to hold")
	else:
		var spent_before := level.game.context.energy_spent
		await _hold(target)
		if level.find_child("CardDetailWindow", true, false) == null:
			_failures.append("card hold: holding %s opened no window (greyed: %s)" % [
				target.card.display_name, greyed
			])
		elif level.game.context.energy_spent != spent_before:
			# A press is either a tap or a hold. Paying for the card *and*
			# opening its window is two actions bought with one finger.
			_failures.append("card hold: holding %s also played it" % target.card.display_name)
		else:
			print("  %-10s held %s, window opened, card not spent" % [
				"card hold", target.card.display_name
			])

	remove_child(level)
	level.queue_free()

## Presses, waits past the hold threshold, and releases — at the control's own
## rect, like every other press this probe makes.
func _hold(button : Button) -> void:
	var at := button.get_global_rect().get_center()
	_touch(at, true)
	await get_tree().create_timer(CardView.HOLD_TIME + 0.2).timeout
	_touch(at, false)
	await get_tree().process_frame

## A finger rather than the mouse event _tap() sends. The hold is the one thing
## here that reads raw input itself, so it is worth pushing the event an actual
## phone pushes.
func _touch(at : Vector2, down : bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.position = at
	touch.pressed = down
	get_viewport().push_input(touch)

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
		await _dismiss_overlays(level, "%s seed %d" % [label, seed_value])
		await get_tree().process_frame

		var outcome := await _drive(level)
		if outcome == "won":
			wins += 1
		elif outcome != "lost":
			_failures.append("%s seed %d: %s" % [label, seed_value, outcome])
		remove_child(level)
		level.queue_free()

	print("  %-10s %d/%d cleared" % [label, wins, SEEDS.size()])

## Puts the save back to what a phone with the game freshly installed holds.
##
## GameState is a resource that persists to disk, and the levels write to it as
## they play: the hand after every card, the collection after every win, and
## whether the walkthrough has been read. So the second run of this probe played
## level 1 with the hand the first one left behind, and CI — a fresh checkout
## with no save file at all — played something different again. A probe whose
## answer depends on what ran before it cannot be used to decide anything, and
## the two disagreed for an afternoon before anyone noticed they were even
## different questions.
func _reset_save() -> void:
	var state := GameState.get_or_create_state()
	if state == null:
		return
	state.run = _seeded_run()
	state.loadout = []
	state.dice_collection = DiceCollection.create_starting()
	# The walkthrough included. It is the one thing here that puts a window over
	# the board, so leaving it read would hide the case a fresh install hits.
	state.level_states = {}
	GlobalState.save()

## A run whose cards are the same ones every time.
##
## RunState.create() seeds itself from an unseeded RngService, on purpose — two
## attempts at the campaign should not deal the same hand. But it means every
## execution of this probe played with different cards, so a failure that needed
## a particular card to be in hand at a particular level appeared once and then
## could not be reproduced. That is how the Nature loop hid: it wanted Earth
## Restore still unspent by level 7.
##
## Built through the same public calls create() makes rather than by changing its
## signature, which a test in test_run_state.gd pins for an unrelated and better
## reason — a run that can be handed a starting point is a run that can be
## resumed.
func _seeded_run() -> RunState:
	var rng := RngService.new(DECK_SEED)
	var run := RunState.create()
	run.deck_seed = DECK_SEED
	run.store_hand(CardHand.create(rng))
	return run

## Closes whatever the level put over the board before the round starts: the
## loadout screen on levels 1, 5 and 10, and the walkthrough on level 1 behind
## it. Both are GameOverlays with one close button.
##
## Goes through the real button rather than calling close(), because a window
## that cannot be dismissed is exactly the dead end this probe exists for — if
## the preselected dice ever failed to add up to six, Start would be disabled and
## the player would be stuck on a screen with no way out, and _drive() would only
## report "no game" without saying why.
##
## In a loop because they stack: dismissing the loadout is what opens the
## walkthrough behind it. Leaving one up is not cosmetic here — the probe taps
## the hand at real coordinates, and a full-screen overlay eats the tap. That is
## how this was found: on a fresh save the walkthrough covered the board, the
## tap landed on it, and the probe correctly reported a card nobody could reach.
func _dismiss_overlays(level : FarkleLevel, label : String) -> void:
	for _pass in MAX_OVERLAYS:
		var window := _open_overlay(level)
		if window == null:
			return
		var close : Button = window.find_child("CloseButton", true, false)
		if close == null:
			_failures.append("%s: %s has no way out" % [label, window.name])
			return
		if close.disabled:
			_failures.append("%s: %s cannot be closed" % [label, window.name])
			return
		close.pressed.emit()
		await get_tree().process_frame
	_failures.append("%s: windows kept opening over the board" % label)

func _open_overlay(level : FarkleLevel) -> Control:
	for child in level.get_children():
		if child is GameOverlay and (child as Control).visible:
			return child as Control
	return null

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
		var bad_energy := _check_energy(level)
		if not bad_energy.is_empty():
			return bad_energy
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

		var card_result := await _play_a_card(level)
		if card_result == "played":
			continue
		if not card_result.is_empty():
			return card_result
		if not take.disabled:
			take.pressed.emit()
		elif not bank.disabled:
			bank.pressed.emit()
		elif not roll.disabled:
			roll.pressed.emit()
		else:
			return "deadlocked on turn %d — every button disabled" % game.context.turn
	return "did not reach a verdict in %d steps" % MAX_STEPS

## Taps the first card the row is offering. Returns "played" if one went, "" if
## there was nothing to play, and a failure otherwise.
##
## ## Why this one goes through the input system
##
## Every other press here is pressed.emit(), which reaches the handler without
## ever asking whether the button could be *hit*. That is enough for Take, Roll
## and Bank: they are authored in the scene, in fixed places, and a press that
## could not land would have to be a regression in the level layout.
##
## The hand is not. Its buttons are built in code and rebuilt whenever a card is
## spent or drawn, so their rects come from a container that re-sorts under them
## — and a card drawn in the right place that no finger can reach looks, to the
## player, exactly like a card that does nothing. pressed.emit() cannot tell the
## two apart and would pass either way. This aims a real event at the button's
## own rect and then checks the turn actually paid for it.
##
## A mouse event rather than a touch one: Godot emulates touch onto this handler,
## so both arrive by the same route and the hit test is the one a finger takes.
## What this proves is that the button is reachable where it is drawn, not
## anything touch-specific.
func _play_a_card(level : FarkleLevel) -> String:
	var row : Control = level.find_child("CardRow", true, false)
	if row == null or not row.visible:
		return ""
	var button := _first_playable_card(row)
	if button == null:
		return ""

	# The row is rebuilt whenever the hand changes, and a freshly built button
	# has no rect until its container has sorted. Aiming at a rect means waiting
	# for one, which pressed.emit() never had to do.
	await get_tree().process_frame
	if not is_instance_valid(button) or button.disabled:
		return ""

	# Energy rather than the hand size, because the hand is not a reliable
	# witness: Draw 2 discards one card and draws two, so a full hand is the
	# same size afterwards. Every card costs something, and nothing else in a
	# turn spends energy.
	var spent_before := level.game.context.energy_spent
	var at := button.get_global_rect().get_center()
	_tap(at)
	if level.game.context.energy_spent != spent_before:
		return "played"

	# The tap did not land. Fall through to the handler so the run still reaches
	# a verdict and the rest of the level is still covered — but say so, because
	# a card that answers its handler and not its own rect is either a button
	# nobody can reach or a probe that cannot reach one, and both want a human.
	button.pressed.emit()
	if level.game.context.energy_spent == spent_before:
		return "the row drew a card as playable that the game then refused"
	return "a card answered pressed() but not a tap at %s" % at

func _first_playable_card(row : Control) -> Button:
	for view in row.find_children("*", "Button", true, false):
		var button := view as Button
		if not button.disabled:
			return button
	return null

## Aims a press and a release at [param at]. Both are needed: a Button fires on
## release by default, and a release on its own is not a press.
func _tap(at : Vector2) -> void:
	for is_down in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = is_down
		click.position = at
		click.global_position = at
		get_viewport().push_input(click)

## Whether the energy the row is showing is the energy the turn actually has.
##
## The number is written by the row and read by nobody else, so no test that
## talks to the engine can see it drift — and it did: the budget is taken after
## the roll that refreshes the row, so from turn 2 on the player was choosing
## cards against the previous turn's figure.
func _check_energy(level : FarkleLevel) -> String:
	var label : Label = level.find_child("EnergyLabel", true, false)
	if label == null or not label.is_visible_in_tree():
		return ""
	# Only while the level is still being played. A won or lost level has
	# advanced its turn counter past the end without beginning a turn, so no
	# budget was ever taken for the turn the context now names — and the row is
	# behind the outcome window by then anyway, on a board nobody will touch.
	if level.game.state != FarkleGame.State.CHOOSING \
			and level.game.state != FarkleGame.State.FARKLED:
		return ""
	var context := level.game.context
	var numbers := _energy_text.search(label.text)
	if numbers == null:
		# The other thing the row ever says. It has to mean what it says.
		if context.available_energy() > 0:
			return "the row says \"%s\" with %d energy left" % [
				label.text, context.available_energy()
			]
		return ""
	var shown_left := int(numbers.get_string(1))
	var shown_total := int(numbers.get_string(2))
	if shown_left == context.available_energy() and shown_total == context.total_energy():
		return ""
	return "the row shows %d of %d energy on turn %d, the turn has %d of %d" % [
		shown_left, shown_total, context.turn,
		context.available_energy(), context.total_energy()
	]

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
