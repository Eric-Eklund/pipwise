class_name FarkleGame
extends RefCounted
## Runs one level: turn after turn of rolling, setting dice aside, and deciding
## whether to push or bank, until the target is reached or the turns run out.
##
## Replaces CardDiceGame, which could not be adapted. That class was built on
## "one level is one hand" — a single scoring event with a single verdict. A
## Farkle level is a loop inside a loop: many turns per level, many rolls per
## turn, with the score changing hands at every step.
##
## Headless by design. Nothing here touches a Node, so a whole level can be
## driven to a win or a loss inside a test, which is what lets the balance probe
## measure the difficulty curve instead of guessing at it.
##
## ## The turn
##
##     roll  ──▶ nothing scores? ──▶ FARKLE: the turn's points are gone
##           └─▶ something does  ──▶ the player sets dice aside
##                                   ├─▶ all six set aside → HOT DICE, roll again
##                                   ├─▶ [Push]  roll what is left, points at risk
##                                   └─▶ [Bank]  points become safe, next turn
##
## A push is not capped. The design document asks for at most three rolls a turn,
## but the bust already is the limit — with two guaranteed-safe rolls in front of
## it the decision would not be a decision. The level's turn count is the budget
## instead. See the deviations section of docs/DESIGN.md.

signal dice_changed
signal selection_changed
signal score_changed
signal rolled
## Dice were committed to the turn. Carries what they were worth and which ones
## they were, because by the time a listener looks at the pool every set aside
## die looks alike and only this knows which the player just chose.
signal took(score : DiceScore, dice : Array[Die])
## Nothing on the table scores. Carries what the turn was worth before it went.
signal farkled(points_lost : int)
signal banked(points : int)
signal hot_dice
## A card was paid for and played. Carries the card so the row can animate the
## one that went rather than redrawing the whole hand, and any dice the card
## changed the face of — the tray redraws a face only when it rolls one, so a
## card that moved the dice and did not say so would leave the old face on
## screen while the engine scored the new one.
signal card_played(card : Card, rerolled : Array[Die])
signal turn_started(turn : int)
signal state_changed(new_state : State)
signal level_won
signal level_lost

enum State {
	SETUP,
	## Dice on the table, the player choosing what to keep.
	CHOOSING,
	## The roll scored nothing. A dead end the player has to acknowledge.
	FARKLED,
	WON,
	LOST,
}

var ruleset : Ruleset
var context : GameContext
var state : State = State.SETUP
## What the dice the player has marked are worth. Recomputed after every tap so
## the HUD can read it rather than scoring the selection again on each redraw.
var selection_score : DiceScore
## The element rules for the dice currently in play. Rebuilt on every roll,
## because a trio depends on what is on the table.
var rules : ElementRules

## The cards the player is holding. Null in endless mode, which is not part of a
## run and so has no hand — every card path checks for that rather than assuming
## a run exists.
var hand : CardHand

var _rng : RngService
var _objective : Objective
## Cards played this turn and still in force. Cleared at the top of every turn:
## section 3 calls their duration "one round", and a round here is a turn.
var _active_cards : Array[Card] = []
## Dice the player has marked but not yet committed. Marking is reversible;
## committing is not, which is why the two are separate.
var _selection : Array[Die] = []

## What is takeable and what is best, worked out once per board.
##
## Both are asked for far more often than they change: the tray asks can_select()
## once per die on every redraw, so a single tap costs a dozen of these, and
## searching for the best selection walks every subset of the table.
var _scorable_cache : Array[Die] = []
var _best_cache : Array[Die] = []
## The board the two caches were computed for. Compared by value rather than
## trusted, because a dirty flag cannot see every way the dice change: the tests
## write faces straight onto the dice and reassign `rules`, touching no method
## and emitting no signal. A flag was tried first and went stale in nineteen
## tests at once.
var _cached_board : Array = []

func _init(game_ruleset : Ruleset, rng : RngService) -> void:
	ruleset = game_ruleset
	_rng = rng
	_objective = ruleset.get_objective()

	var pool := DicePool.new(ruleset.get_bag_definition(), rng)
	context = GameContext.new(pool, rng)
	context.turn_limit = ruleset.turns
	rules = ElementRules.new()

func get_objective() -> Objective:
	return _objective

func get_pool() -> DicePool:
	return context.pool

func get_dice() -> Array[Die]:
	return context.pool.dice

func get_dice_in_play() -> Array[Die]:
	return context.pool.get_in_play()

