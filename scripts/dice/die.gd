class_name Die
extends RefCounted
## A die on the table: a DieType plus the face it currently shows.
##
## Dice are permanent rather than drawn and spent, so the state worth tracking
## is whether the player has paid to keep this die through the next reroll, and
## whether a boss has taken that choice away from them.

var type : DieType
var current_face : DieFace
## Locked dice survive a reroll. The player pays white energy for this.
var is_locked : bool = false
## Frozen dice can be neither locked nor rerolled. Set by boss modifiers.
var is_frozen : bool = false

func _init(die_type : DieType) -> void:
	type = die_type

func roll(rng : RngService) -> DieFace:
	current_face = type.roll(rng)
	return current_face

## The pips showing. Zero for a die that has not been rolled yet.
func get_value() -> int:
	return current_face.value if current_face != null else 0

func get_label() -> String:
	return current_face.get_label() if current_face != null else ""

## Whether a reroll would leave this die alone, for either reason. Views and
## rules both care about "will this change", not about which flag caused it.
func is_held() -> bool:
	return is_locked or is_frozen

func _to_string() -> String:
	return "%s(%s)" % [type.id, get_label()]
