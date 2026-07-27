class_name FarkleScorer
extends RefCounted
## Turns a selection of dice into what it is worth, and answers the one question
## the whole game hangs on: does this roll score at all?
##
## Stateless on purpose — every function is static and takes the dice and the
## element rules it needs. Scoring is asked for after every tap, so it must be
## cheap and it must never depend on something that happened earlier.
##
## ## The scoring table
##
## Section 1.2 of docs/DESIGN.md, with one deliberate change recorded in that
## file's deviations: single dice score only on 1 and 5. The document's base
## column scores every face, which would mean no roll can ever fail, no Farkle
## can ever happen, and "Continue" is free — the push-your-luck core the game is
## named after would not exist. The triple and beyond columns are the document's
## own numbers, untouched, because they already are classic Farkle.
##
##     Single      1 = 100      5 = 50
##     Triple      three 1s = 1000, three N = N x 100
##     Beyond      each die past the third doubles the triple
##     Straight    1-6 = 1500
##     Three pairs = 1500

const SINGLE_POINTS : Dictionary = {1: 100, 5: 50}
## Three of a kind. Every other count is derived from these by doubling.
const TRIPLE_POINTS : Dictionary = {1: 1000, 2: 200, 3: 300, 4: 400, 5: 500, 6: 600}
const STRAIGHT_POINTS := 1500
const THREE_PAIRS_POINTS := 1500
## A straight and three pairs both need the whole table.
const WHOLE_SET_SIZE := 6

# --- the questions the game asks -------------------------------------------

## What [param dice] is worth as a selection. An unscoreable die in the
## selection does not raise — it comes back as leftover_count, and the result
## reports itself invalid.
static func score(dice : Array[Die], rules : ElementRules = null) -> DiceScore:
	var element_rules := rules if rules != null else ElementRules.new()
	var best : DiceScore = null
	for candidate in _decompositions(dice, element_rules):
		var scored := _apply_elements(candidate, element_rules)
		if best == null or _is_better(scored, best):
			best = scored
	return best if best != null else DiceScore.new()

## Whether anything in [param dice] scores. False is a Farkle, and a Farkle is
## the only thing standing between the player and infinite points, so this is
## the single most load-bearing function in the engine.
static func has_scoring_dice(dice : Array[Die], rules : ElementRules = null) -> bool:
	return not score(dice, rules).parts.is_empty()

## Every die in [param dice] that contributes to the best selection. What the
## view highlights, and what the "take everything" button takes.
##
## Taking everything that scores is always at least as good as taking less: no
## entry in the table pays less for more dice, and adding a die can only raise
## the count of the element leading the combo. So this really is the best
## selection and not merely a convenient one.
static func best_selection(dice : Array[Die], rules : ElementRules = null) -> Array[Die]:
	return score(dice, rules).get_dice()

## Whether one die could belong to a scoring selection at all. Used to grey out
## the dice the player cannot pick, so that an illegal selection is unreachable
## rather than merely rejected.
static func is_scoring_die(die : Die, dice : Array[Die], rules : ElementRules = null) -> bool:
	return die in best_selection(dice, rules)

# --- decomposition ---------------------------------------------------------

## The ways this selection could break down. Usually one; six dice may also form
## a straight or three pairs, and those are worth comparing against the ordinary
## reading rather than assumed to win.
static func _decompositions(dice : Array[Die], rules : ElementRules) -> Array:
	var candidates : Array = []
	if dice.is_empty():
		return candidates

	var whole_set := _whole_set_part(dice)
	if whole_set != null:
		var parts : Array[ScorePart] = [whole_set]
		candidates.append({"parts": parts, "leftover": 0})
	candidates.append(_greedy(dice, rules))
	return candidates

