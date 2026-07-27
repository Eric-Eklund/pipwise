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
## Level 1's target. The design document's Novice band opens at 500.
@export var base_target : int = 600
## Added per level after the first.
@export var target_step : float = 190.0

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

## The elements each level hands out, as [element, how many] out of six. Levels
## not listed are plain dice. Authored rather than computed because "which
## element shows up when" is a teaching decision, and a formula would hide it.
const ELEMENT_SCHEDULE : Dictionary = {
	3: [Element.FIRE, 2],
	4: [Element.FIRE, 3],
	5: [Element.FIRE, 4],
	6: [Element.ICE, 3],
	7: [Element.ICE, 4],
	8: [Element.LIGHTNING, 3],
	10: [Element.FIRE, 5],
}

## Levels that hand out one die of every element instead of a single element.
const RAINBOW_LEVELS : Array[int] = [9]

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
func get_ruleset(level : int) -> Ruleset:
	var authored := "%s/level_%d.tres" % [RULESET_DIR, level]
	if ResourceLoader.exists(authored):
		var ruleset : Ruleset = load(authored)
		if ruleset != null:
			return ruleset
	return build_ruleset(level)

func target_for(level : int) -> int:
	return base_target + int(round(maxi(0, level - 1) * target_step))

func turns_for(level : int) -> int:
	return maxi(1, base_turns - (1 if level >= turn_cut_level else 0))

func penalty_for(level : int) -> int:
	return farkle_penalty if level >= penalty_from_level else 0

## The dice the player brings to [param level].
func bag_for(level : int) -> BagDefinition:
	if level in RAINBOW_LEVELS:
		return StarterDice.create_rainbow_bag()
	if ELEMENT_SCHEDULE.has(level):
		var entry : Array = ELEMENT_SCHEDULE[level]
		return StarterDice.create_element_bag(entry[0], int(entry[1]))
	return StarterDice.create_starter_bag()

func build_ruleset(level : int) -> Ruleset:
	var ruleset := Ruleset.new()
	ruleset.id = StringName("level_%d" % level)
	ruleset.bag_definition = bag_for(level)
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
