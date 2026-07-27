class_name DieFace
extends Resource
## One side of a die.
##
## The value is the whole point of a face. The pips a die shows are both the
## white energy the player has to spend that level and the bonus the saved hand
## scores with, so a face needs to carry nothing else.

@export var id : StringName = &"blank"
## Short label for the face. Falls back to the value, then to the id.
@export var display_name : String = ""
## Numeric value. 1-6 on the standard white die.
@export var value : int = 0
## Free-form markers rules can match on, so new face kinds need no schema
## change. Iteration 2's coloured dice will use these to say which energy they
## produce.
@export var tags : Array[StringName] = []

static func create(face_id : StringName, face_value : int, label : String = "") -> DieFace:
	var face := DieFace.new()
	face.id = face_id
	face.value = face_value
	face.display_name = label
	return face

func get_label() -> String:
	if not display_name.is_empty():
		return display_name
	if value != 0:
		return str(value)
	return String(id)

func has_tag(tag : StringName) -> bool:
	return tag in tags
