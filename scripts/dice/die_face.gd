class_name DieFace
extends Resource
## One side of a die.
##
## Since dice are spent rather than scored, a face is mostly a carrier for its
## action. The numeric value is there for rules that want it and is otherwise
## ignored.

@export var id : StringName = &"blank"
## Short label for the face. Falls back to the action's description.
@export var display_name : String = ""
## Numeric value, for faces that carry one.
@export var value : int = 0
## Free-form markers rules can match on, so new face kinds need no schema change.
@export var tags : Array[StringName] = []
## What spending a die showing this face does. Null means the face does nothing.
@export var action : DieAction

static func create(face_id : StringName, face_action : DieAction, label : String = "") -> DieFace:
	var face := DieFace.new()
	face.id = face_id
	face.action = face_action
	face.display_name = label
	return face

func get_label() -> String:
	if not display_name.is_empty():
		return display_name
	if action != null and not action.description.is_empty():
		return action.description
	return String(id)

func has_tag(tag : StringName) -> bool:
	return tag in tags
