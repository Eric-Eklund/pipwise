class_name HandScore
extends RefCounted
## What a hand is worth, kept in the pieces it was built from.
##
## Nothing is pre-multiplied, and the cards and the dice stay apart, because the
## whole appeal of the scoring is watching "(35 + 21) x 2" resolve into 112. A
## single total would be cheaper to carry and would make the HUD guess.

## Sum of the cards' values: 2-10 their pips, J/Q/K 11/12/13, ace 14.
var card_points : int = 0
## Sum of the pips showing on the dice.
var dice_points : int = 0
var multiplier : float = 1.0
## Human-readable name of the shape, e.g. "Two Pair".
var label : String = ""
## The PokerHandClassifier.Category this scored as, or -1 for an empty hand.
## Carried so objectives and the HUD can ask what the hand *is* without
## classifying it a second time.
var category : int = -1

func _init(
	cards : int = 0,
	dice : int = 0,
	mult : float = 1.0,
	score_label : String = "",
	score_category : int = -1
) -> void:
	card_points = cards
	dice_points = dice
	multiplier = mult
	label = score_label
	category = score_category

func base_points() -> int:
	return card_points + dice_points

func total() -> int:
	return int(round(base_points() * multiplier))

func is_scoring() -> bool:
	return base_points() > 0

## The multiplier as the player reads it: "x2", not "x2.0", but still "x7.5"
## when a boss bonus lands on a half.
func multiplier_text() -> String:
	if is_equal_approx(multiplier, roundf(multiplier)):
		return "x%d" % int(roundf(multiplier))
	return "x%.1f" % multiplier

## The full sum, e.g. "(35 + 21) x 2 = 112".
func breakdown_text() -> String:
	return "(%d + %d) %s = %d" % [card_points, dice_points, multiplier_text(), total()]

func _to_string() -> String:
	return "%s: %s" % [label, breakdown_text()]
