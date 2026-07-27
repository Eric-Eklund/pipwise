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
## One line explaining the twist, e.g. "One die is frozen".
@export_multiline var boss_description : String = ""

@export_group("Content")
@export var deck_definition : DeckDefinition
@export var bag_definition : BagDefinition

@export_group("Limits")
@export_range(1, 12) var hand_size : int = 5
## Only used when no bag_definition is authored, to size the fallback bag.
@export_range(1, 12) var dice_count : int = 6
@export_range(0, 6) var max_rerolls : int = 3

@export_group("Costs")
## White energy to replace one card.
@export_range(0, 20) var card_swap_cost : int = 3
## White energy to keep one die through a reroll.
@export_range(0, 20) var die_lock_cost : int = 4

@export_group("Rules")
@export var evaluator : HandEvaluator
@export var objective : Objective
## Boss twists. Empty on an ordinary level.
@export var modifiers : Array[LevelModifier] = []

func get_deck_definition() -> DeckDefinition:
	return deck_definition if deck_definition != null else DeckDefinition.create_standard_52()

func get_bag_definition() -> BagDefinition:
	return bag_definition if bag_definition != null else StarterDice.create_starter_bag(dice_count)

func get_evaluator() -> HandEvaluator:
	return evaluator if evaluator != null else PokerHandEvaluator.new()

func get_objective() -> Objective:
	return objective if objective != null else ScoreTargetObjective.new()
