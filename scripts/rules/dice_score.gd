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
## Section 2.3's mega combo, or MegaCombo.NONE. Kept apart from combo_element
## because a mega is not an element — it is a shape across several of them, and
## tinting or naming it with any one would say the wrong thing.
var mega_combo : StringName = MegaCombo.NONE
## Chaos Mode's multiplier on the element-bonus portion. 1.0 is "no Chaos", and
## every field below defaults so that the sum reduces to what it was before mega
## combos existed.
var element_bonus_multiplier : float = 1.0
## Universal Overload's flat award, paid outside the multiplier.
var mega_bonus_points : int = 0
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
##
## Chaos Mode doubles the element portion and never the base. The base is what
## the dice are worth as dice, and no element rule has ever touched it — letting
## a mega combo do so would make Chaos strictly dominate section 2.1's ladder
## instead of competing with it.
func subtotal() -> float:
	return float(base_points) + (float(bonus_points) + element_bonus) * element_bonus_multiplier

## Rounded exactly once, here, so no two callers can disagree about the number.
##
## Universal Overload's flat award lands *outside* the multiplier. Inside it, on
## the six 6s that are the only hand which fires it, +5000 would become +25000
## and the number would stop meaning anything.
func total() -> int:
	if not is_valid():
		return 0
	return int(round(subtotal() * combo_multiplier)) + mega_bonus_points

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
##
## A mega combo outranks the element one, because the mega is the thing the
## player did. It carries its own effect text rather than multiplier_text(): for
## Chaos, combo_multiplier still holds the section 2.1 ladder, which has nothing
## to do with Chaos's doubling, and printing it there would be a lie.
func combo_text() -> String:
	if mega_combo != MegaCombo.NONE:
		return "%s %s" % [MegaCombo.get_label(mega_combo), MegaCombo.get_effect_text(mega_combo)]
	if combo_count < 2 or combo_element == Element.NONE:
		return ""
	return "%s %s" % [Element.get_label(combo_element), multiplier_text()]

## The full sum as the player reads it, e.g. "(600 + 300) x2.5 = 2250". The
## element bonus is folded in with the base rather than shown separately —
## three numbers is a breakdown, four is a spreadsheet.
func breakdown_text() -> String:
	if not is_valid():
		return ""
	# Chaos is folded into the bonus term rather than shown as its own step. The
	# player can see the doubling in the combo line above; repeating it here would
	# turn a sum into a derivation.
	var bonus := int(round((element_bonus + float(bonus_points)) * element_bonus_multiplier))
	if mega_bonus_points > 0:
		return "(%d + %d) %s + %d = %d" % [
			base_points, bonus, multiplier_text(), mega_bonus_points, total()
		]
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