# --- starting --------------------------------------------------------------

## Begins the level and rolls the first turn.
func start() -> void:
	_set_state(State.CHOOSING)
	for modifier in ruleset.modifiers:
		modifier.on_level_start(context)
	_begin_turn()

## Rolls for a new turn: everything back on the table, nothing riding yet.
func _begin_turn() -> void:
	context.pool.reset_turn()
	_active_cards.clear()
	_clear_selection()
	for modifier in ruleset.modifiers:
		modifier.on_turn_start(context)
	turn_started.emit(context.turn)
	_roll()
	# After the roll, not before: the budget is the pips on the table, and before
	# the roll there are none. Pushing later in the turn does not re-take it.
	context.snapshot_energy()

# --- rolling ---------------------------------------------------------------

## Rolls whatever is still in play and works out whether the turn survived it.
func _roll() -> void:
	context.pool.roll()
	_clear_selection()
	# After the roll: a trio depends on the dice that are on the table now.
	rules = ElementRules.new(get_dice_in_play(), _active_cards)
	rolled.emit()
	dice_changed.emit()

	if get_scorable_dice().is_empty():
		_farkle()
	else:
		_refresh_selection_score()

## Whether the player may push. Pushing is only meaningful once something has
## been committed — rolling again without setting a die aside would be a free
## retry, which is the one thing Farkle must never allow.
func can_push() -> bool:
	return state == State.CHOOSING \
		and _selection.is_empty() \
		and context.pool.set_aside_count() > 0 \
		and not context.pool.is_exhausted()

## Rolls again with the dice that are left, the turn's points still at risk.
func push() -> bool:
	if not can_push():
		return false
	_roll()
	return true

# --- choosing --------------------------------------------------------------

## The dice the player is allowed to set aside. Legality, not advice — every die
## in here stays tappable even when get_best_selection() leaves it behind.
##
## Copied on the way out. The caller owns what it gets: select_all_scoring()
## hands its result straight to _selection, and toggle_selection() erases from
## that, which would eat the cache from under the tray.
func get_scorable_dice() -> Array[Die]:
	_rebuild_scoring_cache()
	return _scorable_cache.duplicate()

## The takeable selection worth the most, which is what the Take button reaches
## for when the player has marked nothing.
##
## Not always everything that scores. A mega combo asks something of the *shape*
## of a selection, and an element bonus is a share of its own part that another
## die dilutes — so one wrong die can cost more than it brings, and the
## highest-scoring take is then a subset of the legal one. That gap is the whole
## of the choice the player now has, and get_scorable_dice() is what keeps it a
## choice rather than an instruction.
func get_best_selection() -> Array[Die]:
	_rebuild_scoring_cache()
	return _best_cache.duplicate()

## The dice the boss is willing to let score.
##
## The boss narrows the field *before* the scorer sees it, not after. Filtering
## afterwards looks equivalent and is not: a straight makes all six dice score,
## and keeping only the Fire ones out of it leaves three dice that are marked
## takeable but form nothing, so the player can select them and then find the
## commit button dead. Removing them up front means the scorer never offers a
## shape the boss would break.
func _takeable_candidates() -> Array[Die]:
	var candidates := get_dice_in_play()
	for modifier in ruleset.modifiers:
		candidates = modifier.filter_scorable(context, candidates)
	return candidates

func _rebuild_scoring_cache() -> void:
	var board := _board_fingerprint()
	if board == _cached_board:
		return
	var candidates := _takeable_candidates()
	_scorable_cache = FarkleScorer.scorable_dice(candidates, rules)
	_best_cache = FarkleScorer.best_of(_scorable_cache, rules)
	_cached_board = board

## Everything the two answers depend on, as a handful of integers.
##
## The turn and the roll count are in here even though no shipped modifier reads
## them: filter_scorable() is handed the whole context, so a future modifier that
## narrows the field as the turn wears on would otherwise be cached over.
func _board_fingerprint() -> Array:
	var board : Array = [
		rules.get_instance_id(), context.turn, context.turn_score, context.pool.roll_count
	]
	for die in context.pool.dice:
		board.append(die.get_value() * 2 + (1 if die.is_set_aside else 0))
	return board

func is_selected(die : Die) -> bool:
	return die in _selection

func get_selection() -> Array[Die]:
	return _selection.duplicate()

func can_select(die : Die) -> bool:
	if state != State.CHOOSING or die == null or die.is_set_aside:
		return false
	return die in get_scorable_dice()

