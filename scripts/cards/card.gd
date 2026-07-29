class_name Card
extends Resource
## One card the player can spend energy on. Section 3 of docs/DESIGN.md.
##
## Modelled on LevelModifier, and for the same reason: a Resource with virtual
## hooks that all do nothing by default, so a new card is a new subclass and
## never a new branch in the turn loop. Nothing here touches a Node, so a card
## can be played inside a test.
##
## ## Two kinds of effect, two kinds of hook
##
## Some cards *do* something the moment they are played — a die comes back, two
## more cards are drawn. Those override on_played().
##
## The rest change what the dice are *worth*, and those cannot be a one-off:
## scoring is recomputed after every tap, so the card has to keep answering for
## as long as it is active. Those override the question hooks below, which
## ElementRules folds into its own answers. The scorer never learns cards exist,
## which is the same seam that keeps element effects out of it.
##
## ## What a card is not
##
## It carries no state about having been played. The hand and the active list
## live in RunState and FarkleGame; a Card is the definition, shared and
## immutable, looked up by id. That is why a hand can be saved as a list of
## StringNames rather than as a pile of serialised resources.

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

## Stable identifier. What a saved hand actually stores, so renaming one breaks
## a save and renaming its display name does not.
@export var id : StringName = &""
@export var display_name : String = ""
## One line, shown on the card and in the guide. Says what it does, not what it
## is for.
@export var description : String = ""
@export var rarity : Rarity = Rarity.COMMON
## Energy this costs to play. Section 3's own numbers where the card survived
## into this build — see the deviations section of docs/DESIGN.md for the ones
## that did not.
@export_range(0, 100) var energy_cost : int = 0
## The element this card is about, or NONE for the elementless scrolls. Only the
## potions use it, and only to name and colour themselves.
@export var element : StringName = Element.NONE

# --- playing ---------------------------------------------------------------

## Whether this card can be played right now, energy aside. Overridden by cards
## that need something on the board — Second Wind has nothing to give back when
## every die is already in play.
##
## Energy is checked by FarkleGame, not here, so a card never has to remember
## what it costs twice.
func can_play(_game) -> bool:
	return true

## Immediate effect, run once when the card is played. The default does nothing,
## which is right for every card whose whole effect is answering the questions
## below for the rest of the turn.
##
## Untyped [param game] on purpose: FarkleGame holds a Ruleset which holds an
## Array[LevelModifier], and typing this as FarkleGame would make Card and
## FarkleGame refer to each other at parse time.
func on_played(_game) -> void:
	pass

## Why the board will not take this card, in one line. Empty when can_play() is
## happy with it.
##
## Only ever about can_play(). Whether the turn is live and whether the energy
## is there are FarkleGame's questions and it answers those itself — see
## FarkleGame.get_card_refusal(), which is what the detail window actually asks.
func get_refusal(_game) -> String:
	return ""

## Whether the element this card is about is on the table at all. What the
## potions guard on: a potion multiplies its own element's share of the score
## and nothing else, so on a board without that element it multiplies nothing.
##
## Counted on the dice **in play**, not the whole bag. A die already set aside
## has been scored and cannot be scored again, so its element has nothing left
## to pay — and hot dice, which is the one thing that brings it back, rebuilds
## these rules on its way past.
func _element_is_in_play(game) -> bool:
	return game != null and game.rules != null and game.rules.count_of(element) > 0

# --- the questions ElementRules asks ---------------------------------------

## What this card multiplies [param card_element]'s bonus by while it is active.
## 1.0 is "leaves it alone", which is what every card that is not a potion says.
func element_bonus_multiplier(_card_element : StringName) -> float:
	return 1.0

## Extra dice this card adds to what Nature hands back. Zero for everything but
## Earth Restore.
func dice_restored_bonus() -> int:
	return 0

## Whether a roll that scores nothing is survivable this turn. Shield's whole
## effect, and the only card that can stop the turn ending.
func blocks_farkle() -> bool:
	return false

## Whether a Farkle pays instead of costing, the way three Shadow dice do.
func farkle_pays() -> bool:
	return false

# --- how it reads ----------------------------------------------------------

## Name with its element symbol when it has one, e.g. "🔥 Fire Brew".
func get_label() -> String:
	var symbol := Element.get_symbol(element)
	if symbol.is_empty():
		return display_name
	return "%s %s" % [symbol, display_name]

## The colour the view tints this card. Elementless cards take the rarity's
## colour; a potion takes its element's, because that is the thing the player is
## looking for when they scan the row.
func get_color() -> Color:
	if element != Element.NONE:
		return Element.get_color(element)
	return RARITY_COLORS.get(rarity, RARITY_COLORS[Rarity.COMMON])

const RARITY_COLORS : Dictionary = {
	Rarity.COMMON: Color(0.72, 0.76, 0.82),
	Rarity.UNCOMMON: Color(0.45, 0.82, 0.60),
	Rarity.RARE: Color(0.40, 0.66, 0.95),
	Rarity.EPIC: Color(0.72, 0.50, 0.95),
	Rarity.LEGENDARY: Color(0.98, 0.72, 0.30),
}

func _to_string() -> String:
	return "%s (%d energy)" % [display_name, energy_cost]
