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

var face : DieFace
var skin : DieSkin
## Greyed out when the face's action cannot currently run.
var dimmed : bool = false

func set_face(new_face : DieFace, new_skin : DieSkin) -> void:
	face = new_face
	skin = new_skin
	queue_redraw()

func set_dimmed(value : bool) -> void:
	if dimmed == value:
		return
	dimmed = value
	queue_redraw()

func _draw() -> void:
	if skin == null:
		return
	var rect := Rect2(Vector2.ZERO, size)

	var texture := skin.get_texture(face)
	if texture != null:
		draw_texture_rect(texture, rect, false)
		return

	draw_style_box(skin.build_body_box(), rect)
	_draw_depth_bands(rect)

	if face == null:
		return
	var font := _get_font()
	if font == null:
		return
	_draw_label(rect, font)

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

func _draw_label(rect : Rect2, font : Font) -> void:
	var text := face.get_label()
	if text.is_empty():
		return
	var ink := skin.disabled_ink if dimmed else skin.ink
	# Multiplier faces are short and want to shout; the rest need to fit.
	var base_size := rect.size.x * (0.34 if text.length() <= 3 else 0.18)
	var font_size := maxi(8, int(base_size))
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

func _get_font() -> Font:
	var font := get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	return font
