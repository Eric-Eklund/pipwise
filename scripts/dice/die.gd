class_name Die
extends RefCounted
## A die in play: a DieType plus the face it currently shows.

var type : DieType
var current_face : DieFace
## Spent dice stay visible until the turn ends, so this is a flag rather than
## a removal.
var is_spent : bool = false

func _init(die_type : DieType) -> void:
	type = die_type

func roll(rng : RngService) -> DieFace:
	current_face = type.roll(rng)
	return current_face

func get_action() -> DieAction:
	return current_face.action if current_face != null else null

func get_label() -> String:
	return current_face.get_label() if current_face != null else ""

func _to_string() -> String:
	return "%s(%s)" % [type.id, get_label()]
