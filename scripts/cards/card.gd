class_name Card
extends RefCounted
## A card in play: a CardData plus the state that belongs to this copy of it.

var data : CardData
## Whether the player has picked this card for the next play.
var is_selected : bool = false
## Locked cards survive a redraw. Set by die actions.
var is_locked : bool = false

func _init(card_data : CardData) -> void:
	data = card_data

func get_id() -> StringName:
	return data.get_id()

func _to_string() -> String:
	return data.get_display_name()