## Marks or unmarks a die. Free and reversible — nothing is spent until the
## selection is committed, so the player can try a combination and change their
## mind without being punished for experimenting.
func toggle_selection(die : Die) -> bool:
	if die in _selection:
		_selection.erase(die)
	elif can_select(die):
		_selection.append(die)
	else:
		return false
	_refresh_selection_score()
	selection_changed.emit()
	return true

## Marks the selection worth the most. The button most players will use most of
## the time, and no longer the same thing as marking everything that scores —
## see get_best_selection().
func select_all_scoring() -> void:
	_selection = get_best_selection()
	_refresh_selection_score()
	selection_changed.emit()

func can_commit_selection() -> bool:
	return state == State.CHOOSING \
		and selection_score != null \
		and selection_score.is_valid()

## Commits the marked dice to the turn: their points join the turn score and the
## dice leave the table. The only irreversible move inside a turn.
##
## Two things can follow immediately. Nature may hand dice back, and clearing
## the table earns hot dice — all six again with the score intact, which is
## where the big turns come from.
func commit_selection() -> bool:
	if not can_commit_selection():
		return false

	var score := selection_score
	var taken := _selection.duplicate()
	context.pool.set_aside_all(_selection)
	context.add_turn_score(score.total())
	_clear_selection()
	took.emit(score, taken)

	if score.dice_restored > 0:
		context.pool.restore(score.dice_restored)

	if context.pool.is_exhausted():
		context.pool.reset_for_hot_dice()
		hot_dice.emit()
		dice_changed.emit()
		score_changed.emit()
		_roll()
		return true

	dice_changed.emit()
	score_changed.emit()
	_refresh_selection_score()
	return true

# --- cards -----------------------------------------------------------------

## The cards the player could play right now. What the row draws.
##
## Spelled out rather than a ternary: `a if b else [] as Array[Card]` builds an
## untyped array on the empty branch, and the row assigns the result straight
## into an Array[Card].
func get_hand() -> Array[Card]:
	if hand == null:
		var empty : Array[Card] = []
		return empty
	return hand.get_cards()

## The cards in force this turn. Read by the HUD, and by anything rebuilding the
## element rules after the board changed under them.
func get_active_cards() -> Array[Card]:
	return _active_cards.duplicate()

## Whether [param card] can be played: the turn is live, it is in hand, the
## energy is there, and the card itself is willing.
##
## Only during CHOOSING. A card played on a busted board would be paying to
## change a roll that has already failed, and Shield is bought *before* the roll
## it protects for exactly that reason — otherwise pushing is free and the game
## loses its core.
func can_play_card(card : Card) -> bool:
	if card == null or hand == null or state != State.CHOOSING:
		return false
	if not hand.holds(card.id):
		return false
	if not context.can_afford(card.energy_cost):
		return false
	return card.can_play(self)

## Why [param card] cannot be played right now, in one line, or "" when it can.
##
## The same shape as get_bank_requirement_text(), and for the same reason: the
## row can only say yes or no by greying a card out, and on a phone there is no
## hover to explain the difference. This is the sentence the card's own detail
## window shows when the player holds it down and asks.
##
## Ordered cheapest question first, and the card's own objection last, because a
## card refused for three reasons at once should name the one the player can do
## something about soonest.
func get_card_refusal(card : Card) -> String:
	if card == null or hand == null or not hand.holds(card.id):
		return ""
	if state != State.CHOOSING:
		return "Cards are played while the dice are still on the table."
	if not context.can_afford(card.energy_cost):
		return "Costs %d⚡, and the turn has %d left." % [
			card.energy_cost, context.available_energy()
		]
	if not card.can_play(self):
		return card.get_refusal(self)
	return ""

## Pays for a card and plays it. The energy goes first, then the card leaves the
## hand, then it takes effect — in that order, so a card that draws cards cannot
## draw itself back and a refused play has already cost nothing.
func play_card(card : Card) -> bool:
	if not can_play_card(card):
		return false

	context.spend_energy(card.energy_cost)
	hand.discard(card.id)
	_active_cards.append(card)
	var faces_before := _face_snapshot()
	card.on_played(self)

	# Rebuilt rather than mutated, because the scoring cache is keyed on this
	# object's identity — without a new one the Take button would go on offering
	# the pre-card answer until the next roll.
	rules = ElementRules.new(get_dice_in_play(), _active_cards)

	# dice_changed first: it is what moves a restored die out of the set aside
	# row, and the roll animation card_played asks for should play on a die that
	# is already where it belongs.
	dice_changed.emit()
	card_played.emit(card, _dice_rerolled_since(faces_before))
	_refresh_selection_score()
	return true

