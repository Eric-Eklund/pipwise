class_name DicePool
extends RefCounted
## The dice a turn is played with: rolled together, set aside one at a time,
## rolled again with whatever is left.
##
## The pool is the whole board state of a Farkle turn. Dice move in one
## direction — in play, then set aside — and the only thing that moves them back
## is hot dice, when everything has scored and the player gets all six again.
##
## It knows nothing about scoring. What is worth setting aside is FarkleScorer's
## business, and keeping that out of here is what lets an element rule change
## what counts as a score without this class hearing about it.

signal rolled(dice : Array[Die])
signal set_aside_changed(die : Die)
## Every die came back to the table with the turn score intact.
signal hot_dice

## Every die the player owns this level, set aside or not.
var dice : Array[Die] = []
## How many rolls this turn has taken. The first one is 1.
var roll_count : int = 0

var _rng : RngService

func _init(definition : BagDefinition, rng : RngService) -> void:
	_rng = rng
	for die_type in definition.dice:
		dice.append(Die.new(die_type))

func size() -> int:
	return dice.size()

# --- what is where ---------------------------------------------------------

## The dice still being rolled.
func get_in_play() -> Array[Die]:
	var result : Array[Die] = []
	for die in dice:
		if not die.is_set_aside:
			result.append(die)
	return result

## The dice committed to this turn.
func get_set_aside() -> Array[Die]:
	var result : Array[Die] = []
	for die in dice:
		if die.is_set_aside:
			result.append(die)
	return result

func in_play_count() -> int:
	return get_in_play().size()

func set_aside_count() -> int:
	return get_set_aside().size()

## Every pip showing across the whole pool. The energy budget a level is given,
## which is why it counts set aside dice too — the player's dice are their
## resources whether or not they have been spent this turn.
func total_value() -> int:
	var total := 0
	for die in dice:
		total += die.get_value()
	return total

# --- rolling ---------------------------------------------------------------

## Rolls everything still in play. Returns the dice it rolled, which is empty
## only when the player has somehow set every die aside without the pool
## noticing — a state hot dice is supposed to have already cleared.
func roll() -> Array[Die]:
	var rolling := get_in_play()
	if rolling.is_empty():
		return rolling
	for die in rolling:
		die.roll(_rng)
	roll_count += 1
	rolled.emit(rolling)
	return rolling

# --- setting aside ---------------------------------------------------------

## Commits one die to the turn. Returns false if it was already set aside, so a
## caller that scored the selection first does not double-count it.
func set_aside(die : Die) -> bool:
	if die == null or die.is_set_aside:
		return false
	die.is_set_aside = true
	set_aside_changed.emit(die)
	return true

## Takes a die back out of the turn. Only legal before the score is committed —
## FarkleGame is what enforces that, since the pool has no notion of a score.
func take_back(die : Die) -> bool:
	if die == null or not die.is_set_aside:
		return false
	die.is_set_aside = false
	set_aside_changed.emit(die)
	return true

func set_aside_all(selection : Array[Die]) -> int:
	var count := 0
	for die in selection:
		if set_aside(die):
			count += 1
	return count

## Hands [param count] dice back to the table, newest commitments first. Nature's
## doing. Returns the dice that actually came back, which is fewer than asked
## when the turn has not set that many aside yet.
##
## Newest first because those are the dice the player just chose, so the ones
## coming back are the ones they are still looking at.
##
## The dice rather than a count, because a caller may want to do something to
## them: Second Wind rerolls what it buys back, and Nature deliberately does not.
func restore(count : int) -> Array[Die]:
	var restored : Array[Die] = []
	if count <= 0:
		return restored
	for i in range(dice.size() - 1, -1, -1):
		if restored.size() >= count:
			break
		if dice[i].is_set_aside:
			dice[i].is_set_aside = false
			set_aside_changed.emit(dice[i])
			restored.append(dice[i])
	return restored

## Whether every die has been set aside, which is what earns hot dice.
func is_exhausted() -> bool:
	return in_play_count() == 0

## Brings every die back for another roll with the turn score kept. The reward
## for clearing the table, and the only way a turn can score more than six dice
## are worth.
func reset_for_hot_dice() -> void:
	for die in dice:
		die.is_set_aside = false
	hot_dice.emit()

## Clears the turn: everything back in play, roll count back to zero.
func reset_turn() -> void:
	for die in dice:
		die.is_set_aside = false
	roll_count = 0
