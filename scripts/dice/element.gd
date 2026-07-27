class_name Element
extends RefCounted
## The six elements a die can carry, and how each one reads on screen.
##
## An element is a StringName rather than an enum so that a die authored in the
## editor, a save file, and a test fixture can all name one the same way without
## an integer that means nothing when you read it back six months later.
##
## Pure data and lookups. What an element *does* lives in ElementRules, because
## the effects need the dice to talk about and this file must stay loadable by
## anything, including the view layer.

const NONE : StringName = &"none"
const FIRE : StringName = &"fire"
const ICE : StringName = &"ice"
const LIGHTNING : StringName = &"lightning"
const NATURE : StringName = &"nature"
const SHADOW : StringName = &"shadow"
const CRYSTAL : StringName = &"crystal"

## Every real element, in the order the design document lists them. NONE is not
## in here on purpose — it is the absence of an element, not one of them.
const ALL : Array[StringName] = [FIRE, ICE, LIGHTNING, NATURE, SHADOW, CRYSTAL]

const DISPLAY_NAMES : Dictionary = {
	NONE: "Basic",
	FIRE: "Fire",
	ICE: "Ice",
	LIGHTNING: "Lightning",
	NATURE: "Nature",
	SHADOW: "Shadow",
	CRYSTAL: "Crystal",
}

const SYMBOLS : Dictionary = {
	NONE: "",
	FIRE: "🔥",
	ICE: "❄️",
	LIGHTNING: "⚡",
	NATURE: "🌿",
	SHADOW: "☠️",
	CRYSTAL: "💎",
}

## The palette from the design document, section 8.1. The view tints dice with
## these; keeping them here rather than in DieSkin means the engine and the
## renderer cannot drift apart on what "fire" looks like.
const COLORS : Dictionary = {
	NONE: Color(0.93, 0.92, 0.89),
	FIRE: Color("#FF4500"),
	ICE: Color("#00FFFF"),
	LIGHTNING: Color("#FFD700"),
	NATURE: Color("#32CD32"),
	SHADOW: Color("#4B0082"),
	CRYSTAL: Color("#C0C0C0"),
}

## One line naming what the element does at level 1. Shown in the guide and on
## the die tooltip, so it has to match ElementRules exactly.
const DESCRIPTIONS : Dictionary = {
	NONE: "No element.",
	FIRE: "Scored 6s pay +50%.",
	ICE: "Dice in a matched set pay +100%.",
	LIGHTNING: "Scored 4s, 5s and 6s pay double.",
	NATURE: "An even pip total returns a die to the table.",
	SHADOW: "Halves the Farkle penalty.",
	CRYSTAL: "Scored 1s pay triple.",
}

## What three or more of the element does, on top of the above.
const TRIO_DESCRIPTIONS : Dictionary = {
	FIRE: "Triples of 6 pay +200 more.",
	ICE: "Pairs score as triples.",
	LIGHTNING: "4s, 5s and 6s pay triple instead of double.",
	NATURE: "Two dice come back instead of one.",
	SHADOW: "A Farkle pays +50 instead of costing you.",
	CRYSTAL: "1s pay quadruple, and a straight pays +1000.",
}

static func is_element(value : StringName) -> bool:
	return value in ALL

static func get_display_name(element : StringName) -> String:
	return String(DISPLAY_NAMES.get(element, String(element)))

static func get_symbol(element : StringName) -> String:
	return String(SYMBOLS.get(element, ""))

static func get_color(element : StringName) -> Color:
	return COLORS.get(element, COLORS[NONE])

static func get_description(element : StringName) -> String:
	return String(DESCRIPTIONS.get(element, ""))

static func get_trio_description(element : StringName) -> String:
	return String(TRIO_DESCRIPTIONS.get(element, ""))

## Name and symbol together, e.g. "🔥 Fire".
static func get_label(element : StringName) -> String:
	var symbol := get_symbol(element)
	if symbol.is_empty():
		return get_display_name(element)
	return "%s %s" % [symbol, get_display_name(element)]
