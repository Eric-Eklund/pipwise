class_name RunState
extends Resource
## One attempt at the campaign: where you are in it and what it has been worth.
##
## Everything here is thrown away when a run ends. What survives is in
## `GameState` — the dice collection, and nothing else. That split is the whole
## of the rogue-lite, and putting both in one resource would be the easiest
## possible way to lose it.
##
## Note what is *not* here, and is not anywhere: a checkpoint. Every run starts
## at level 1. Resuming at the last boss reached was tried first and made a loss
## a non-event — if the attempt restarts where it died, nothing was risked and
## there is no run, only retries. The dice are what make attempt two shorter than
## attempt one.
##
## A `Resource` rather than a `RefCounted` because a run outlives the level scene
## it is played in: the player can quit between levels and come back to the same
## run.

## Which level the run is on, one-based.
@export var level : int = 1
## Points banked across every level cleared this run.
@export var score : int = 0
## Levels cleared this run. What the summary counts.
@export var levels_cleared : int = 0
## Farkles suffered this run. Flavour for the summary, and a fair hint about
## whether the player is pushing too hard.
@export var farkles : int = 0

## The cards in hand and the deck they come off, as ids.
##
## Ids rather than resources, which is the same shape GameState.loadout uses for
## dice. A saved Array[StringName] is a line of text; a saved array of Card
## sub-resources is a pile of them inlined into the save file, and every rename
## afterwards is a migration.
##
## Note what these are *not* called. A test walks this resource's properties and
## fails any name holding "dice" or "collection", because the line between what a
## run owns and what survives it is the whole of the rogue-lite. Cards are the
## run's; they go when it does.
@export var hand : Array[StringName] = []
@export var deck : Array[StringName] = []
## Seeds the reshuffle when the deck runs dry. Stored so that a run reproduces
## from its seed, cards included.
##
## A second reshuffle inside one run would repeat the first one's order. A full
## deck is eighteen cards and a whole campaign draws about twenty-three, so it
## happens at most once and never twice — not worth a counter to fix.
@export var deck_seed : int = 0

## A fresh run, always at level 1. Takes no starting level on purpose: a run that
## could begin anywhere is a run that can be resumed, and resuming is what this
## design gave up.
## Still takes nothing, including a seed. The test on this signature is about
## resuming, but it is asserted on the argument list rather than on the value, so
## the deck has to seed itself in here rather than be handed one.
static func create() -> RunState:
	var run := RunState.new()
	var rng := RngService.new()
	run.deck_seed = rng.get_seed()
	run.store_hand(CardHand.create(rng))
	return run

# --- cards -----------------------------------------------------------------

## The run's cards as something playable. Rebuilt per level rather than held,
## because RunState is saved data and CardHand is runtime state.
func build_hand() -> CardHand:
	return CardHand.restore(hand, deck, RngService.new(deck_seed))

## Writes a hand back after a level has drawn from or played out of it.
func store_hand(card_hand : CardHand) -> void:
	if card_hand == null:
		return
	hand = card_hand.hand.duplicate()
	deck = card_hand.deck.duplicate()

func clear_level(banked : int, farkle_count : int) -> void:
	score += banked
	levels_cleared += 1
	farkles += farkle_count
	level += 1

func record_loss(farkle_count : int) -> void:
	farkles += farkle_count

## One line for the summary: what this attempt amounted to.
func summary_text() -> String:
	var parts : Array[String] = [
		"%d level%s cleared" % [levels_cleared, "" if levels_cleared == 1 else "s"],
		"%d banked" % score,
	]
	if farkles > 0:
		parts.append("%d Farkle%s" % [farkles, "" if farkles == 1 else "s"])
	return "  ·  ".join(parts)

func _to_string() -> String:
	return "run: level %d, %s" % [level, summary_text()]
