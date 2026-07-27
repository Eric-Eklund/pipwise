class_name DiceScore
extends RefCounted
## What a selection of dice is worth, kept in the pieces it was built from.
##
## Nothing is pre-multiplied and nothing is collapsed early, because the appeal
## of the scoring is watching "(600 + 300) x2.5 = 2250" resolve. A single total
## would be cheaper to carry and would leave the HUD guessing where it came
## from.
##
## An invalid score is a real result rather than an error: selecting a die that
## does not contribute is the most ordinary mistake in Farkle, and the game
## answers it by greying out the button, not by refusing to compute.

## The scoring units the selection broke into. Empty on an invalid or empty one.
var parts : Array[ScorePart] = []
## Sum of the parts' base points, before elements.
var base_points : int = 0
## Flat points added by element trios, e.g. Fire's +200 on a triple of 6.
var bonus_points : int = 0
## Percentage bonuses the individual dice earned. A float until the very end,
## so a chain of +50%s does not lose a point per part to rounding.
var element_bonus : float = 0.0
## The element carrying section 2.1's combo, and how many of it scored.
var combo_element : StringName = Element.NONE
var combo_count : int = 0
var combo_multiplier : float = 1.0
## Dice Nature hands back to the table after this selection is banked.
var dice_restored : int = 0
## Dice in the selection that contribute nothing. Non-zero means the player has
## picked something they cannot keep, and the selection cannot be taken.
var leftover_count : int = 0

## Whether this selection may actually be set aside: at least one die, and every
## die in it pulling its weight.
func is_valid() -> bool:
	return not parts.is_empty() and leftover_count == 0

func is_scoring() -> bool:
	return total() > 0

## Everything before the combo multiplier.
func subtotal() -> float:
	return float(base_points + bonus_points) + element_bonus

## Rounded exactly once, here, so no two callers can disagree about the number.
func total() -> int:
	if not is_valid():
		return 0
	return int(round(subtotal() * combo_multiplier))

## The multiplier as the player reads it: "x4", not "x4.0", but still "x1.5".
func multiplier_text() -> String:
	if is_equal_approx(combo_multiplier, roundf(combo_multiplier)):
		return "x%d" % int(roundf(combo_multiplier))
	return "x%.1f" % combo_multiplier

## Names the shapes that scored, e.g. "Three 6s + Single 1".
func parts_text() -> String:
	if parts.is_empty():
		return ""
	var labels : Array[String] = []
	for part in parts:
		labels.append(part.get_label())
	return " + ".join(labels)

## Names the combo, e.g. "🔥 Fire x4". Empty when nothing repeated enough to
## earn one, which is also when the multiplier is 1 and there is nothing to say.
func combo_text() -> String:
	if combo_count < 2 or combo_element == Element.NONE:
		return ""
	return "%s %s" % [Element.get_label(combo_element), multiplier_text()]

## The full sum as the player reads it, e.g. "(600 + 300) x2.5 = 2250". The
## element bonus is folded in with the base rather than shown separately —
## three numbers is a breakdown, four is a spreadsheet.
func breakdown_text() -> String:
	if not is_valid():
		return ""
	var bonus := int(round(element_bonus + bonus_points))
	if bonus == 0 and is_equal_approx(combo_multiplier, 1.0):
		return str(total())
	if is_equal_approx(combo_multiplier, 1.0):
		return "%d + %d = %d" % [base_points, bonus, total()]
	return "(%d + %d) %s = %d" % [base_points, bonus, multiplier_text(), total()]

## Every die that scored, across all parts.
func get_dice() -> Array[Die]:
	var result : Array[Die] = []
	for part in parts:
		result.append_array(part.dice)
	return result

func _to_string() -> String:
	if not is_valid():
		return "invalid selection"
	return "%s: %s" % [parts_text(), breakdown_text()]
