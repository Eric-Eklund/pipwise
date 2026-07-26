class_name Ruleset
extends Resource
## Everything that makes one level different from another.
##
## Designing a level means editing this resource, not writing code. The
## getters fall back to sensible defaults so a half-authored ruleset still
## produces a playable level rather than a crash.

@export var id : StringName = &"untitled"

@export_group("Content")
@export var deck_definition : DeckDefinition
@export var bag_definition : BagDefinition

@export_group("Limits")
@export_range(1, 12) var hand_size : int = 5
@export_range(0, 6) var dice_per_turn : int = 2
## How many hands the player gets before the level is judged.
@export_range(1, 30) var max_plays : int = 4

@export_group("Rules")
@export var evaluator : HandEvaluator
@export var objective : Objective

func get_deck_definition() -> DeckDefinition:
	return deck_definition if deck_definition != null else DeckDefinition.create_standard_52()

func get_bag_definition() -> BagDefinition:
	return bag_definition if bag_definition != null else StarterDice.create_starter_bag()

func get_evaluator() -> HandEvaluator:
	return evaluator if evaluator != null else PokerHandEvaluator.new()

func get_objective() -> Objective:
	return objective if objective != null else ScoreTargetObjective.new()
