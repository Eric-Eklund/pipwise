extends GameOverlay
## Choose the six dice you take into a level.
##
## A stepper per element rather than a grid of individual dice, because the
## decision this game actually asks is *how many of each element*, not which
## particular die. Three is the number that matters — it is where every element's
## trio switches on — so the count is the thing to put under the player's thumb,
## and the row says so the moment it reaches three.
##
## Shown at the start of a run and before each boss. Not before every level: ten
## of these per run is friction, and on an ordinary level there is nothing new to
## decide.

signal loadout_chosen(elements : Array[StringName])

const HEADING_COLOR := Color(0.98, 0.83, 0.36)
const MUTED_COLOR := Color(0.62, 0.66, 0.72)
const TRIO_COLOR := Color(0.42, 0.85, 0.68)
const LENT_COLOR := Color(0.58, 0.62, 0.72)

const LOADOUT_SIZE := 6
const STEPPER_SIZE := Vector2(52, 52)

## Element to how many are available, and how many of those are on loan.
var _available : Dictionary = {}
var _lent : Dictionary = {}
## Element to how many the player has picked.
var _chosen : Dictionary = {}

var _count_label : Label
var _rows : Dictionary = {}

## [param collection] is what the player owns; [param reference] is the bag this
## level's target was measured against, which is what gets lent.
func show_loadout(collection : DiceCollection, reference : BagDefinition) -> void:
	_available = collection.available_counts(reference)
	_lent = collection.lent_counts(reference)
	_chosen = {}

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override(&"font_size", 26)
	content.add_child(_count_label)

	add_line(
		"Three of an element unlocks its trio — the rule that changes how a roll"
		+ " plays, not just what it pays.",
		MUTED_COLOR
	)

	for element in _ordered_elements():
		_add_row(element)

	_preselect(reference)
	_refresh()

## Starts from the bag the level was balanced around, so a player who wants to
## think about none of this can press Start immediately and get a fair level.
func _preselect(reference : BagDefinition) -> void:
	var wanted := DiceCollection.count_bag(reference)
	for element in wanted:
		_chosen[element] = int(wanted[element])

## Owned first in Element.ALL order, then anything that exists only on loan, so
## the list does not reorder itself as the collection grows.
func _ordered_elements() -> Array[StringName]:
	var result : Array[StringName] = []
	if int(_available.get(Element.NONE, 0)) > 0:
		result.append(Element.NONE)
	for element in Element.ALL:
		if int(_available.get(element, 0)) > 0:
			result.append(element)
	return result

func _add_row(element : StringName) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)

	var name_label := Label.new()
	name_label.text = Element.get_label(element)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var minus := _stepper("−")
	minus.pressed.connect(_on_step.bind(element, -1))
	row.add_child(minus)

	var count := Label.new()
	count.custom_minimum_size = Vector2(46, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override(&"font_size", 24)
	row.add_child(count)

	var plus := _stepper("+")
	plus.pressed.connect(_on_step.bind(element, 1))
	row.add_child(plus)

	content.add_child(row)

	var note := Label.new()
	note.add_theme_font_size_override(&"font_size", 15)
	content.add_child(note)

	_rows[element] = {
		"name": name_label, "count": count, "note": note, "minus": minus, "plus": plus
	}

func _stepper(text : String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = STEPPER_SIZE
	return button

func _on_step(element : StringName, delta : int) -> void:
	var wanted := int(_chosen.get(element, 0)) + delta
	if wanted < 0 or wanted > int(_available.get(element, 0)):
		return
	if delta > 0 and _total_chosen() >= LOADOUT_SIZE:
		return
	_chosen[element] = wanted
	_refresh()

func _total_chosen() -> int:
	var sum := 0
	for element in _chosen:
		sum += int(_chosen[element])
	return sum

func _refresh() -> void:
	var total := _total_chosen()
	_count_label.text = "%d / %d dice" % [total, LOADOUT_SIZE]
	_count_label.add_theme_color_override(
		&"font_color", TRIO_COLOR if total == LOADOUT_SIZE else HEADING_COLOR
	)

	for element in _rows:
		var picked := int(_chosen.get(element, 0))
		var owned_here := int(_available.get(element, 0))
		var row : Dictionary = _rows[element]
		row["count"].text = str(picked)
		row["minus"].disabled = picked <= 0
		row["plus"].disabled = picked >= owned_here or total >= LOADOUT_SIZE
		var note : String = _note_for(element, picked, owned_here)
		row["note"].text = note
		# Hidden rather than left blank, or every row without a note reserves an
		# empty line and the list reads as though something failed to load.
		row["note"].visible = not note.is_empty()
		row["note"].add_theme_color_override(
			&"font_color",
			TRIO_COLOR if picked >= ElementRules.TRIO_THRESHOLD else LENT_COLOR
		)

	set_close_enabled(
		total == LOADOUT_SIZE,
		"Start" if total == LOADOUT_SIZE else "Pick %d more" % (LOADOUT_SIZE - total)
	)

## The one line under each row: what this many of the element does, and how many
## of them are only on loan.
func _note_for(element : StringName, picked : int, available : int) -> String:
	var parts : Array[String] = []
	if picked >= ElementRules.TRIO_THRESHOLD:
		parts.append(Element.get_trio_description(element))
	elif element != Element.NONE and picked > 0:
		parts.append(Element.get_description(element))

	var lent := int(_lent.get(element, 0))
	if lent > 0:
		parts.append("%d of %d borrowed for this level" % [lent, available])
	if parts.is_empty():
		return ""
	return "   " + "  ·  ".join(parts)

## The chosen dice as a flat list, which is what a bag is built from.
func get_loadout() -> Array[StringName]:
	var elements : Array[StringName] = []
	for element in _ordered_elements():
		for _i in int(_chosen.get(element, 0)):
			elements.append(element)
	return elements

func close() -> void:
	if _total_chosen() == LOADOUT_SIZE:
		loadout_chosen.emit(get_loadout())
	super()
