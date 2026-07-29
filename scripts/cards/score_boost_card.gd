class_name ScoreBoostCard
extends Card
## Score Boost: matched sets pay half again until the dice are rolled next.
##
## The one card that changes what a selection is worth, so it is also the one
## that goes through ElementRules rather than doing anything itself — the same
## seam the elements use, and the reason FarkleScorer still does not know cards
## exist.
##
## ## Why matched sets rather than "pairs"
##
## A bare pair is worth nothing in this game unless an Ice trio is promoting
## pairs, so "+50% on pairs" would be +50% of zero on almost every board — the
## trap deviation 8 of docs/DESIGN.md keeps catching. What the player actually
## reads as a pair here is a matched set: three 4s, four 6s, and the promoted
## pair when Ice is out. That is `ScorePart.is_matched_set()`, and it is what
## this pays on.
##
## Straights, three pairs and lone 1s and 5s are left alone. Adding the whole
## board would make this a flat multiplier on everything, which is what the
## element combo ladder already is.
##
## The points land in the part's bonus rather than its base, beside what an
## element trio adds, so Chaos Mode doubles them along with everything else in
## that term. That is a synergy rather than an oversight: a mega combo that
## doubled the elements and pointedly not the card would be a rule with an
## exception in it.

## What a matched set pays on top, as a fraction of its base.
@export var bonus_fraction : float = 0.5

func part_bonus_fraction(part : ScorePart) -> float:
	return bonus_fraction if part != null and part.is_matched_set() else 0.0
