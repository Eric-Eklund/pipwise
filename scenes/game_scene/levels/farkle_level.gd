class_name FarkleLevel
extends Level
## A level driven by a Ruleset.
##
## Owns none of the rules itself — it wires FarkleGame to the views and
## translates the engine's outcome into the level_won/level_lost signals that
## LevelManager duck-types onto. Designing a level means editing its Ruleset,
## not this script.
##
## ## Three buttons, one at a time
##
## Take, Roll and Bank are always all on screen and mostly disabled, rather than
## swapping in and out. A button that moves is a button you have to find again,
## and this game is played with a thumb: the same three targets stay in the same
## three places all the way through a turn, and only their labels change.

## Muted grey for the always-on hint line.
const HINT_COLOR := Color(0.55, 0.58, 0.64)
const FARKLE_COLOR := Color(0.90, 0.44, 0.36)
## Brighter than the standing hint, because the line it carries is the one thing
## on screen the player cannot work out by looking at the dice.
const COMBO_HINT_COLOR := Color(0.70, 0.53, 1.0)

## Which level of the campaign this is. Every level scene sets only this; the
## Campaign works out the rest.
@export_range(1, 200) var level_number : int = 1
@export var campaign : Campaign
## Overrides the campaign entirely. Left null on the shipped levels.
@export var ruleset : Ruleset
## Non-zero reproduces the same rolls every run. Handy while testing.
@export var rng_seed : int = 0

## Shown once, the first time this level is reached. Only level 1 has one.
@export var tutorial_scene : PackedScene
## Opened by the HUD's ? button: what scores and what the elements do.
@export var guide_scene : PackedScene
## Shown at the start of a run and before each boss: pick the six dice.
@export var loadout_scene : PackedScene

var game : FarkleGame

## A one-off message that outranks the standing hint until the player does
## something. Hot dice and Farkles both announce themselves in the middle of a
## chain of signals that ends in a refresh, so without somewhere to survive that
## refresh the message would be written and overwritten in the same frame.
var _notice : String = ""
var _notice_color : Color = HINT_COLOR

@onready var _board : Control = %Board
@onready var _dice_tray : DiceTray = %DiceTray
@onready var _score_hud : ScoreHud = %ScoreHud
@onready var _banner : ScoreBanner = %ScoreBanner
@onready var _effects : BoardEffects = %BoardEffects
@onready var _sounds : BoardSounds = %BoardSounds
@onready var _hint_label : Label = %HintLabel
@onready var _take_button : Button = %TakeButton
@onready var _roll_button : Button = %RollButton
@onready var _bank_button : Button = %BankButton

func _ready() -> void:
	super()
	_dice_tray.die_pressed.connect(_on_die_pressed)
	_score_hud.guide_requested.connect(_on_guide_requested)
	# The banner parks itself above the tray, and the tray moves whenever the
	# set aside row appears or the window changes shape.
	_dice_tray.resized.connect(_place_banner)
	_effects.bind_board(_board)
	# The round waits for the loadout when there is one to choose. Rolling first
	# and re-rolling afterwards would work, but the player would hear the dice
	# land behind the dim and watch the board rebuild itself the moment they
	# pressed Start.
	if not _offer_loadout():
		start_round(_get_ruleset())
		_show_tutorial_once()

## Builds a fresh game and puts it on screen. Separate from _ready() because
## endless mode plays round after round in the same scene, so everything here
## has to survive being done again.
##
## The old FarkleGame is a RefCounted with nothing else holding it, so its
## signal connections die with it and do not need unhooking.
func start_round(round_ruleset : Ruleset) -> void:
	game = FarkleGame.new(round_ruleset, RngService.new(rng_seed))

	_score_hud.bind_game(game)
	game.dice_changed.connect(_refresh)
	game.selection_changed.connect(_refresh)
	game.score_changed.connect(_refresh)
	game.rolled.connect(_on_rolled)
	game.took.connect(_on_took)
	game.banked.connect(_on_banked)
	game.farkled.connect(_on_farkled)
	game.hot_dice.connect(_on_hot_dice)
	game.turn_started.connect(_on_turn_started)
	game.level_won.connect(_on_level_won)
	game.level_lost.connect(_on_level_lost)

	_dice_tray.show_dice(game.get_dice())
	game.start()
	_refresh()

## An explicit ruleset wins, then the campaign, then bare defaults — so a scene
## dropped in with nothing configured still runs.
##
## The campaign is handed the saved loadout. Null means nothing has been equipped
## yet, and the level falls back to the bag its target was measured against,
## which is exactly what the balance probe and the tests play.
func _get_ruleset() -> Ruleset:
	if ruleset != null:
		return ruleset
	if campaign != null:
		return campaign.get_ruleset(level_number, GameState.get_loadout_bag())
	return Ruleset.new()

# --- loadout ----------------------------------------------------------------

