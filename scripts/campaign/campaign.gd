class_name Campaign
extends Resource
## Builds the ruleset for any level of the campaign.
##
## Ten levels are few enough to author and repetitive enough not to want to, so
## this does both: it computes an ordinary level from a curve, and hands over an
## authored .tres when one exists. Dropping a level_N.tres into
## resources/rulesets/ overrides level N and needs no code change.
##
## ## The shape of the ten levels
##
## The campaign teaches one thing at a time. Levels 1 and 2 are plain dice and
## nothing else, so the player learns what a Farkle costs before an element ever
## softens one. Elements arrive from level 3, and a trio — three dice of one
## element, where the interesting rules switch on — is first possible on level 4.
## The bosses sit on 5 and 10.
##
## ## Where the numbers came from
##
## tools/balance_probe.gd, not guesswork. It plays every level hundreds of times
## with a deliberately mediocre bot and reports the clear rate. Rerun it after
## changing a target, a turn count or a bag — all three move the whole curve.

const RULESET_DIR := "res://resources/rulesets"

@export_range(1, 200) var level_count : int = 10

@export_group("Score target")
## Fallback curve, used only past the end of the authored TARGETS table below.
@export var base_target : int = 900
@export var target_step : float = 300.0

@export_group("Turns")
@export_range(1, 30) var base_turns : int = 5
## From this level on the player gets one turn fewer. Taking a turn away bites
## far harder than raising the target, so it happens once and late.
@export var turn_cut_level : int = 8

@export_group("Farkle")
## From this level on a Farkle costs banked points too. Zero before it: losing
## the turn is punishment enough while the player is still learning what a
## Farkle even is.
@export var penalty_from_level : int = 6
@export var farkle_penalty : int = 100

## The elements each level hands out, as a list of [element, how many] out of
## six, padded with plain dice. Levels not listed are plain dice throughout.
##
## Authored rather than computed, because "which element shows up when" is a
## teaching decision and a formula would hide it. The order is also a power
## curve: one element, then a trio of it, then a second element, then two trios
## at once. Every step is measurably stronger than the one before, which is what
## lets the targets climb without a level ever feeling like a step backwards.
##
## All six elements are dealt across the ten levels, because a mega combo needs
## elements the player owns and grants only ever top the collection up — so an
## element no level hands out is one the loadout screen can never offer, and
## Elemental Master would be a rule about dice that do not exist.
##
## Shadow and Nature are paired with the levels that give them something to do
## rather than given levels of their own. Neither pays points — Shadow softens a
## Farkle and Nature returns dice — so a bag built around them scores nothing and
## would make the curve step backwards. Shadow lands on 6 because 6 is where the
## Farkle penalty starts (see penalty_from_level), and Nature lands on 7 beside
## Ice because both of them are about getting more takes out of a turn.
##
## Levels 8 and 9 are each two trios at once, which is the shape section 2.3's
## Chaos Mode asks for: three of one element and three of another both clear its
## "at least two of each", and one stray die of a third breaks it.
##
## Both keep Ice, and that is not laziness. Ice is far and away the strongest
## element, because promoting bare pairs to triples means fewer Farkles *and*
## more scoring dice at once — measurably worth more than any two other trios
## together. A level 9 without it scored barely half of level 8 and made the last
## ordinary level of the campaign a step down. Crystal rides along on 9 instead,
## where its 1s pay quadruple and Chaos doubles that again.
const ELEMENT_SCHEDULE : Dictionary = {
	3: [[Element.FIRE, 2]],
	4: [[Element.FIRE, 3]],
	5: [[Element.FIRE, 4]],
	6: [[Element.LIGHTNING, 3], [Element.SHADOW, 2]],
	7: [[Element.ICE, 3], [Element.NATURE, 2]],
	8: [[Element.ICE, 3], [Element.FIRE, 3]],
	9: [[Element.ICE, 3], [Element.CRYSTAL, 3]],
	10: [[Element.FIRE, 5]],
}

## What each level asks for, measured with tools/balance_probe.gd rather than
## computed. The curve below is only a fallback for a level past the end of this
## table.
##
## A formula cannot do this job. Every level hands out a different bag, and an
## element changes what a turn is worth by far more than a linear step could
## track — three Ice dice roughly double a turn on their own, because pairs
## scoring means fewer Farkles *and* more points. Targets that ignored that
## would make level 7 trivial and level 9 impossible.
##
## Levels 1 and 2 are the same ruleset with the same plain bag, so the only thing
## that can separate them is this number. One is set a little under its measured
## half-way mark on purpose — it is the first thing anybody plays, and losing it
## teaches nothing that level 2 will not teach a minute later.
const TARGETS : Dictionary = {
	1: 2000,
	2: 2150,
	3: 2700,
	4: 3700,
	5: 4600,
	6: 5300,
	7: 13600,
	8: 14400,
	9: 19000,
	10: 2250,
}

