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

const LOCK_BADGE_COLOR := Color(0.18, 0.62, 0.34)
const FROST_BADGE_COLOR := Color(0.32, 0.62, 0.86)
const BADGE_RADIUS_RATIO := 0.16

var face : DieFace
var skin : DieSkin
## Greyed out when the player cannot afford to do anything with this die.
var dimmed : bool = false
var locked : bool = false
var frozen : bool = false

func set_face(new_face : DieFace, new_skin : DieSkin) -> void:
	face = new_face
	skin = new_skin
	queue_redraw()

func set_dimmed(value : bool) -> void:
	if dimmed == value:
		return
	dimmed = value
	queue_redraw()

func set_badges(is_locked : bool, is_frozen : bool) -> void:
	if locked == is_locked and frozen == is_frozen:
		return
	locked = is_locked
	frozen = is_frozen
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

	draw_style_box(skin.build_body_box(), rect)
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

## A dot in the top-right corner: green for a die the player paid to keep, blue
## for one a boss froze. Frozen wins, because it is the state the player cannot
## do anything about.
func _draw_badges(rect : Rect2) -> void:
	if not locked and not frozen:
		return
	var radius := minf(rect.size.x, rect.size.y) * BADGE_RADIUS_RATIO
	var centre := rect.position + Vector2(rect.size.x - radius * 1.3, radius * 1.3)
	draw_circle(centre, radius, FROST_BADGE_COLOR if frozen else LOCK_BADGE_COLOR)

func _get_font() -> Font:
	var font := get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	return font
