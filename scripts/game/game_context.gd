class_name GameContext
extends RefCounted
## The slice of game state a DieAction is allowed to touch.
##
## Actions get this rather than the whole game, so they can change cards and
## score but cannot drive state transitions themselves — that stays with the
## state machine.
##
## The dice bag is deliberately absent. None of the current actions affect it,
## and leaving it out keeps the class graph acyclic: DieFace holds a DieAction,
## which references this class, so pulling DiceBag in here would close a loop
## back through Die and DieType.

var deck : Deck
var hand : Hand
var rng : RngService

var score : int = 0
## Multiplier applied to the next scored hand. Die actions raise it; the
## scoring pass in M5 consumes it.
var score_multiplier : float = 1.0
var plays_left : int = 0

func _init(game_deck : Deck, game_hand : Hand, game_rng : RngService) -> void:
	deck = game_deck
	hand = game_hand
	rng = game_rng

## Fills the hand back up from the deck. Returns how many were actually drawn,
## which is less than requested once the deck is exhausted.
func refill_hand() -> int:
	var drawn := deck.draw(hand.missing_count())
	hand.add(drawn)
	return drawn.size()
