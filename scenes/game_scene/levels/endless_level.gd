class_name EndlessLevel
extends FarkleLevel
## Endless mode: one round after another, harder every time, until one is missed.
##
## Reuses the campaign level whole — same board, same controls, same HUD. The
## only difference is what a win means. Clearing a round starts the next one in
## place instead of leaving the scene, so the run is unbroken and the total keeps
## climbing.
##
## The run ends the first time a round is missed. That is the point: the score is
## how long the player lasted, not whether they finished.

signal round_started(round_number : int)

@export var endless_run : EndlessRun

## Which round is on the table. One-based, like a level number.
var round_number : int = 1
## Points banked across every round already cleared.
var total_score : int = 0

## The endless run's escalation replaces the campaign's, which is authored for
## ten levels and has nowhere to go after them.
##
## The round counter goes in the boss banner. That row is empty on an endless
## level and is already the most prominent line on the screen, so it says which
## round this is and what the run is worth so far.
func _get_ruleset() -> Ruleset:
	var ruleset := _get_run().get_ruleset(round_number)
	ruleset.boss_name = "Round %d" % round_number
	if total_score > 0:
		ruleset.boss_description = "Banked %d so far" % total_score
	return ruleset

func _get_run() -> EndlessRun:
	return endless_run if endless_run != null else EndlessRun.new()

## Clearing a round banks it and deals the next, harder one.
func _on_level_won() -> void:
	total_score += game.context.banked_score
	_record_run()
	round_number += 1
	start_round(_get_ruleset())
	round_started.emit(round_number)

## Missing a round ends the run. Endless has no win state, so this is the only
## way out, and it still counts as finishing rather than failing.
func _on_level_lost() -> void:
	_record_run()
	lose()

## Persists the best run rather than the best single round — surviving nine
## rounds badly beats one perfect round, and the saved number should say so.
func _record_run() -> void:
	if level_state == null:
		return
	level_state.best_score = maxi(level_state.best_score, total_score)
	# Reaching endless at all is the achievement; there is nothing to complete.
	level_state.completed = true
	GlobalState.save()