## The bosses, keyed by level. Kept here rather than in .tres files because a
## boss is two lines of data and one modifier; the .tres override still exists
## for one that turns out to need more.
const BOSSES : Dictionary = {
	5: {
		"name": "Ember Warden",
		"description": "Nothing banks below 500. You have to push.",
	},
	10: {
		"name": "Fire Lord",
		"description": "Only Fire dice score. Everything else is dead weight.",
	},
}

func is_boss(level : int) -> bool:
	return not get_ruleset(level).boss_name.is_empty()

## The authored ruleset for [param level] if there is one, otherwise a computed
## level. Never returns null.
##
## [param loadout] is what the player equipped. Null falls back to the reference
## bag, which is what the balance probe and the tests want and what a level
## dropped into the editor with nothing configured needs to still be playable.
func get_ruleset(level : int, loadout : BagDefinition = null) -> Ruleset:
	var authored := "%s/level_%d.tres" % [RULESET_DIR, level]
	if ResourceLoader.exists(authored):
		var ruleset : Ruleset = load(authored)
		if ruleset != null:
			return ruleset
	return build_ruleset(level, loadout)

func target_for(level : int) -> int:
	if TARGETS.has(level):
		return int(TARGETS[level])
	return base_target + int(round(maxi(0, level - 1) * target_step))

func turns_for(level : int) -> int:
	return maxi(1, base_turns - (1 if level >= turn_cut_level else 0))

func penalty_for(level : int) -> int:
	return farkle_penalty if level >= penalty_from_level else 0

## The bag [param level]'s target was measured against.
##
## Not necessarily what the player brings — they equip from their own collection
## now. This is the reference: the floor a level lends up to, and the set the
## balance probe measures. Renamed from bag_for() so that nothing can quietly
## treat it as the loadout again.
func reference_bag_for(level : int) -> BagDefinition:
	if ELEMENT_SCHEDULE.has(level):
		return StarterDice.create_mixed_bag(ELEMENT_SCHEDULE[level])
	return StarterDice.create_starter_bag()

## What clearing [param level] adds to the collection, as a bag to top up to.
##
## The same data as the reference bag, deliberately. A separate drop table would
## be a second place to keep in sync with the curve, and it would drift: the
## targets were measured against these exact dice, so these are the dice the
## player has to end up owning.
func grant_for(level : int) -> BagDefinition:
	return reference_bag_for(level)

## Whether [param level] is where the player gets to choose a build. The start of
## a run, because that is where a build is chosen at all, and the bosses, because
## a twist is the only thing that forces a rethink. Not every level: ten loadout
## screens per run is friction, and nine of them would have nothing new to decide.
##
## Note what this deliberately no longer means. It used to also mark where a lost
## run resumed, and that made a loss a non-event — the attempt restarted where it
## died, so nothing was ever risked. Every run starts at level 1 now.
func offers_a_loadout(level : int) -> bool:
	return level == 1 or BOSSES.has(level)

## The number in a path like "res://…/level_7.tscn", or -1 for anything without
## one — which is what endless is.
##
## Static and here rather than in the two places that used to parse it for
## themselves: the level select menu sorts by it and the level manager reads it
## off the current scene, and two copies of the same parser is one copy too many.
static func level_number_from_path(level_path : String) -> int:
	var name := level_path.get_file().trim_suffix(".tscn")
	var digits := ""
	for index in range(name.length() - 1, -1, -1):
		if not name[index].is_valid_int():
			break
		digits = name[index] + digits
	return int(digits) if digits.is_valid_int() else -1

func build_ruleset(level : int, loadout : BagDefinition = null) -> Ruleset:
	var ruleset := Ruleset.new()
	ruleset.id = StringName("level_%d" % level)
	# The loadout is raised to the level's reference bag rather than trusted as
	# it stands. It was chosen at the last checkpoint and the references escalate
	# behind it, so without this a build picked on level 1 walks into level 9.
	ruleset.bag_definition = DiceCollection.apply_floor(loadout, reference_bag_for(level))
	ruleset.turns = turns_for(level)
	ruleset.farkle_penalty = penalty_for(level)

	var objective := ScoreTargetObjective.new()
	objective.target_score = target_for(level)
	ruleset.objective = objective

	_apply_boss(ruleset, level)
	return ruleset

## A boss is an ordinary level with a name and one twist. Applied last so it can
## override anything the curve decided.
func _apply_boss(ruleset : Ruleset, level : int) -> void:
	if not BOSSES.has(level):
		return
	var boss : Dictionary = BOSSES[level]
	ruleset.boss_name = String(boss["name"])
	ruleset.boss_description = String(boss["description"])

	match level:
		5:
			var gate := MinimumBankModifier.new()
			gate.minimum = 500
			ruleset.modifiers = [gate] as Array[LevelModifier]
		10:
			var lock := ElementLockModifier.new()
			lock.element = Element.FIRE
			ruleset.modifiers = [lock] as Array[LevelModifier]
