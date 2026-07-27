class_name CardDiceLevel
extends Level
## A level driven by a Ruleset.
##
## Owns none of the rules itself — it wires CardDiceGame to the views and
## translates the engine's outcome into the level_won/level_lost signals that
## LevelManager duck-types onto. Designing a level means editing its Ruleset
## resource, not this script.

## Which level of the campaign this is. Every level scene sets only this; the
## Campaign works out the rest, and hands over an authored ruleset for the
## levels that have one.
@export_range(1, 200) var level_number : int = 1
@export var campaign : Campaign
## Overrides the campaign entirely. Left null on the shipped levels.
@export var ruleset : Ruleset
## Non-zero reproduces the same shuffle and rolls every run. Handy while testing.
@export var rng_seed : int = 0

var game : CardDiceGame

@onready var _hand_view : HandView = %HandView
@onready var _dice_tray : DiceTray = %DiceTray
@onready var _score_hud : ScoreHud = %ScoreHud
@onready var _energy_hud : EnergyHud = %EnergyHud
@onready var _swap_button : Button = %SwapButton
@onready var _reroll_button : Button = %RerollButton
@onready var _save_button : Button = %SaveButton

func _ready() -> void:
	super()
	_hand_view.card_pressed.connect(_on_card_pressed)
	_dice_tray.die_pressed.connect(_on_die_pressed)
	start_round(_get_ruleset())

## Builds a fresh game and puts it on screen. Separate from _ready() because
## endless mode plays round after round in the same scene, and everything here
## has to survive being done again.
##
## The old CardDiceGame is a RefCounted with nothing else holding it, so its
## signal connections die with it and do not need unhooking.
func start_round(round_ruleset : Ruleset) -> void:
	game = CardDiceGame.new(round_ruleset, RngService.new(rng_seed))

	_hand_view.bind_hand(game.context.hand)
	_score_hud.bind_game(game)
	_energy_hud.bind_game(game)

	game.dice_changed.connect(_on_dice_changed)
	game.progress_changed.connect(_refresh_interactables)
	game.energy_changed.connect(_refresh_interactables)
	game.game_won.connect(_on_game_won)
	game.game_lost.connect(_on_game_lost)
	# What the player can afford depends on how many cards they have marked, so
	# the buttons change with the selection, not only with the dice.
	game.context.hand.changed.connect(_refresh_interactables)
	game.context.hand.selection_changed.connect(_refresh_interactables)

	_dice_tray.show_dice(game.get_dice())
	game.start()

## An explicit ruleset wins, then the campaign, then bare defaults — so the
## level still runs even if a scene is dropped in with nothing configured.
func _get_ruleset() -> Ruleset:
	if ruleset != null:
		return ruleset
	if campaign != null:
		return campaign.get_ruleset(level_number)
	return Ruleset.new()

func _on_dice_changed() -> void:
	_refresh_interactables()

func _refresh_interactables() -> void:
	_dice_tray.refresh_state(game)

	var swap_count := game.context.hand.selected_count()
	_swap_button.disabled = not game.can_swap_selected()
	if swap_count == 0:
		_swap_button.text = "Swap cards"
	else:
		_swap_button.text = "Swap %d  %d⚡" % [swap_count, game.selected_swap_cost()]

	_reroll_button.disabled = not game.can_reroll()
	_reroll_button.text = "Reroll  %d left" % game.rerolls_left()

	_save_button.disabled = not game.can_save_hand()
	var requirement := game.get_save_requirement_text()
	if requirement.is_empty():
		_save_button.text = "Save hand  %d" % game.context.score
	else:
		_save_button.text = requirement

func _on_card_pressed(card : Card) -> void:
	game.context.hand.toggle_selection(card)

## Tapping a die is how the player pays to keep it through the next reroll.
func _on_die_pressed(die : Die) -> void:
	game.toggle_lock(die)

func _on_swap_button_pressed() -> void:
	game.swap_selected()

func _on_reroll_button_pressed() -> void:
	if game.reroll():
		_dice_tray.play_roll()

func _on_save_button_pressed() -> void:
	game.save_hand()

func _on_game_won() -> void:
	_record_result(true)
	win()

func _on_game_lost() -> void:
	_record_result(false)
	lose()

## Persists the run so level select and progression have something to read.
func _record_result(completed : bool) -> void:
	if level_state == null:
		return
	level_state.best_score = maxi(level_state.best_score, game.context.score)
	if completed:
		level_state.completed = true
	GlobalState.save()
