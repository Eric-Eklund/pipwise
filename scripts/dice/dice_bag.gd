class_name DiceBag
extends RefCounted
## Dice drawn from a bag without replacement; spent dice go to a used pile and
## come back when the bag runs dry.
##
## Deliberately the same shape as Deck. Cards and dice behave alike, so the
## game loop can treat them alike.

signal dice_drawn(dice : Array[Die])
signal refilled

var _bag : Array[Die] = []
var _used : Array[Die] = []
var _rng : RngService

func _init(definition : BagDefinition, rng : RngService) -> void:
	_rng = rng
	for die_type in definition.dice:
		_bag.append(Die.new(die_type))
	_rng.shuffle(_bag)

func bag_size() -> int:
	return _bag.size()

func used_size() -> int:
	return _used.size()

func total_size() -> int:
	return _bag.size() + _used.size()

func is_exhausted() -> bool:
	return total_size() == 0

## Draws up to [param count] dice and rolls each one as it comes out, so a
## drawn die always shows a face. Refills from the used pile if the bag empties.
func draw(count : int) -> Array[Die]:
	var drawn : Array[Die] = []
	for _i in count:
		if _bag.is_empty():
			if _used.is_empty():
				break
			refill()
		var die : Die = _bag.pop_back()
		die.is_spent = false
		die.roll(_rng)
		drawn.append(die)
	if not drawn.is_empty():
		dice_drawn.emit(drawn)
	return drawn

## Marks a die spent and sends it to the used pile.
func spend(die : Die) -> void:
	die.is_spent = true
	_used.append(die)

## Returns unspent dice to the used pile, e.g. at the end of a turn.
func return_dice(dice : Array[Die]) -> void:
	for die in dice:
		die.is_spent = false
		_used.append(die)

func refill() -> void:
	if _used.is_empty():
		return
	_bag.append_array(_used)
	_used.clear()
	_rng.shuffle(_bag)
	refilled.emit()