## What every die is showing, by index. Taken either side of on_played() so the
## view can be told exactly which dice a card turned over.
##
## Worked out here rather than reported by the card, because a card carries no
## state about having been played and should not have to remember to mention
## this. §3.5's spells turn the whole board over; they will be seen for free.
func _face_snapshot() -> Array[int]:
	var faces : Array[int] = []
	for die in context.pool.dice:
		faces.append(die.get_value())
	return faces

func _dice_rerolled_since(faces_before : Array[int]) -> Array[Die]:
	var changed : Array[Die] = []
	for i in context.pool.dice.size():
		if i < faces_before.size() and context.pool.dice[i].get_value() != faces_before[i]:
			changed.append(context.pool.dice[i])
	return changed

# --- banking ---------------------------------------------------------------

func can_bank() -> bool:
	if state != State.CHOOSING or context.turn_score <= 0:
		return false
	# An uncommitted selection is not banked. Requiring it to be committed first
	# keeps one rule — points are only real once set aside — instead of two.
	if not _selection.is_empty():
		return false
	if context.turn_score < ruleset.minimum_bank:
		return false
	for modifier in ruleset.modifiers:
		if not modifier.can_bank(context):
			return false
	return true

## Why banking is blocked, e.g. "Reach 500 to bank". Empty when it is not.
func get_bank_requirement_text() -> String:
	if context.turn_score > 0 and context.turn_score < ruleset.minimum_bank:
		return "Reach %d to bank" % ruleset.minimum_bank
	for modifier in ruleset.modifiers:
		if not modifier.can_bank(context):
			var text := modifier.get_requirement_text(context)
			if not text.is_empty():
				return text
	return ""

## Makes the turn's points safe and ends the turn.
func bank() -> bool:
	if not can_bank():
		return false
	var points := context.bank_turn_score()
	banked.emit(points)
	score_changed.emit()
	_end_turn()
	return true

# --- farkle ----------------------------------------------------------------

## Nothing on the table scores. The turn's points are gone, and the level may
## charge for it on top.
## Shield banks the turn instead of losing it. The table still holds nothing
## worth taking, so the turn is over either way — what the card buys is keeping
## what was already earned.
##
## It deliberately does not hand the roll back. Leaving the player in CHOOSING
## would let them push again off dice they had already set aside, and a free
## retry after a bust is the one thing Farkle must never allow — it is the same
## reason can_push() refuses to roll without a commitment.
func _farkle() -> void:
	var lost := context.turn_score
	if rules.blocks_farkle() and lost > 0:
		var saved := context.bank_turn_score()
		_set_state(State.FARKLED)
		farkled.emit(0)
		banked.emit(saved)
		score_changed.emit()
		return
	context.lose_turn_score(rules.farkle_penalty(ruleset.farkle_penalty))
	_set_state(State.FARKLED)
	farkled.emit(lost)
	score_changed.emit()

## Acknowledges a Farkle and moves on. A separate step rather than an automatic
## one because losing 2000 points deserves a beat to look at, and because a turn
## ending on its own while the player is mid-tap is how a phone game gets thrown
## across a room.
func continue_after_farkle() -> bool:
	if state != State.FARKLED:
		return false
	_set_state(State.CHOOSING)
	_end_turn()
	return true

# --- turn and level boundaries ---------------------------------------------

## Judges the level, then either starts the next turn or stops.
##
## The order matters: winning is checked before running out of turns, so banking
## the winning points on the last turn is a win and not a loss.
func _end_turn() -> void:
	if _objective.is_met(context):
		_set_state(State.WON)
		level_won.emit()
		return

	context.advance_turn()

	if _objective.is_failed(context):
		_set_state(State.LOST)
		level_lost.emit()
		return

	_begin_turn()

# --- scoring ---------------------------------------------------------------

## Recomputes what the marked dice are worth. Called after every change so the
## HUD can read selection_score instead of scoring the selection again itself.
func _refresh_selection_score() -> void:
	selection_score = FarkleScorer.score(_selection, rules)
	score_changed.emit()

func _clear_selection() -> void:
	_selection.clear()
	selection_score = FarkleScorer.score([] as Array[Die], rules)

func _set_state(new_state : State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)
