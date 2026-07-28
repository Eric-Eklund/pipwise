class_name GameOverlay
extends Control
## A dimmed panel over the board: the walkthrough and the hand guide sit in one.
##
## Deliberately not the template's OverlaidWindow. That is an inherited scene
## whose children are addressed by parent_id_path, which makes a hand-written
## .tscn fragile and ties these two small windows to the addon's internal node
## names. This is a plain Control with a title, a body and a close button.

signal closed

@export var title : String = ""
@export var close_text : String = "Got it"

@onready var _title_label : Label = %TitleLabel
@onready var _close_button : Button = %CloseButton
## Where subclasses put their content.
@onready var content : VBoxContainer = %Content

func _ready() -> void:
	_title_label.text = title
	_title_label.visible = not title.is_empty()
	_close_button.text = close_text
	_close_button.pressed.connect(close)
	_close_button.grab_focus()

func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		accept_event()
		if _close_button.disabled:
			# A window that cannot be closed from its own button must not be
			# closable with Back either, or Android has a way out that the UI
			# says does not exist.
			return
		close()

func close() -> void:
	closed.emit()
	queue_free()

## Blocks the way out until a subclass says the player is done. The loadout
## screen needs it: leaving with four dice equipped would start a level short.
func set_close_enabled(enabled : bool, text : String = "") -> void:
	_close_button.disabled = not enabled
	if not text.is_empty():
		_close_button.text = text

## Convenience for subclasses: a row with a label on the left and a value pushed
## to the right.
func add_row(left : String, right : String, color : Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)

	var name_label := Label.new()
	name_label.text = left
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_color_override(&"font_color", color)

	var value_label := Label.new()
	value_label.text = right
	value_label.add_theme_color_override(&"font_color", color)

	row.add_child(name_label)
	row.add_child(value_label)
	content.add_child(row)

## A plain paragraph of body text.
func add_line(text : String, color : Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override(&"font_color", color)
	content.add_child(label)
