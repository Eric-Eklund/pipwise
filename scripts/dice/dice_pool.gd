class_name DicePool
extends RefCounted
## The dice on the table: rolled together, held one at a time, rerolled as a set.
##
## Replaces the old draw-and-discard DiceBag. Dice are no longer drawn — the
## player brings the same six to every level, and the interesting decision is
## which of them to pay to keep before spending a reroll on the rest.
##
## The pool never touches energy itself. It reports what it is showing and
## GameContext prices it, so the cost rules stay in one place.

signal rolled(dice : Array[Die])
signal lock_changed(die : Die)

var dice : Array[Die] = []
var rerolls_left : int = 0

var _rng : RngService

func _init(definition : BagDefinition, rng : RngService, max_rerolls : int = 3) -> void:
	_rng = rng
	rerolls_left = maxi(0, max_rerolls)
	for die_type in definition.dice:
		dice.append(Die.new(die_type))

func size() -> int:
	return dice.size()

## The opening roll. Ignores locks and freezes, because nothing is held yet.
func roll_all() -> void:
	for die in dice:
		die.roll(_rng)
	rolled.emit(dice)

## Rerolls everything the player has not held, and spends a reroll doing it.
## Returns false when there is none left or nothing would change, so callers
## can leave the button switched off rather than guess.
func reroll_unheld() -> bool:
	if not can_reroll():
		return false
	rerolls_left -= 1
	for die in dice:
		if not die.is_held():
			die.roll(_rng)
	rolled.emit(dice)
	return true

func can_reroll() -> bool:
	return rerolls_left > 0 and not get_unheld().is_empty()

## Every pip showing, added up. This one number is both the white energy the
## player has to spend and the dice bonus the saved hand scores with.
func total_value() -> int:
	var total := 0
	for die in dice:
		total += die.get_value()
	return total

func locked_count() -> int:
	var count := 0
	for die in dice:
		if die.is_locked:
			count += 1
	return count

func frozen_count() -> int:
	var count := 0
	for die in dice:
		if die.is_frozen:
			count += 1
	return count

func get_unheld() -> Array[Die]:
	var result : Array[Die] = []
	for die in dice:
		if not die.is_held():
			result.append(die)
	return result

## Refuses rather than silently ignores a frozen die, so a caller that charged
## energy for the lock can hand it back. Returns whether anything changed.
func set_locked(die : Die, value : bool) -> bool:
	if die.is_frozen or die.is_locked == value:
		return false
	die.is_locked = value
	lock_changed.emit(die)
	return true

## Freezes [param count] dice picked at random, and returns the ones it froze.
## Frost King's entire effect. A frozen die drops any lock it had, because the
## player can no longer choose for it and should not keep paying for it.
func freeze_random(count : int) -> Array[Die]:
	var candidates : Array[Die] = []
	for die in dice:
		if not die.is_frozen:
			candidates.append(die)
	_rng.shuffle(candidates)

	var frozen : Array[Die] = []
	for i in mini(count, candidates.size()):
		var die : Die = candidates[i]
		die.is_frozen = true
		die.is_locked = false
		frozen.append(die)
		lock_changed.emit(die)
	return frozen
