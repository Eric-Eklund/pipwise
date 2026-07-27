class_name CardFace
extends Control
## Draws a playing card.
##
## Pure drawing: no input, no rules. If the skin has a texture for this card it
## covers the whole face; otherwise the card is drawn from the skin's palette,
## which is what happens today.
##
## The selection lift is a draw-time offset rather than a real position change,
## because this node is anchored to its parent button and a container would
## fight any attempt to move it.

## Pip positions per rank, normalised inside the pip area: x is 0 (left column),
## 0.5 (centre) or 1 (right column); y runs 0 (top) to 1 (bottom). These are the
## standard playing-card arrangements.
const PIP_LAYOUTS : Dictionary = {
	2: [Vector2(0.5, 0.0), Vector2(0.5, 1.0)],
	3: [Vector2(0.5, 0.0), Vector2(0.5, 0.5), Vector2(0.5, 1.0)],
	4: [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)],
	5: [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.5, 0.5), Vector2(0.0, 1.0), Vector2(1.0, 1.0)],
	6: [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 0.5), Vector2(1.0, 0.5), Vector2(0.0, 1.0), Vector2(1.0, 1.0)],
	7: [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.5, 0.25), Vector2(0.0, 0.5), Vector2(1.0, 0.5), Vector2(0.0, 1.0), Vector2(1.0, 1.0)],
	8: [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.5, 0.25), Vector2(0.0, 0.5), Vector2(1.0, 0.5), Vector2(0.5, 0.75), Vector2(0.0, 1.0), Vector2(1.0, 1.0)],
	9: [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0 / 3.0), Vector2(1.0, 1.0 / 3.0), Vector2(0.5, 0.5), Vector2(0.0, 2.0 / 3.0), Vector2(1.0, 2.0 / 3.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)],
	10: [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(0.5, 1.0 / 6.0), Vector2(0.0, 1.0 / 3.0), Vector2(1.0, 1.0 / 3.0), Vector2(0.0, 2.0 / 3.0), Vector2(1.0, 2.0 / 3.0), Vector2(0.5, 5.0 / 6.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0)],
}

var card : Card
var skin : CardSkin

## Pixels the drawn face is raised. Tweened by CardView on selection.
var lift : float = 0.0 : set = _set_lift

func set_card(new_card : Card, new_skin : CardSkin) -> void:
	card = new_card
	skin = new_skin
	queue_redraw()

func _set_lift(value : float) -> void:
	lift = value
	queue_redraw()

func _draw() -> void:
	if card == null or skin == null:
		return
	var rect := Rect2(Vector2(0.0, -lift), size)
	var selected : bool = card.is_selected

	var texture := skin.get_texture(card.data)
	if texture != null:
		draw_texture_rect(texture, rect, false)
		if selected:
			draw_rect(rect, skin.selected_border_color, false, skin.border_width * 2.0)
		return

	draw_style_box(skin.build_body_box(selected), rect)

	var font := _get_font()
	if font == null:
		return
	var ink := skin.get_ink(card.data)
	_draw_indices(rect, font, ink)
	_draw_centre(rect, font, ink)

## Rank over suit in the top-left corner, repeated upside down in the
## bottom-right the way a real card reads from either end.
func _draw_indices(rect : Rect2, font : Font, ink : Color) -> void:
	var font_size := maxi(8, int(rect.size.x * 0.20))
	var inset := Vector2(rect.size.x * 0.13, rect.size.y * 0.10)
	var rank_pos := rect.position + inset
	var suit_pos := rank_pos + Vector2(0.0, font_size * 0.95)

	_draw_centred(font, card.data.get_rank_name(), rank_pos, font_size, ink)
	_draw_centred(font, card.data.get_suit_symbol(), suit_pos, int(font_size * 0.85), ink)

	# Flip the whole coordinate system about the card's centre, then draw the
	# same index again — it lands rotated in the opposite corner.
	draw_set_transform(rect.position * 2.0 + rect.size, PI, Vector2.ONE)
	_draw_centred(font, card.data.get_rank_name(), rank_pos, font_size, ink)
	_draw_centred(font, card.data.get_suit_symbol(), suit_pos, int(font_size * 0.85), ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_centre(rect : Rect2, font : Font, ink : Color) -> void:
	var rank : int = card.data.rank
	var centre := rect.position + rect.size * 0.5
	var suit := card.data.get_suit_symbol()

	if rank == 1:
		_draw_centred(font, suit, centre, maxi(12, int(rect.size.x * 0.52)), ink)
		return

	if rank > 10:
		var letter_size := maxi(12, int(rect.size.x * 0.42))
		_draw_centred(font, card.data.get_rank_name(), centre - Vector2(0.0, rect.size.y * 0.05), letter_size, ink)
		_draw_centred(font, suit, centre + Vector2(0.0, rect.size.y * 0.22), maxi(8, int(rect.size.x * 0.20)), ink)
		return

	var layout : Array = PIP_LAYOUTS.get(rank, [])
	if layout.is_empty():
		return
	var pip_area := Rect2(
		rect.position + Vector2(rect.size.x * 0.26, rect.size.y * 0.17),
		Vector2(rect.size.x * 0.48, rect.size.y * 0.66)
	)
	var pip_size := maxi(8, int(rect.size.x * 0.21))
	for offset in layout:
		var point : Vector2 = pip_area.position + Vector2(
			offset.x * pip_area.size.x,
			offset.y * pip_area.size.y
		)
		_draw_centred(font, suit, point, pip_size, ink)

## draw_string() places the baseline, so centring means measuring first.
func _draw_centred(font : Font, text : String, centre : Vector2, font_size : int, color : Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := Vector2(
		centre.x - text_size.x * 0.5,
		centre.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

## get_theme_default_font() returns null when the theme has no default, so fall
## back to the engine's own font rather than skipping the draw.
func _get_font() -> Font:
	var font := get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	return font
