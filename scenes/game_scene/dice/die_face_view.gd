class_name DieFaceView
extends Control
## Draws one die face.
##
## Named DieFaceView rather than DieFace because that name belongs to the data
## resource in scripts/dice/die_face.gd.
##
## The depth comes from two bands drawn over the body — a light one along the
## top edge, a dark one along the bottom. That reads as a solid object without
## any pre-rendered art, which is as close to the intended "3D look, 2D tech"
## as this project can get without a renderer.

## Pip positions per value, normalised inside the pip area: x and y both run 0
## (left/top) to 1 (right/bottom), 0.5 being the centre. The standard d6
## arrangement — opposite corners fill in first, the centre pip only appears on
## odd numbers.
const PIP_LAYOUTS : Dictionary = {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.0, 0.0), Vector2(1.0, 1.0)],
	3: [Vector2(0.0, 0.0), Vector2(0.5, 0.5), Vector2(1.0, 1.0)],
	4: [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)],
	5: [
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.5, 0.5),
		Vector2(0.0, 1.0), Vector2(1.0, 1.0),
	],
	6: [
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 0.5),
		Vector2(1.0, 0.5), Vector2(0.0, 1.0), Vector2(1.0, 1.0),
	],
}

## Fraction of the die's width taken up by the pip grid, and by one pip.
const PIP_AREA_RATIO := 0.58
const PIP_RADIUS_RATIO := 0.095

## Green for a die already committed to the turn, amber for one the player has
## marked but not yet taken.
const KEPT_BADGE_COLOR := Color(0.18, 0.62, 0.34)
const MARKED_BADGE_COLOR := Color(0.98, 0.73, 0.24)
const BADGE_RADIUS_RATIO := 0.16
## Thickness of the ring drawn around a marked die, as a fraction of its size.
const MARK_RING_RATIO := 0.055

var face : DieFace
var skin : DieSkin
## Which element to tint the body with. Element.NONE draws the plain die.
var element : StringName = Element.NONE
## Greyed out when this die cannot be part of a scoring selection.
var dimmed : bool = false
## Already committed to the turn.
var set_aside : bool = false
## Marked by the player but not yet committed.
var marked : bool = false

func set_face(new_face : DieFace, new_skin : DieSkin, new_element : StringName = Element.NONE) -> void:
	face = new_face
	skin = new_skin
	element = new_element
	queue_redraw()

func set_dimmed(value : bool) -> void:
	if dimmed == value:
		return
	dimmed = value
	queue_redraw()

func set_badges(is_set_aside : bool, is_marked : bool) -> void:
	if set_aside == is_set_aside and marked == is_marked:
		return
	set_aside = is_set_aside
	marked = is_marked
	queue_redraw()

func _draw() -> void:
	if skin == null:
		return
	var rect := Rect2(Vector2.ZERO, size)

	var texture := skin.get_texture(face)
	if texture != null:
		draw_texture_rect(texture, rect, false)
		_draw_badges(rect)
		return

	draw_style_box(skin.build_body_box(element), rect)
	_draw_depth_bands(rect)

	if face != null:
		if PIP_LAYOUTS.has(face.value):
			_draw_pips(rect, PIP_LAYOUTS[face.value])
		else:
			# Any die that is not a plain 1-6 falls back to its label, so an
			# exotic face from a later iteration still reads as something.
			_draw_label(rect)
	_draw_badges(rect)

## Light along the top, dark along the bottom — cheap but convincing volume.
func _draw_depth_bands(rect : Rect2) -> void:
	var band_height := rect.size.y * skin.depth_band_ratio
	var inset := skin.corner_radius * 0.5
	draw_rect(Rect2(
		rect.position + Vector2(inset, skin.border_width),
		Vector2(rect.size.x - inset * 2.0, band_height)
	), skin.top_highlight)
	draw_rect(Rect2(
		rect.position + Vector2(inset, rect.size.y - band_height - skin.border_width),
		Vector2(rect.size.x - inset * 2.0, band_height)
	), skin.bottom_shadow)

func _draw_pips(rect : Rect2, layout : Array) -> void:
	var ink := skin.disabled_ink if dimmed else skin.ink
	var extent := minf(rect.size.x, rect.size.y) * PIP_AREA_RATIO
	var radius := minf(rect.size.x, rect.size.y) * PIP_RADIUS_RATIO
	var origin := rect.position + rect.size * 0.5 - Vector2(extent, extent) * 0.5
	for spot in layout:
		draw_circle(origin + Vector2(spot) * extent, radius, ink)

func _draw_label(rect : Rect2) -> void:
	var text := face.get_label()
	if text.is_empty():
		return
	var font := _get_font()
	if font == null:
		return
	var ink := skin.disabled_ink if dimmed else skin.ink
	var font_size := maxi(8, int(rect.size.x * 0.34))
	var available := rect.size.x - skin.corner_radius
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	if text_size.x > available:
		font_size = maxi(8, int(font_size * available / text_size.x))
		text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var centre := rect.position + rect.size * 0.5
	var baseline := Vector2(
		centre.x - text_size.x * 0.5,
		centre.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)

## A dot in the top-right corner, plus a ring around a marked die.
##
## Marked and set aside are drawn differently rather than in two colours of the
## same shape, because they mean opposite things: a ring is a choice still open,
## and a die that is only badged is one the player has already spent. Set aside
## wins the badge when both are somehow true, since it is the state that cannot
## be undone.
func _draw_badges(rect : Rect2) -> void:
	if marked and not set_aside:
		var width := minf(rect.size.x, rect.size.y) * MARK_RING_RATIO
		draw_rect(rect.grow(-width * 0.5), MARKED_BADGE_COLOR, false, width)

	if not set_aside and not marked:
		return
	var radius := minf(rect.size.x, rect.size.y) * BADGE_RADIUS_RATIO
	var centre := rect.position + Vector2(rect.size.x - radius * 1.3, radius * 1.3)
	draw_circle(centre, radius, KEPT_BADGE_COLOR if set_aside else MARKED_BADGE_COLOR)

func _get_font() -> Font:
	var font := get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	return font
