class_name RunState
extends Resource
## One attempt at the campaign: where you are in it and what it has been worth.
##
## Everything here is thrown away when a run ends. What survives is in
## `GameState` — the dice collection and the checkpoint. That split is the whole
## of the rogue-lite, and putting both in one resource would be the easiest
## possible way to lose it.
##
## Note what is *not* here: the checkpoint. Where a lost run starts again is
## permanent progress, not run progress — reaching the Ember Warden means every
## future run begins there, which is the thing that keeps a ten-level run from
## costing half an hour to fail.
##
## A `Resource` rather than a `RefCounted` because a run outlives the level scene
## it is played in: the player can quit between levels and come back to the same
## run.

## Which level the run is on, one-based.
@export var level : int = 1
## Points banked across every level cleared this run.
@export var score : int = 0
## Levels cleared this run. What the summary counts.
@export var levels_cleared : int = 0
## Farkles suffered this run. Flavour for the summary, and a fair hint about
## whether the player is pushing too hard.
@export var farkles : int = 0

## A fresh run beginning at [param from_level], which is the player's checkpoint
## rather than always level 1.
static func create(from_level : int = 1) -> RunState:
	var run := RunState.new()
	run.level = maxi(1, from_level)
	return run

func clear_level(banked : int, farkle_count : int) -> void:
	score += banked
	levels_cleared += 1
	farkles += farkle_count
	level += 1

func record_loss(farkle_count : int) -> void:
	farkles += farkle_count

## One line for the summary: what this attempt amounted to.
func summary_text() -> String:
	var parts : Array[String] = [
		"%d level%s cleared" % [levels_cleared, "" if levels_cleared == 1 else "s"],
		"%d banked" % score,
	]
	if farkles > 0:
		parts.append("%d Farkle%s" % [farkles, "" if farkles == 1 else "s"])
	return "  ·  ".join(parts)

func _to_string() -> String:
	return "run: level %d, %s" % [level, summary_text()]
