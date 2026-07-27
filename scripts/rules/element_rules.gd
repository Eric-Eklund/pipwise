class_name ElementRules
extends RefCounted
## What the elements actually do, for one particular set of dice.
##
## Built once per roll from the dice on the table, then asked questions by the
## scorer. Doing it this way rather than with static functions means "does the
## Ice trio apply" is answered once and cannot disagree with itself halfway
## through scoring a selection.
##
## ## Where a trio is counted
##
## Trios are counted on the dice **in play** — everything the player is looking
## at, set aside or not — while section 2.1's combo multiplier is counted on the
## dice that actually **scored**. That split is deliberate. A trio changes what
## is possible (Ice makes pairs score at all), so the player has to be able to
## see it before they choose; a combo multiplier rewards what they chose, so it
## can only be known afterwards.
##
## ## Where these numbers come from
##
## Section 1.3 and 2.2 of docs/DESIGN.md, at their level-1 tier. Two of them are
## reinterpreted rather than transcribed, because the design document was written
## against a scoring table where every face scores and this game's does not —
## see the deviations section of that file. Ice's "pairs +100%" becomes "matched
## sets +100%", since a bare pair is worth nothing to add 100% to, and
## Lightning's trio escalates its own doubling to tripling rather than repeating
## it. Everything else is the document's own wording.

## Fewer than this many dice of one element and its trio does not fire.
const TRIO_THRESHOLD := 3

## The combo ladder from section 2.1, keyed by how many dice of the leading
## element scored. Anything not in here multiplies by 1.
const COMBO_MULTIPLIERS : Dictionary = {
	2: 1.5,
	3: 2.5,
	4: 4.0,
	5: 6.0,
	6: 10.0,
}

## Percentage bonuses, as fractions: 0.5 is "+50%".
const FIRE_SIX_BONUS := 0.5
const ICE_SET_BONUS := 1.0
const LIGHTNING_HIGH_BONUS := 1.0
const LIGHTNING_HIGH_BONUS_TRIO := 2.0
const CRYSTAL_ONE_BONUS := 2.0
const CRYSTAL_ONE_BONUS_TRIO := 3.0

## Flat trio bonuses.
const FIRE_TRIO_SIX_SET_BONUS := 200
const CRYSTAL_TRIO_STRAIGHT_BONUS := 1000
## What a Farkle pays instead of costing, once three Shadow dice are in play.
const SHADOW_TRIO_FARKLE_REWARD := 50

## How many dice of each element are in play, keyed by element.
var counts : Dictionary = {}

func _init(dice_in_play : Array[Die] = []) -> void:
	for die in dice_in_play:
		if die == null:
			continue
		counts[die.element] = int(counts.get(die.element, 0)) + 1

func count_of(element : StringName) -> int:
	return int(counts.get(element, 0))

func has_trio(element : StringName) -> bool:
	return count_of(element) >= TRIO_THRESHOLD

# --- what the scorer asks --------------------------------------------------

## Whether a bare pair scores as though it were a triple. The Ice trio's whole
## effect, and the only element rule that changes what *counts* as scoring
## rather than what it is worth — which is why the scorer takes these rules as
## an argument instead of reading them afterwards.
func pairs_score() -> bool:
	return has_trio(Element.ICE)

## The percentage bonus one die adds to its own share of its part, as a
## fraction. Elements that do not touch the score at all — Nature and Shadow —
## return zero here and are answered by the two functions below instead.
func die_bonus_fraction(die : Die, part : ScorePart) -> float:
	if die == null or part == null:
		return 0.0
	match die.element:
		Element.FIRE:
			return FIRE_SIX_BONUS if die.get_value() == 6 else 0.0
		Element.ICE:
			return ICE_SET_BONUS if part.is_matched_set() else 0.0
		Element.LIGHTNING:
			if die.get_value() < 4:
				return 0.0
			return LIGHTNING_HIGH_BONUS_TRIO if has_trio(Element.LIGHTNING) \
				else LIGHTNING_HIGH_BONUS
		Element.CRYSTAL:
			if die.get_value() != 1:
				return 0.0
			return CRYSTAL_ONE_BONUS_TRIO if has_trio(Element.CRYSTAL) \
				else CRYSTAL_ONE_BONUS
		_:
			return 0.0

## Flat points a trio adds to one part, on top of its base.
func part_bonus_points(part : ScorePart) -> int:
	if part == null:
		return 0
	var bonus := 0
	if has_trio(Element.FIRE) and part.is_matched_set() and part.value == 6:
		bonus += FIRE_TRIO_SIX_SET_BONUS
	if has_trio(Element.CRYSTAL) and part.kind == ScorePart.Kind.STRAIGHT:
		bonus += CRYSTAL_TRIO_STRAIGHT_BONUS
	return bonus

## Section 2.1's multiplier, from the most numerous element among the dice that
## scored. The leading element takes the whole selection with it rather than
## only its own share, which is what makes committing to one element a strategy
## instead of an accounting detail.
func combo_multiplier_for(scored_dice : Array[Die]) -> float:
	return float(COMBO_MULTIPLIERS.get(leading_element_count(scored_dice), 1.0))

## The element carrying the combo, and how many of it scored. Returns
## [Element.NONE, 0] when nothing scored or nothing repeats.
func leading_element(scored_dice : Array[Die]) -> Array:
	var tally : Dictionary = {}
	for die in scored_dice:
		if die == null or die.element == Element.NONE:
			continue
		tally[die.element] = int(tally.get(die.element, 0)) + 1

	var best_element : StringName = Element.NONE
	var best_count := 0
	# ALL rather than the dictionary's own key order, so a tie always resolves
	# the same way and a seeded run stays reproducible.
	for element in Element.ALL:
		var count := int(tally.get(element, 0))
		if count > best_count:
			best_element = element
			best_count = count
	return [best_element, best_count]

func leading_element_count(scored_dice : Array[Die]) -> int:
	return int(leading_element(scored_dice)[1])

# --- what the game asks ----------------------------------------------------

## How many dice Nature hands back after a scoring selection. Nature is the one
## element that pays in dice instead of points, so it is settled by the game
## loop rather than folded into the total.
##
## "Even sum" is the sum of the *pips* the scored dice are showing, not the
## points they earned. The document says only "jämn summa", but read as points
## it is not a condition at all: every entry in the scoring table is a multiple
## of fifty and every combo multiplier keeps it that way, so the total is even
## almost always and Nature would quietly mean "a free die, every single turn".
## Pips are a real coin flip, and they are what the player is looking at.
func dice_restored(scored_dice : Array[Die]) -> int:
	var pip_sum := 0
	var has_nature := false
	for die in scored_dice:
		if die == null:
			continue
		pip_sum += die.get_value()
		if die.element == Element.NATURE:
			has_nature = true
	if not has_nature or pip_sum <= 0 or pip_sum % 2 != 0:
		return 0
	return 2 if has_trio(Element.NATURE) else 1

## What a Farkle actually costs, given a penalty the level wanted to charge.
## Shadow softens it, and three Shadow dice turn it into a reward — which is the
## whole point of the element: it makes pushing your luck cheap enough to be
## reckless with.
func farkle_penalty(base_penalty : int) -> int:
	if has_trio(Element.SHADOW):
		return -SHADOW_TRIO_FARKLE_REWARD
	if count_of(Element.SHADOW) > 0:
		return int(round(base_penalty * 0.5))
	return base_penalty

## The trios currently firing, in Element.ALL order. The HUD lists these.
func active_trios() -> Array[StringName]:
	var result : Array[StringName] = []
	for element in Element.ALL:
		if has_trio(element):
			result.append(element)
	return result
