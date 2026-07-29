class_name ElementBoostCard
extends Card
## A potion that doubles one element's bonus for the rest of the turn.
##
## One parameterised class rather than four nearly identical ones, the same way
## ElementLockModifier covers every possible boss lock with an exported element.
##
## ## Why only four of the six potions are this
##
## Section 3.3 gives every element a potion, but two of those elements do not pay
## points at all: Nature hands back dice and Shadow softens a Farkle. Doubling a
## bonus they never earn is doubling zero, so Earth Restore and Shadow Veil are
## their own classes and this covers Fire, Ice, Lightning and Crystal.
##
## Section 3.3's own wording is kept where it survived. Frost Shield reads "+100%
## pair bonus", which is exactly this. Crystal Focus read "triples all 1s", which
## Crystal already does on its own — see the deviations section of
## docs/DESIGN.md.

## How much the element's bonus is multiplied by while this is active.
@export var multiplier : float = 2.0

## Refused on a board that has none of its element.
##
## Doubling a share of the score that no die on the table can earn is doubling
## zero, and the campaign deals no elements at all until level 3 — so on the two
## levels where a new player meets the hand, every potion in it was bright,
## buyable and worth nothing. Second Wind already makes this guard for the same
## reason: greyed out beats taking the energy for free.
##
## It costs the design document one line, which docs/DESIGN.md now carries: a
## potion for an element you did not bring was meant to read as a bad draw the
## player works around. It read as a broken card instead. It is still a bad
## draw — it just cannot be spent on nothing while it waits for its level.
func can_play(game) -> bool:
	return _element_is_in_play(game)

func get_refusal(_game) -> String:
	return "No %s dice on the table." % Element.get_label(element)

func element_bonus_multiplier(card_element : StringName) -> float:
	return multiplier if card_element == element else 1.0
