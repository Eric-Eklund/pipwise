class_name CardDiceGame
extends RefCounted
## Runs one level: deal a hand, roll the dice, spend the white energy they
## produce on better cards and kept dice, then save the hand and see whether it
## cleared the bar.
##
## One level is one hand. Everything the player does between the deal and the
## save is paid for out of the dice, and saving is the only way out — which is
## what makes the round short enough to be worth replaying immediately.
##
## Headless by design. Nothing here touches a Node, so a whole level can be
## driven to a win or a loss inside a test.

signal hand_changed
signal dice_changed
signal energy_changed
signal hand_saved(score : HandScore)
signal progress_changed
signal state_changed(new_state : State)
signal game_won
signal game_lost

enum State { SETUP, PLAYING, WON, LOST }

var ruleset : Ruleset
var context : GameContext
var state : State = State.SETUP
## What the hand was worth when it was saved. Null until then.
var last_score : HandScore

var _rng : RngService
var _evaluator : HandEvaluator
var _objective : Objective

func _init(game_ruleset : Ruleset, rng : RngService) -> void:
	ruleset = game_ruleset
	_rng = rng
	_evaluator = ruleset.get_evaluator()
	_objective = ruleset.get_objective()

	# The deck is built, and so consumes the seeded stream, before the dice.
	# Swapping these two lines changes every seeded outcome in the game; a test
	# pins the order for exactly that reason.
	var deck := Deck.new(ruleset.get_deck_definition(), rng)
	var hand := Hand.new(ruleset.hand_size)
	var pool := DicePool.new(ruleset.get_bag_definition(), rng, ruleset.max_rerolls)
	context = GameContext.new(deck, hand, pool, rng)
	context.energy_changed.connect(_on_energy_changed)

func get_objective() -> Objective:
	return _objective

func get_pool() -> DicePool:
	return context.pool

func get_dice() -> Array[Die]:
	return context.pool.dice

## Deals the opening hand, rolls every die, and lets the bosses have their say.
func start() -> void:
	_set_state(State.PLAYING)
	context.refill_hand()
	hand_changed.emit()
	context.pool.roll_all()
	# After the roll, so a modifier that cares what the dice landed on can see
	# it before the player does.
	for modifier in ruleset.modifiers:
		modifier.on_level_start(context)
	dice_changed.emit()
	_refresh_score()

# --- cards --------------------------------------------------------------

func swap_cost() -> int:
	return ruleset.card_swap_cost

## What swapping everything currently marked would cost.
func selected_swap_cost() -> int:
	return context.hand.selected_count() * swap_cost()

func can_swap_selected() -> bool:
	return state == State.PLAYING \
		and context.hand.selected_count() > 0 \
		and context.can_afford(selected_swap_cost()) \
		and not context.deck.is_exhausted()

## Pays for the marked cards, discards them, and deals replacements.
func swap_selected() -> bool:
	if not can_swap_selected():
		return false
	if not context.spend_energy(selected_swap_cost()):
		return false
	var swapped := context.hand.take_selected()
	context.deck.discard(swapped)
	context.refill_hand()
	hand_changed.emit()
	_refresh_score()
	return true

# --- dice ---------------------------------------------------------------

func lock_cost() -> int:
	return ruleset.die_lock_cost

func can_toggle_lock(die : Die) -> bool:
	if state != State.PLAYING or die.is_frozen:
		return false
	# Unlocking is always allowed; locking has to be paid for.
	return die.is_locked or context.can_afford(lock_cost())

## Locking costs energy and unlocking gives it back. The cost only bites at the
## next reroll, so charging for a change of mind would punish experimenting
## with no rule to justify it.
func toggle_lock(die : Die) -> bool:
	if not can_toggle_lock(die):
		return false

	if die.is_locked:
		if not context.pool.set_locked(die, false):
			return false
		context.refund_energy(lock_cost())
	else:
		if not context.spend_energy(lock_cost()):
			return false
		if not context.pool.set_locked(die, true):
			context.refund_energy(lock_cost())
			return false

	dice_changed.emit()
	_refresh_score()
	return true

func rerolls_left() -> int:
	return context.pool.rerolls_left

func can_reroll() -> bool:
	return state == State.PLAYING and context.pool.can_reroll()

## Rerolls every die the player has not held. Free, but limited, and it can
## leave them with less energy than they had a moment ago.
func reroll() -> bool:
	if not can_reroll():
		return false
	if not context.pool.reroll_unheld():
		return false
	dice_changed.emit()
	_refresh_score()
	return true

# --- scoring ------------------------------------------------------------

## What the hand would be worth right now. Mutates nothing, so the UI can call
## it after every tap.
func preview_score() -> HandScore:
	return _evaluator.evaluate(context.hand.cards, context)

func can_save_hand() -> bool:
	if state != State.PLAYING:
		return false
	if not _evaluator.is_valid_play(context.hand.cards):
		return false
	for modifier in ruleset.modifiers:
		if not modifier.can_save_hand(context):
			return false
	return true

## Why saving is blocked, e.g. "Lock at least 2 dice". Empty when it is not.
func get_save_requirement_text() -> String:
	for modifier in ruleset.modifiers:
		if not modifier.can_save_hand(context):
			var text := modifier.get_requirement_text(context)
			if not text.is_empty():
				return text
	return ""

## Locks the hand in and judges the level. The only exit from PLAYING.
func save_hand() -> void:
	if not can_save_hand():
		return
	_refresh_score()
	last_score = preview_score()
	hand_saved.emit(last_score)

	if _objective.is_met(context):
		_set_state(State.WON)
		game_won.emit()
	else:
		_set_state(State.LOST)
		game_lost.emit()

## Recomputes what the hand is worth as it stands. Called after every change, so
## the objective and the HUD can read context.score instead of each evaluating
## the hand for themselves.
func _refresh_score() -> void:
	var score := preview_score()
	context.score = score.total()
	context.current_category = score.category
	progress_changed.emit()

func _on_energy_changed() -> void:
	energy_changed.emit()

func _set_state(new_state : State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)