## A straight or three pairs, when the selection is the whole table and forms
## one. Null otherwise.
static func _whole_set_part(dice : Array[Die]) -> ScorePart:
	if dice.size() != WHOLE_SET_SIZE:
		return null
	var by_value := _group_by_value(dice)

	# One of each 1-6. Guarded on the values rather than only the count, so a
	# larger die type cannot accidentally read as a straight.
	if by_value.size() == WHOLE_SET_SIZE:
		var is_straight := true
		for value in range(1, WHOLE_SET_SIZE + 1):
			if not by_value.has(value):
				is_straight = false
				break
		if is_straight:
			return ScorePart.new(ScorePart.Kind.STRAIGHT, dice.duplicate(), 0, STRAIGHT_POINTS)

	# Three values, two dice each.
	if by_value.size() == 3:
		var all_pairs := true
		for value in by_value:
			if by_value[value].size() != 2:
				all_pairs = false
				break
		if all_pairs:
			return ScorePart.new(
				ScorePart.Kind.THREE_PAIRS, dice.duplicate(), 0, THREE_PAIRS_POINTS
			)
	return null

## The ordinary reading: take every matched set, then every 1 and 5 left over.
## Anything still standing is a die the player cannot keep.
static func _greedy(dice : Array[Die], rules : ElementRules) -> Dictionary:
	var by_value := _group_by_value(dice)
	var parts : Array[ScorePart] = []
	var leftover := 0

	var values := by_value.keys()
	values.sort()
	for value in values:
		var group : Array[Die] = by_value[value]
		var count := group.size()

		if count >= 3:
			parts.append(ScorePart.new(
				ScorePart.Kind.SET, group, value, set_points(value, count)
			))
			continue

		# The Ice trio's doing: a bare pair scores as though it were a triple,
		# which is always worth more than the two singles it might otherwise
		# have been.
		if count == 2 and rules.pairs_score():
			parts.append(ScorePart.new(
				ScorePart.Kind.SET, group, value, triple_points(value)
			))
			continue

		if SINGLE_POINTS.has(value):
			for die in group:
				var single : Array[Die] = [die]
				parts.append(ScorePart.new(
					ScorePart.Kind.SINGLE, single, value, int(SINGLE_POINTS[value])
				))
			continue

		leftover += count

	return {"parts": parts, "leftover": leftover}

# --- the table -------------------------------------------------------------

## Three of a kind. Falls back to value x 100 for faces past 6, which is the
## pattern the design document's D8/D10/D12 expansion follows.
static func triple_points(value : int) -> int:
	return int(TRIPLE_POINTS.get(value, value * 100))

## A matched set of any size. Every die past the third doubles it, which is the
## document's 2000/4000/8000 column exactly.
static func set_points(value : int, count : int) -> int:
	if count < 3:
		return 0
	return triple_points(value) * (1 << (count - 3))

# --- elements --------------------------------------------------------------

## Folds the element bonuses and the combo multiplier into a decomposition.
static func _apply_elements(candidate : Dictionary, rules : ElementRules) -> DiceScore:
	var result := DiceScore.new()
	result.parts = candidate["parts"]
	result.leftover_count = int(candidate["leftover"])

	for part in result.parts:
		result.base_points += part.base_points
		part.bonus_points = rules.part_bonus_points(part)
		result.bonus_points += part.bonus_points
		# A percentage of the die's own share of its part, so the same +50%
		# means more inside a triple of 6 than on a lone 5.
		var share := part.share_per_die()
		for die in part.dice:
			result.element_bonus += share * rules.die_bonus_fraction(die, part)

	var scored := result.get_dice()
	var lead := rules.leading_element(scored)
	result.combo_element = lead[0]
	result.combo_count = int(lead[1])
	result.combo_multiplier = rules.combo_multiplier_for(scored)
	result.dice_restored = rules.dice_restored(scored)
	return result

## A valid selection always beats an invalid one, however many points the
## invalid one claims — the player cannot take it, so its total is fiction.
static func _is_better(candidate : DiceScore, incumbent : DiceScore) -> bool:
	if candidate.is_valid() != incumbent.is_valid():
		return candidate.is_valid()
	return candidate.total() > incumbent.total()

# --- helpers ---------------------------------------------------------------

## Face value to the dice showing it. Dice that have not been rolled are
## skipped: a value of zero is "not rolled yet", not a face.
static func _group_by_value(dice : Array[Die]) -> Dictionary:
	var groups : Dictionary = {}
	for die in dice:
		if die == null:
			continue
		var value := die.get_value()
		if value <= 0:
			continue
		if not groups.has(value):
			groups[value] = [] as Array[Die]
		groups[value].append(die)
	return groups
