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

func element_bonus_multiplier(card_element : StringName) -> float:
	return multiplier if card_element == element else 1.0
