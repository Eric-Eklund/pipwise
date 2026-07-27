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

## Muted grey for the always-on hint lines and for a hand not worth pointing at.
const HINT_COLOR := Color(0.55, 0.58, 0.64)

## Shown once, the first time this level is reached. Only level 1 has one.
@export var tutorial_scene : PackedScene
## Opened by the HUD's ? button: the nine hands and what each pays here.
@export var hand_guide_scene : PackedScene

var game : CardDiceGame

@onready var _hand_view : HandView = %HandView
@onready var _dice_tray : DiceTray = %DiceTray
@onready var _score_hud : ScoreHud = %ScoreHud
@onready var _energy_hud : EnergyHud = %EnergyHud
@onready var _hand_name_label : Label = %HandNameLabel
@onready var _card_hint_label : Label = %CardHintLabel
@onready var _swap_button : Button = %SwapButton
@onready var _reroll_button : Button = %RerollButton
@onready var _save_button : Button = %SaveButton

func _ready() -> void:
	super()
	_hand_view.card_pressed.connect(_on_card_pressed)
	_dice_tray.die_pressed.connect(_on_die_pressed)
	_score_hud.guide_requested.connect(_on_guide_requested)
	start_round(_get_ruleset())
	_show_tutorial_once()

## The guide is built from this level's own evaluator and context, so a boss's
## bans and bonuses show up in it rather than a generic table that quietly lies
## on level 15.
func _on_guide_requested() -> void:
	if hand_guide_scene == null:
		return
	var guide := hand_guide_scene.instantiate()
	add_child(guide)
	guide.show_hands(game.ruleset.get_evaluator(), game.context)

## Opens the walkthrough the first time this level is played, then never again.
## LevelState.tutorial_read has been in the save file since the template and has
## never been used for anything.
func _show_tutorial_once() -> void:
	if tutorial_scene == null or level_state == null or level_state.tutorial_read:
		return
	level_state.tutorial_read = true
	GlobalState.save()
	var window := tutorial_scene.instantiate()
	add_child(window)

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
	_refresh_hints()
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
	# What the cards are worth changed, so who is framed may have changed too.
	_hand_view.refresh_state()
	_refresh_hand_name()

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

## Names the hand directly under the cards, in the same colour the framed cards
## are drawn in, so the frame and the name read as one statement. That includes
## a high card: exactly one card is framed then, and the label has to agree with
## it rather than quietly disowning it.
func _refresh_hand_name() -> void:
	var score := game.preview
	if score == null:
		return
	_hand_name_label.text = "%s  %s" % [score.label, score.multiplier_text()]
	_hand_name_label.add_theme_color_override(&"font_color", _scoring_color())

## Reads the colour off the card skin so the label can never drift from the
## frames it is describing.
func _scoring_color() -> Color:
	var view := _hand_view.get_card_view()
	if view != null and view.skin != null:
		return view.skin.scoring_border_color
	return HINT_COLOR

## The swap price comes from the ruleset rather than the scene text, so a level
## that changes it does not leave the hint lying. The other hints carry no
## numbers and stay in the scene where they can be edited without code.
func _refresh_hints() -> void:
	_card_hint_label.text = "Tap cards to mark them, then Swap  ·  %d⚡ each" % game.swap_cost()

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