## Opens the loadout screen where a choice is worth making, and returns whether
## it did. Which levels those are is the campaign's call — see
## Campaign.offers_a_loadout().
func _offer_loadout() -> bool:
	if loadout_scene == null or campaign == null:
		return false
	if not campaign.offers_a_loadout(level_number):
		return false

	# The board is hidden, not merely dimmed. Its labels still carry the scene's
	# authored placeholders until start_round runs, and a target of "1900"
	# showing through behind the loadout is a number the player will believe.
	_board.visible = false

	var window := loadout_scene.instantiate()
	add_child(window)
	window.loadout_chosen.connect(_on_loadout_chosen)
	window.show_loadout(GameState.get_dice_collection(), campaign.reference_bag_for(level_number))
	return true

func _on_loadout_chosen(elements : Array[StringName]) -> void:
	GameState.set_loadout(elements)
	_board.visible = true
	start_round(_get_ruleset())
	_show_tutorial_once()

# --- input ------------------------------------------------------------------

func _on_die_pressed(die : Die) -> void:
	game.toggle_selection(die)

func _on_take_button_pressed() -> void:
	_clear_notice()
	# Nothing marked means "take everything that scores", which is what the
	# player wants almost every time and saves six taps when they do.
	if game.get_selection().is_empty():
		game.select_all_scoring()
	game.commit_selection()

func _on_roll_button_pressed() -> void:
	# The same button acknowledges a Farkle and pushes, because in both cases it
	# is the only thing left to do and the thumb is already there.
	if game.state == FarkleGame.State.FARKLED:
		_clear_notice()
		game.continue_after_farkle()
		return
	_clear_notice()
	if game.push():
		_dice_tray.play_roll()

func _on_bank_button_pressed() -> void:
	_clear_notice()
	game.bank()

# --- feedback ---------------------------------------------------------------

func _on_rolled() -> void:
	_dice_tray.play_roll()
	_sounds.play_roll()

func _on_turn_started(_turn : int) -> void:
	_clear_notice()
	_refresh()

## The dice burst in their own element colour and the board takes a knock whose
## size is the size of the score. A 100-point take should not feel like a
## 3000-point one, and this is the cheapest place to say so.
func _on_took(score : DiceScore, dice : Array[Die]) -> void:
	_dice_tray.play_take(dice)
	_banner.show_score(score)
	_effects.shake(_shake_for(score.total()))
	_sounds.play_take(score.total(), _expected_per_turn(), score.combo_count)

func _on_banked(points : int) -> void:
	_banner.show_banked(points)
	_sounds.play_bank()

func _on_hot_dice() -> void:
	_set_notice("Hot dice — all six back, points intact", HINT_COLOR)
	_banner.show_hot_dice()
	_effects.shake(BoardEffects.MEDIUM)
	_effects.flash(ScoreBanner.HOT_COLOR, 0.16)
	_sounds.play_hot_dice()

func _on_farkled(points_lost : int) -> void:
	if points_lost > 0:
		_set_notice("Farkle — %d points gone" % points_lost, FARKLE_COLOR)
	else:
		_set_notice("Farkle — nothing scored", FARKLE_COLOR)
	_banner.show_farkle(points_lost)
	_effects.shake(BoardEffects.HARD)
	_effects.flash(FARKLE_COLOR)
	_sounds.play_farkle()
	_refresh()

## What one turn of this level is expected to be worth. Both the shake and the
## take sound scale against it rather than against a fixed number, so a big take
## feels big on level 1 and on level 9 alike — the raw scores differ by an order
## of magnitude between them.
func _expected_per_turn() -> float:
	var target := game.ruleset.get_target_score()
	return maxf(1.0, float(target) / float(maxi(1, game.ruleset.turns)))

func _shake_for(points : int) -> float:
	return clampf(
		BoardEffects.SOFT + float(points) / _expected_per_turn() * BoardEffects.MEDIUM,
		BoardEffects.SOFT,
		BoardEffects.HARD
	)

func _set_notice(text : String, color : Color) -> void:
	_notice = text
	_notice_color = color
	_show_hint(text, color)

func _clear_notice() -> void:
	_notice = ""

func _show_hint(text : String, color : Color) -> void:
	_hint_label.text = text
	_hint_label.add_theme_color_override(&"font_color", color)

# --- buttons ----------------------------------------------------------------

func _refresh() -> void:
	_dice_tray.refresh_state(game)
	_place_banner()
	_refresh_buttons()
	_refresh_hint()

## Keeps the banner sitting just above the dice. The tray is inside a container
## and the banner is not, so the only thing that can relate them is this.
func _place_banner() -> void:
	_banner.follow(_dice_tray)

func _refresh_buttons() -> void:
	var farkled := game.state == FarkleGame.State.FARKLED

	_take_button.disabled = farkled or not _can_take()
	_take_button.text = _take_text()

	_roll_button.disabled = not farkled and not game.can_push()
	_roll_button.text = _farkle_button_text() if farkled else "Roll again"

	_bank_button.disabled = farkled or not game.can_bank()
	_bank_button.text = _bank_text()

