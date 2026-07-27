class_name DieSkin
extends Resource
## How a die looks.
##
## Mirrors CardSkin: palette and metrics for the procedural die face, plus an
## optional texture per face id. The depth shading is what sells the die as a
## solid object without any pre-rendered art — a lighter band along the top
## edge and a darker one along the bottom.

@export_group("Body")
@export var body_color : Color = Color(0.93, 0.92, 0.89)
@export var top_highlight : Color = Color(1.0, 1.0, 0.99, 0.65)
@export var bottom_shadow : Color = Color(0.0, 0.0, 0.05, 0.28)
@export var border_color : Color = Color(0.62, 0.60, 0.56)
@export_range(0.0, 32.0) var corner_radius : float = 12.0
@export_range(0.0, 8.0) var border_width : float = 2.0
## Height of the highlight and shadow bands, as a fraction of the die's height.
@export_range(0.05, 0.4) var depth_band_ratio : float = 0.18

@export_group("Ink")
@export var ink : Color = Color(0.13, 0.14, 0.17)
## Pips on a die that scores nothing. Muted, but still well clear of the body —
## the value on a dead die is exactly what tells the player why the roll failed,
## so it has to stay readable.
@export var disabled_ink : Color = Color(0.34, 0.36, 0.40)

@export_group("Elements")
## How far an element's colour pulls the die body away from the plain one, 0 to
## 1. Well under half on purpose: a fully saturated body drowns the pips, and
## the value is what the player reads first. The element is a tint and a rim,
## not a repaint.
@export_range(0.0, 1.0) var element_tint : float = 0.34
## How far the border is pulled towards the element colour. Stronger than the
## body, because a rim reads as "which element" at a glance without costing any
## contrast against the pips.
@export_range(0.0, 1.0) var element_border_tint : float = 0.85

@export_group("Art")
## Face id (see DieFace.id) to Texture2D. Present ids are drawn from the
## texture; the rest are drawn procedurally. Pre-rendered dice land here.
@export var face_textures : Dictionary = {}

## Null when this face has no authored art and should be drawn procedurally.
func get_texture(face : DieFace) -> Texture2D:
	if face == null:
		return null
	return face_textures.get(face.id, null)

## The body box for a die of [param element]. Element.NONE gets the plain one,
## so a basic die is not a special case anywhere in the drawing code.
func build_body_box(element : StringName = Element.NONE) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = body_color
	box.border_color = border_color
	if element != Element.NONE:
		var tint := Element.get_color(element)
		box.bg_color = body_color.lerp(tint, element_tint)
		box.border_color = border_color.lerp(tint, element_border_tint)
	var width := int(border_width)
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
