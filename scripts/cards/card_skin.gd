class_name CardSkin
extends Resource
## How a card looks.
##
## Holds the palette and metrics the procedural card face draws with, plus an
## optional texture per card id. If a texture exists for a card, the view draws
## that instead of drawing the face itself — so replacing the placeholder art
## with real art is a resource change, not a code change.

@export_group("Body")
@export var face_color : Color = Color(0.97, 0.96, 0.93)
@export var border_color : Color = Color(0.75, 0.73, 0.68)
@export var selected_border_color : Color = Color(1.0, 0.78, 0.28)
@export_range(0.0, 32.0) var corner_radius : float = 8.0
@export_range(0.0, 8.0) var border_width : float = 2.0

@export_group("Ink")
@export var red_ink : Color = Color(0.78, 0.15, 0.20)
@export var black_ink : Color = Color(0.11, 0.12, 0.15)

@export_group("Art")
## Card id (see CardData.get_id(), e.g. &"hearts_12") to Texture2D. Any id
## present here is drawn from the texture; the rest are drawn procedurally.
@export var face_textures : Dictionary = {}

func get_ink(card_data : CardData) -> Color:
	return red_ink if card_data.is_red() else black_ink

## Null when this card has no authored art and should be drawn procedurally.
func get_texture(card_data : CardData) -> Texture2D:
	return face_textures.get(card_data.get_id(), null)

## The rounded, bordered card body. Rebuilt per draw because the border colour
## depends on selection.
func build_body_box(selected : bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = face_color
	box.border_color = selected_border_color if selected else border_color
	var width := int(border_width * (2 if selected else 1))
	box.border_width_left = width
	box.border_width_top = width
	box.border_width_right = width
	box.border_width_bottom = width
	var radius := int(corner_radius)
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box