## What acknowledging a Farkle actually does. On the last turn it does not start
## another one — it ends the level — and the button said "Next turn" anyway. A
## button that names a turn the player is not going to get is the game lying at
## the exact moment they most need to know where they stand.
##
## Read off the turn count rather than off the score, because Farkle has no
## points ceiling: with a turn left, no deficit is provably out of reach, and
## only "there is no turn left" is ever certain.
func _farkle_button_text() -> String:
	return "End level" if game.context.turns_left() == 1 else "Next turn"

## Taking is offered when something is marked, and also when nothing is marked
## but something could be — the button takes everything in that case.
func _can_take() -> bool:
	if game.can_commit_selection():
		return true
	return game.get_selection().is_empty() and not game.get_scorable_dice().is_empty()

## "Take all" is a promise the button cannot always keep. Once a mega combo can
## make five dice worth more than six, pressing it takes the *best* selection,
## which is sometimes fewer — and a button that says "all" and then leaves a
## scoring die behind reads as a bug rather than as advice.
func _take_text() -> String:
	var score := game.selection_score
	if score != null and score.is_valid():
		return "Take  +%d" % score.total()
	if _best_is_a_subset():
		return "Take best"
	return "Take all"

## Whether the highest-scoring take leaves a scoring die on the table. The one
## situation in the game where taking less is right, so it is worth saying twice
## — on the button, and in the hint line under the dice.
func _best_is_a_subset() -> bool:
	var best := game.get_best_selection().size()
	return best > 0 and best < game.get_scorable_dice().size()

func _bank_text() -> String:
	var requirement := game.get_bank_requirement_text()
	if not requirement.is_empty():
		return requirement
	if game.context.turn_score > 0:
		return "Bank  %d" % game.context.turn_score
	return "Bank"

## The one line under the dice. It says whatever the player most needs to know
## right now, which changes through a turn — so it is rebuilt rather than set
## once in the scene.
func _refresh_hint() -> void:
	if not _notice.is_empty():
		_show_hint(_notice, _notice_color)
		return
	if game.state != FarkleGame.State.CHOOSING:
		return
	# Points on the table outrank everything else, because the decision they
	# create is the only one that matters. "Nothing scores" is true of the dice
	# left over after a take, and saying it there would read as a dead end when
	# the player is one tap from banking.
	# A take worth more than the whole roll outranks even points on the table. It
	# is the only moment the game asks the player to leave a scoring die behind,
	# and nothing else on screen would ever tell them so.
	if _best_is_a_subset():
		_show_hint("Fewer dice score more here — see what Take offers", COMBO_HINT_COLOR)
	elif game.context.turn_score > 0:
		_show_hint(
			"Roll again to grow the turn, or bank before a Farkle takes it", HINT_COLOR
		)
	elif game.get_scorable_dice().is_empty():
		_show_hint("Nothing scores", HINT_COLOR)
	else:
		_show_hint("Tap the dice that score, then Take", HINT_COLOR)

# --- windows ----------------------------------------------------------------

## The guide is built from this level's own rules, so a boss's twist shows up in
## it rather than a generic table that quietly lies.
func _on_guide_requested() -> void:
	if guide_scene == null:
		return
	var guide := guide_scene.instantiate()
	add_child(guide)
	guide.show_rules(game)

## Opens the walkthrough the first time this level is played, then never again.
func _show_tutorial_once() -> void:
	if tutorial_scene == null or level_state == null or level_state.tutorial_read:
		return
	level_state.tutorial_read = true
	GlobalState.save()
	var window := tutorial_scene.instantiate()
	add_child(window)

# --- outcome ----------------------------------------------------------------

func _on_level_won() -> void:
	_record_result(true)
	_grant_dice()
	GameState.get_run().clear_level(game.context.banked_score, game.context.farkle_count)
	GlobalState.save()
	win()

## Clearing a level pays the dice it showed you, permanently.
##
## Tops up rather than adds, so replaying a level is not a dice farm — the reward
## is reaching it the first time. Campaign.grant_for() is the same data as the
## reference bag on purpose: the targets were measured against exactly these
## dice, so these are the ones the player has to end up owning.
func _grant_dice() -> void:
	if campaign == null:
		return
	var granted := GameState.grant_dice(campaign.grant_for(level_number))
	if granted.is_empty():
		return
	var names : Array[String] = []
	for element in granted:
		names.append("%d %s" % [int(granted[element]), Element.get_label(element)])
	_set_notice("Earned %s" % " and ".join(names), HINT_COLOR)

## The run's tally is updated here, but the run is *ended* by the level manager.
## A level does not get to decide that the attempt is over — endless levels lose
## too, and they are not part of a campaign run at all.
func _on_level_lost() -> void:
	_record_result(false)
	GameState.get_run().record_loss(game.context.farkle_count)
	GlobalState.save()
	lose()

## Persists the run so level select and progression have something to read.
func _record_result(completed : bool) -> void:
	if level_state == null:
		return
	level_state.best_score = maxi(level_state.best_score, game.context.banked_score)
	if completed:
		level_state.completed = true
	GlobalState.save()
