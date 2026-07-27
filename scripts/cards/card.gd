class_name Card
extends RefCounted
## A card in play: a CardData plus the state that belongs to this copy of it.

var data : CardData
## Whether the player has marked this card to be swapped out.
var is_selected : bool = false
## Whether this card is part of the shape the hand currently scores as. Set by
## the game after every change, and read by the view to frame it.
var is_scoring : bool = false

func _init(card_data : CardData) -> void:
	data = card_data

func get_id() -> StringName:
	return data.get_id()

func _to_string() -> String:
	return data.get_display_name()
