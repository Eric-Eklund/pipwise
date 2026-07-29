class_name Card
extends Resource
## One thing energy can buy, played from the row under the dice.
##
## Modelled on LevelModifier, and for the same reason: a Resource with virtual
## hooks that all do nothing by default, so a new card is a new subclass and
## never a new branch in the turn loop. Nothing here touches a Node, so a card
## can be played inside a test.
##
## ## Three kinds of effect, three lifetimes
##
## Most of these cards *do* something the moment they are played — a die lands on
## the table, a value moves, the scoring dice are taken. Those override
## on_played() and their duration is INSTANT: nothing is left behind.
##
## The rest change what the board is *worth* or what the player is *allowed to
## do*, and those cannot be a one-off: scoring is recomputed after every tap and
## the buttons are re-asked on every redraw, so the card has to keep answering
## for as long as it is in force. Those override the question hooks below, which
## ElementRules folds into its own answers. The scorer never learns cards exist,
## which is the same seam that keeps element effects out of it.
##
## ## What a card is not
##
## It carries no state about having been played. The hand and the active list
## live in RunState and FarkleGame; a Card is the definition, shared and
## immutable, looked up by id. That is why a hand can be saved as a list of
## StringNames rather than as a pile of serialised resources, and it is why a
## card that wants to remember something has to ask FarkleGame to remember it.

## How long a card stays in force after it is played.
##
## A turn here is many rolls, so "one round" is ambiguous in a way the design
## document never had to be: Score Boost buys the board in front of you and
## Farkle Shield buys the roll you have not made yet. ROLL and TURN are that
## difference, and FarkleGame is what clears each of them.
enum Duration {
	## Nothing is left behind — the whole effect happened on the way in.
	INSTANT,
	## In force until the dice are rolled again.
	ROLL,
	## In force until the turn ends.
	TURN,
}

## Stable identifier. What a saved hand actually stores, so renaming one breaks
## a save and renaming its display name does not.
@export var id : StringName = &""
@export var display_name : String = ""
## One line, shown on the card and in the guide. Says what it does, not what it
## is for.
@export var description : String = ""
## Energy this costs to play, in pips off the turn's budget.
@export_range(0, 100) var energy_cost : int = 0
@export var duration : Duration = Duration.INSTANT
## Drawn before the name. One glyph, because the card is 92px wide.
@export var icon : String = ""
## Border and text colour. Authored per card rather than derived from a rarity:
## these seven are one tier, and the colour is how a thumb finds the right one
## in a row of five.
@export var color : Color = Color(0.72, 0.76, 0.82)

# --- playing ---------------------------------------------------------------

## Whether this card can be played right now, energy aside. Energy is checked by
## FarkleGame, not here, so a card never has to remember what it costs twice.
##
## A card that needs a die is refused when the board holds none it would accept.
## That guard is not politeness: playing one opens a targeting step, and a step
## with no legal target is a board the player can only back out of. Cards that
## want more than "some die will do" narrow it in can_target().
func can_play(game) -> bool:
	return not needs_target() or not game.get_targets_for(self).is_empty()

## Immediate effect, run once when the card is played. The default does nothing,
## which is right for every card whose whole effect is answering the questions
## below for as long as it is in force.
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

# --- targeting -------------------------------------------------------------

## Whether playing this card asks the player for a die.
##
## A targeted card is paid for when the die is picked, not when the card is
## tapped, so backing out costs nothing. See FarkleGame's targeting section.
func needs_target() -> bool:
	return false

## Whether [param die] is one this card would accept. Asked of every die in
## play, both to light the tray up and to decide whether the card can be
## offered at all.
func can_target(_game, _die : Die) -> bool:
	return false

## The line the player is shown while the card waits for a die.
func target_prompt() -> String:
	return ""

## The choices the player picks between before tapping a die, as button labels.
## Empty for a card whose only question is which die — the row draws no buttons
## then, and the choice handed back is always 0.
func target_choices() -> Array[String]:
	var none : Array[String] = []
	return none

## The effect, once the player has picked. [param choice] indexes
## target_choices().
func on_target(_game, _die : Die, _choice : int) -> void:
	pass

# --- the questions ElementRules asks ---------------------------------------

## Extra points this card adds to one scoring part, as a fraction of that part's
## base. Zero leaves the part alone, which is what every card but Score Boost
## says.
func part_bonus_fraction(_part : ScorePart) -> float:
	return 0.0

## Whether a roll that scores nothing may be survived. Farkle Shield's whole
## effect, and the only thing that can stop a bust taking the turn with it.
func blocks_farkle() -> bool:
	return false

## Whether the player is being made to roll: banking is off and the push is on,
## even with nothing set aside. Forced Reroll's whole effect.
func forces_reroll() -> bool:
	return false

# --- how it reads ----------------------------------------------------------

## Name with its icon, e.g. "🎲 Extra Die".
func get_label() -> String:
	if icon.is_empty():
		return display_name
	return "%s %s" % [icon, display_name]

func get_color() -> Color:
	return color

func _to_string() -> String:
	return "%s (%d energy)" % [display_name, energy_cost]
