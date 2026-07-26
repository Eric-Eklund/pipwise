class_name CardDiceLevel
extends Level
## A level driven by a Ruleset.
##
## Owns none of the rules itself — it wires CardDiceGame to the views and
## translates the engine's outcome into the level_won/level_lost signals that
## LevelManager duck-types onto. Designing a level means editing its Ruleset
## resource, not this script.

@export var ruleset : Ruleset
## Non-zero reproduces the same shuffle and rolls every run. Handy while testing.
@export var rng_seed : int = 0

var game : CardDiceGame

@onready var _hand_view : HandView = %HandView
@onready var _dice_tray : DiceTray = %DiceTray
@onready var _score_hud : ScoreHud = %ScoreHud
@onready var _play_button : Button = %PlayButton

func _ready() -> void:
	super()
	game = CardDiceGame.new(_get_ruleset(), RngService.new(rng_seed))

	_hand_view.bind_hand(game.context.hand)
	_hand_view.card_pressed.connect(_on_card_pressed)
	_dice_tray.die_pressed.connect(_on_die_pressed)
	_score_hud.bind_game(game)

	game.dice_changed.connect(_on_dice_changed)
	game.progress_changed.connect(_refresh_interactables)
	game.game_won.connect(_on_game_won)
	game.game_lost.connect(_on_game_lost)
	# Most die actions need cards picked first, so what is usable changes with
	# the selection, not just with the turn.
	game.context.hand.changed.connect(_refresh_interactables)
	game.context.hand.selection_changed.connect(_refresh_interactables)

	game.start()

## Falls back to defaults so the level still runs before a Ruleset is authored.
func _get_ruleset() -> Ruleset:
	return ruleset if ruleset != null else Ruleset.new()

func _on_dice_changed(dice : Array[Die]) -> void:
	_dice_tray.show_dice(dice)
	_refresh_interactables()

func _refresh_interactables() -> void:
	_dice_tray.refresh_state(game.context)
	_play_button.disabled = not game.can_play()

func _on_card_pressed(card : Card) -> void:
	game.context.hand.toggle_selection(card)

func _on_die_pressed(die : Die) -> void:
	game.spend_die(die)

func _on_play_button_pressed() -> void:
	game.play_selected()

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
