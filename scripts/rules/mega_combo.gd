class_name MegaCombo
extends RefCounted
## Section 2.3's mega combos: the three shapes a *selection* can have that pay
## more than the dice in it are worth.
##
## Pure data and lookups, exactly like Element. What a mega combo *does* lives in
## ElementRules, so that this file stays loadable by the view layer — the banner
## and the guide window need a name and a colour and have no rules object to ask.
##
## ## Why these exist at all
##
## The first decision of a Farkle turn is how much of the roll to keep, and until
## these it had one right answer: everything. The scorer said so in a comment. It
## was wrong even then — see FarkleScorer.best_selection on how an Ice trio and a
## plain die quietly dilute each other — but it was close enough to true that the
## take was never a decision anybody made.
##
## Two of these three make it one, deliberately. Chaos Mode asks that every
## element present appears at least twice, and Universal Overload that every die
## shows a 6. Both are conditions a *further* die can destroy, so a smaller
## selection is sometimes worth a great deal more than a larger one, and the
## player has to look. Elemental Master cannot be broken this way and does not
## need to be — it is what makes the rainbow bag worth owning at all.

const NONE : StringName = &"none"
const ELEMENTAL_MASTER : StringName = &"elemental_master"
const UNIVERSAL_OVERLOAD : StringName = &"universal_overload"
const CHAOS_MODE : StringName = &"chaos_mode"

## Rarest first. detect() returns the first that fires, so a selection that
## satisfies two never reads as the cheaper one.
const ALL : Array[StringName] = [UNIVERSAL_OVERLOAD, ELEMENTAL_MASTER, CHAOS_MODE]

## What Elemental Master multiplies the whole selection by, replacing section
## 2.1's ladder rather than stacking on it. See ElementRules.combo_multiplier_for.
const MASTER_MULTIPLIER := 5.0
## Universal Overload's flat award, paid outside the multiplier.
const OVERLOAD_BONUS := 5000
## The face every die must show for Universal Overload.
const OVERLOAD_FACE := 6
## What Chaos Mode multiplies the element-bonus portion by — never the base.
const CHAOS_BONUS_MULTIPLIER := 2.0
## Chaos needs this many distinct elements, each appearing at least this often.
##
## The design document says three distinct. It is two here because with six dice
## a three-element rule can only ever be satisfied by exactly 2+2+2, and nothing
## larger can break that — so at three it would create no decision and fire on no
## bag the campaign ships. See the deviations section of docs/DESIGN.md.
const CHAOS_MINIMUM_ELEMENTS := 2
const CHAOS_MINIMUM_PER_ELEMENT := 2

const DISPLAY_NAMES : Dictionary = {
	NONE: "",
	ELEMENTAL_MASTER: "Elemental Master",
	UNIVERSAL_OVERLOAD: "Universal Overload",
	CHAOS_MODE: "Chaos Mode",
}

const SYMBOLS : Dictionary = {
	NONE: "",
	ELEMENTAL_MASTER: "🌟",
	UNIVERSAL_OVERLOAD: "☄️",
	CHAOS_MODE: "🔮",
}

## Deliberately not element colours. A mega combo is a shape across several
## elements, so tinting it with any one of them would name the wrong thing.
const COLORS : Dictionary = {
	NONE: Color(0.98, 0.95, 0.88),
	ELEMENTAL_MASTER: Color("#FFE066"),
	UNIVERSAL_OVERLOAD: Color("#FF8C42"),
	CHAOS_MODE: Color("#B388FF"),
}

const DESCRIPTIONS : Dictionary = {
	NONE: "",
	ELEMENTAL_MASTER: "One die of every element, scored together.",
	UNIVERSAL_OVERLOAD: "Every element, and every one of them showing a 6.",
	CHAOS_MODE: "Every element you take, taken at least twice.",
}

## What the combo is worth, as the player reads it on the banner.
const EFFECT_TEXTS : Dictionary = {
	NONE: "",
	ELEMENTAL_MASTER: "x5",
	UNIVERSAL_OVERLOAD: "x5 +5000",
	CHAOS_MODE: "element bonuses x2",
}

# --- detection --------------------------------------------------------------

## Which mega combo [param scored_dice] forms, or NONE.
##
## Counted on the dice that *scored*, like section 2.1's ladder and unlike the
## element trios. A trio changes what is possible, so the player has to see it
## before choosing; a combo rewards what they chose, so it can only be known
## afterwards. See the class comment of ElementRules.
static func detect(scored_dice : Array[Die]) -> StringName:
	var counts := _element_counts(scored_dice)
	if counts.is_empty():
		return NONE

	if counts.size() == Element.ALL.size():
		# Overload is Master plus a condition, so it has to be tested first.
		if _every_die_shows(scored_dice, OVERLOAD_FACE):
			return UNIVERSAL_OVERLOAD
		return ELEMENTAL_MASTER

	if counts.size() < CHAOS_MINIMUM_ELEMENTS:
		return NONE
	for element in counts:
		if int(counts[element]) < CHAOS_MINIMUM_PER_ELEMENT:
			return NONE
	return CHAOS_MODE

## How many of each real element scored.
##
## Element.NONE is skipped, because a plain die carries no element rather than a
## seventh one. Counting it would fire Chaos Mode on two Fire dice and four
## pieces of padding — a hand every level from 3 on can roll — and would also
## make a plain die something the player had to drop, which is nonsense: there is
## nothing elemental about it to dilute.
static func _element_counts(scored_dice : Array[Die]) -> Dictionary:
	var counts : Dictionary = {}
	for die in scored_dice:
		if die == null or die.element == Element.NONE:
			continue
		counts[die.element] = int(counts.get(die.element, 0)) + 1
	return counts

static func _every_die_shows(scored_dice : Array[Die], value : int) -> bool:
	for die in scored_dice:
		if die == null or die.get_value() != value:
			return false
	return true

# --- what it pays -----------------------------------------------------------

## The multiplier this combo puts a floor under. 1.0 means it does not touch the
## whole-selection multiplier at all.
static func multiplier_floor_for(id : StringName) -> float:
	if id == ELEMENTAL_MASTER or id == UNIVERSAL_OVERLOAD:
		return MASTER_MULTIPLIER
	return 1.0

## What this combo multiplies the element-bonus portion by. 1.0 is "no change".
static func element_bonus_multiplier_for(id : StringName) -> float:
	return CHAOS_BONUS_MULTIPLIER if id == CHAOS_MODE else 1.0

## Flat points this combo awards, paid outside the multiplier.
static func flat_bonus_for(id : StringName) -> int:
	return OVERLOAD_BONUS if id == UNIVERSAL_OVERLOAD else 0

# --- how it reads -----------------------------------------------------------

static func get_display_name(id : StringName) -> String:
	return String(DISPLAY_NAMES.get(id, ""))

static func get_symbol(id : StringName) -> String:
	return String(SYMBOLS.get(id, ""))

static func get_color(id : StringName) -> Color:
	return COLORS.get(id, COLORS[NONE])

static func get_description(id : StringName) -> String:
	return String(DESCRIPTIONS.get(id, ""))

static func get_effect_text(id : StringName) -> String:
	return String(EFFECT_TEXTS.get(id, ""))

## Symbol and name together, e.g. "🔮 Chaos Mode".
static func get_label(id : StringName) -> String:
	var symbol := get_symbol(id)
	if symbol.is_empty():
		return get_display_name(id)
	return "%s %s" % [symbol, get_display_name(id)]
