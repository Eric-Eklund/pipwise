class_name CardDiceGame
extends RefCounted
## Runs one level: deal a hand, spend dice on it, play a combination, repeat
## until the objective is met or the plays run out.
##
## Headless by design. Nothing here touches a Node, so a whole level can be
## driven to a win or a loss inside a test.

signal hand_changed
signal dice_changed(dice : Array[Die])
signal hand_played(score : HandScore)
signal progress_changed
signal state_changed(new_state : State)
signal game_won
signal game_lost

enum State { SETUP, PLAYING, WON, LOST }

var ruleset : Ruleset
var context : GameContext
var bag : DiceBag
var drawn_dice : Array[Die] = []
var state : State = State.SETUP

var _rng : RngService
var _evaluator : HandEvaluator
var _objective : Objective

func _init(game_ruleset : Ruleset, rng : RngService) -> void:
	ruleset = game_ruleset
	_rng = rng
	_evaluator = ruleset.get_evaluator()
	_objective = ruleset.get_objective()

	var deck := Deck.new(ruleset.get_deck_definition(), rng)
	var hand := Hand.new(ruleset.hand_size)
	context = GameContext.new(deck, hand, rng)
	context.plays_left = ruleset.max_plays
	bag = DiceBag.new(ruleset.get_bag_definition(), rng)

func get_objective() -> Objective:
	return _objective

func start() -> void:
	_set_state(State.PLAYING)
	context.refill_hand()
	hand_changed.emit()
	_start_turn()

## Whether the current selection is something the evaluator will accept.
func can_play() -> bool:
	return state == State.PLAYING and _evaluator.is_valid_play(context.hand.get_selected())

## Scores the selected cards, ends the turn, and judges the level.
func play_selected() -> void:
	if not can_play():
		return
	var played := context.hand.take_selected()
	var score := _evaluator.evaluate(played, context)
	context.deck.discard(played)
	context.score += score.total()
	# The multiplier is spent by the hand it boosted.
	context.score_multiplier = 1.0
	context.plays_left -= 1
	hand_played.emit(score)

	context.refill_hand()
	hand_changed.emit()
	# Judge before dealing the next turn, so a winning play does not briefly
	# put fresh dice on the table.
	_check_outcome()
	if state == State.PLAYING:
		_start_turn()
	else:
		progress_changed.emit()

## Runs a die's action and marks it spent. Returns whether anything happened.
func spend_die(die : Die) -> bool:
	if state != State.PLAYING or die.is_spent:
		return false
	var action := die.get_action()
	if action == null or not action.can_apply(context):
		return false
	action.apply(context)
	bag.spend(die)
	progress_changed.emit()
	return true

## Returns whatever dice went unspent and draws a fresh set for the new turn.
func _start_turn() -> void:
	var unspent : Array[Die] = []
	for die in drawn_dice:
		if not die.is_spent:
			unspent.append(die)
	bag.return_dice(unspent)
	drawn_dice = bag.draw(ruleset.dice_per_turn)
	dice_changed.emit(drawn_dice)
	progress_changed.emit()

func _check_outcome() -> void:
	if _objective.is_met(context):
		_set_state(State.WON)
		game_won.emit()
	elif _objective.is_failed(context):
		_set_state(State.LOST)
		game_lost.emit()

func _set_state(new_state : State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)
