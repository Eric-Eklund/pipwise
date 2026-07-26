class_name StarterDice
extends RefCounted
## Factory for the starting die type.
##
## Kept separate from DieType so the data classes stay free of any concrete
## action. Once dice are authored as .tres files in the editor this becomes a
## fallback rather than the source of truth.

## Six faces: two redraws, a lock, an extra card, and two multipliers.
## Redraw appears twice because it is the face that always has a use.
static func create_action_d6() -> DieType:
	var die := DieType.new()
	die.id = &"action_d6"

	var faces : Array[DieFace] = []
	faces.append(DieFace.create(&"redraw", _redraw(), "Redraw"))
	faces.append(DieFace.create(&"redraw", _redraw(), "Redraw"))
	faces.append(DieFace.create(&"lock", _lock(), "Lock"))
	faces.append(DieFace.create(&"draw", _draw_extra(1), "+1 Card"))
	faces.append(DieFace.create(&"mult_small", _multiplier(0.5), "x1.5"))
	faces.append(DieFace.create(&"mult_big", _multiplier(1.0), "x2"))
	die.faces = faces
	return die

## A bag of six identical action dice.
static func create_starter_bag(count : int = 6) -> BagDefinition:
	var definition := BagDefinition.create_uniform(create_action_d6(), count)
	definition.id = &"starter_bag"
	return definition

static func _redraw() -> RedrawCardsAction:
	var action := RedrawCardsAction.new()
	action.description = "Discard the selected cards and draw replacements."
	return action

static func _lock() -> LockCardAction:
	var action := LockCardAction.new()
	action.description = "Lock the selected cards so a redraw skips them."
	return action

static func _draw_extra(amount : int) -> DrawExtraCardAction:
	var action := DrawExtraCardAction.new()
	action.amount = amount
	action.description = "Widen the hand by %d and fill it." % amount
	return action

static func _multiplier(bonus : float) -> ScoreMultiplierAction:
	var action := ScoreMultiplierAction.new()
	action.bonus = bonus
	action.description = "Raise the next hand's multiplier by %.1f." % bonus
	return action
