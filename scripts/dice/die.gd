class_name Die
extends RefCounted
## A die on the table: a DieType, the face it currently shows, and the two
## dimensions the game is built on — its value and its element.
##
## Element and level are copied off the type rather than read through it,
## because both are things the game will want to change on one particular die
## without minting a new type: a spell that turns everything wild, an upgrade
## bought in the shop. The type is where they *start*, not where they live.
##
## The only per-roll state is whether the player has set this die aside. Locking
## and freezing went with the card game — in Farkle a die is either still in
## play or already committed to this turn, and there is no third thing.

var type : DieType
var current_face : DieFace
## Which element this die counts as right now. Starts as the type's.
var element : StringName = Element.NONE
## The die's strength, 1-10. Fixed at 1 for now — per-die levelling is not in
## the MVP. The element rules read it anyway, so switching it on later is a
## change to the rules rather than to the data model.
var level : int = 1
## Set aside dice have been committed to this turn's score. They sit out every
## roll until the turn ends or the player earns hot dice.
var is_set_aside : bool = false

func _init(die_type : DieType) -> void:
	type = die_type
	if die_type != null:
		element = die_type.element
		level = die_type.level

func roll(rng : RngService) -> DieFace:
	current_face = type.roll(rng)
	return current_face

## The pips showing. Zero for a die that has not been rolled yet.
func get_value() -> int:
	return current_face.value if current_face != null else 0

func get_label() -> String:
	return current_face.get_label() if current_face != null else ""

func get_element_label() -> String:
	return Element.get_label(element)

## Whether the next roll would leave this die alone. Views and rules both care
## about "will this change", not about why.
func is_held() -> bool:
	return is_set_aside

func _to_string() -> String:
	return "%s%s(%s)" % [Element.get_symbol(element), type.id, get_label()]
