class_name Ruleset
extends Resource
## Everything that makes one level different from another.
##
## Designing a level means editing this resource, not writing code. The getters
## fall back to sensible defaults so a half-authored ruleset still produces a
## playable level rather than a crash.

@export var id : StringName = &"untitled"

@export_group("Presentation")
## Named on the boss banner. Empty on an ordinary level, which is what the HUD
## keys off to decide whether there is a banner at all.
@export var boss_name : String = ""
## One line explaining the twist, e.g. "Only Fire dice score".
@export_multiline var boss_description : String = ""

@export_group("Content")
## The dice the player brings. Null falls back to six plain d6s.
@export var bag_definition : BagDefinition
## Only used when no bag_definition is authored, to size the fallback bag.
@export_range(1, 12) var dice_count : int = 6

@export_group("Limits")
## Turns the level allows. Zero is unlimited — endless mode's shape, and a way
## to author a pure score race.
@export_range(0, 30) var turns : int = 5
## The fewest points a turn must be worth before it may be banked. Farkle's
## classic opening rule, and a real difficulty dial, because it forces a push.
@export_range(0, 5000) var minimum_bank : int = 0

@export_group("Costs")
## Points a Farkle takes off the banked score, on top of the turn it wipes.
## Shadow dice halve this and three of them reverse it.
@export_range(0, 2000) var farkle_penalty : int = 0

@export_group("Rules")
@export var objective : Objective
## Boss twists. Empty on an ordinary level.
@export var modifiers : Array[LevelModifier] = []

func get_bag_definition() -> BagDefinition:
	return bag_definition if bag_definition != null else StarterDice.create_starter_bag(dice_count)

func get_objective() -> Objective:
	return objective if objective != null else ScoreTargetObjective.new()

## What the level asks for, as a number, or 0 for an objective that is not a
## score target. The campaign curve and the balance probe both need this without
## caring which Objective subclass produced it.
func get_target_score() -> int:
	var target := get_objective()
	if target is ScoreTargetObjective:
		return (target as ScoreTargetObjective).target_score
	return 0
