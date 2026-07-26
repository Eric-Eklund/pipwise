class_name HandScore
extends RefCounted
## What a played hand was worth.
##
## Base points and multiplier are kept apart rather than pre-multiplied so the
## UI can show the player where the number came from.

var base_points : int = 0
var multiplier : float = 1.0
## Human-readable name of what was played, e.g. "Two Pair".
var label : String = ""

func _init(points : int = 0, mult : float = 1.0, score_label : String = "") -> void:
	base_points = points
	multiplier = mult
	label = score_label

func total() -> int:
	return int(round(base_points * multiplier))

func is_scoring() -> bool:
	return base_points > 0

func _to_string() -> String:
	return "%s: %d x %.1f = %d" % [label, base_points, multiplier, total()]
