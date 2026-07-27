class_name GameContext
extends RefCounted
## The state a level is played against: the cards, the dice, and the white
## energy that connects them.
##
## The dice used to be deliberately absent from this class. Die faces carried
## actions, an action took a GameContext, and holding the dice here would have
## closed the loop DieFace -> DieAction -> GameContext -> Die -> DieType ->
## DieFace. Faces are plain numbers now, so the pool belongs here — the score
## reads the dice, and so does every cost the player pays.
##
## Costs are priced here rather than in DicePool so there is exactly one place
## that knows what energy is and how much of it is left.

signal energy_changed

var deck : Deck
var hand : Hand
var pool : DicePool
var rng : RngService

## The current hand's worth. Kept live rather than written once at the end, so
## the objective and the HUD can both read it while the player is still
## deciding.
var score : int = 0
## The shape the current hand scores as, as a PokerHandClassifier.Category, or
## -1 before anything has been evaluated.
var current_category : int = -1
## Multiplier applied on top of the hand's own. Boss modifiers raise it.
var score_multiplier : float = 1.0
## White energy already committed to swaps and locks this level.
var energy_spent : int = 0

## Shapes a boss has ruled out. The evaluator skips these and takes the next
## best thing the hand forms.
var banned_categories : Array[int] = []
## Extra multiplier a boss grants for particular shapes, keyed by category and
## expressed as a fraction: 0.5 means "+50%".
var category_bonuses : Dictionary = {}

func _init(
	game_deck : Deck,
	game_hand : Hand,
	game_pool : DicePool,
	game_rng : RngService
) -> void:
	deck = game_deck
	hand = game_hand
	pool = game_pool
	rng = game_rng
	# A reroll changes the total on the table, which changes what is left to
	# spend even though nothing was spent. The pool has no idea it is currency,
	# so the translation happens here.
	pool.rolled.connect(_on_pool_rolled)

## Every pip showing on the table. Both the energy budget and the score bonus —
## spending energy deliberately does not reduce what the dice add to the hand.
func total_energy() -> int:
	return pool.total_value()

## What is left to spend. A reroll that lands lower shrinks this, and that is
## the risk which makes rerolling a decision rather than a formality.
func available_energy() -> int:
	return maxi(0, total_energy() - energy_spent)

func can_afford(cost : int) -> bool:
	return cost <= available_energy()

func spend_energy(cost : int) -> bool:
	if not can_afford(cost):
		return false
	energy_spent += cost
	energy_changed.emit()
	return true

## Hands energy back, e.g. when a die is unlocked before the lock ever mattered.
func refund_energy(amount : int) -> void:
	if amount <= 0:
		return
	energy_spent = maxi(0, energy_spent - amount)
	energy_changed.emit()

func is_category_banned(category : int) -> bool:
	return category in banned_categories

func multiplier_bonus_for(category : int) -> float:
	return float(category_bonuses.get(category, 0.0))

## Fills the hand back up from the deck. Returns how many were actually drawn,
## which is less than requested once the deck is exhausted.
func refill_hand() -> int:
	var drawn := deck.draw(hand.missing_count())
	hand.add(drawn)
	return drawn.size()

func _on_pool_rolled(_dice : Array[Die]) -> void:
	energy_changed.emit()
