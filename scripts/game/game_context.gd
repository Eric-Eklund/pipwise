class_name GameContext
extends RefCounted
## The state a level is played against: the dice, the two scores, and the energy
## the dice produce.
##
## Split from FarkleGame so that an Objective can be handed the state without
## being handed the game loop — a resource that could reach back into the loop
## could also drive it, and then a level's win condition would be able to roll
## dice. What an objective needs is a scoreboard, and this is the scoreboard.
##
## ## Two scores, not one
##
## banked_score is safe and turn_score is not. Every Farkle decision is a bet of
## the second against the first, so collapsing them into a total would erase the
## only number the player is actually thinking about.

signal energy_changed
signal score_changed

var pool : DicePool
var rng : RngService

## Points the player has locked in. Only banking moves points here, and nothing
## takes them away.
var banked_score : int = 0
## Points riding on the current turn. A Farkle wipes this; banking moves it.
var turn_score : int = 0
## Which turn is being played, counting from 1.
var turn : int = 1
## Turns the level allows. Zero means unlimited, which is what endless mode and
## a pure score race want.
var turn_limit : int = 0
## How many Farkles the player has hit this level. Read by the HUD, and the only
## record that a turn went badly once its points are gone.
var farkle_count : int = 0

## Energy already committed to cards this turn. Reset by advance_turn().
var energy_spent : int = 0
## What this turn's dice were worth when the turn began. Section 4's "energy =
## the sum of the dice symbols", taken once rather than continuously.
##
## It has to be a snapshot. Read live it would move under the player mid-turn:
## spend nine on a potion, push into a worse roll, and the budget that paid for
## it would shrink below what was already spent. A number you cannot plan against
## is not a currency, and the whole point of energy is planning a turn around it.
var energy_budget : int = 0

func _init(game_pool : DicePool, game_rng : RngService) -> void:
	pool = game_pool
	rng = game_rng
	pool.rolled.connect(_on_pool_rolled)

# --- score -----------------------------------------------------------------

## Banked plus what is riding on this turn: what the player would have if they
## banked right now. The number the progress bar shows, because it is the one
## that answers "am I going to clear this".
func projected_score() -> int:
	return banked_score + turn_score

func add_turn_score(points : int) -> void:
	if points == 0:
		return
	turn_score += points
	score_changed.emit()

## Moves the turn's points somewhere nothing can reach them.
func bank_turn_score() -> int:
	var banked := turn_score
	banked_score += turn_score
	turn_score = 0
	score_changed.emit()
	return banked

## Wipes the turn. The penalty is applied to the banked score, so a level can
## charge for a Farkle beyond the points that were already at risk, and the
## banked score never goes below zero — losing a level should come from missing
## the target, not from arriving at it in debt.
func lose_turn_score(penalty : int = 0) -> void:
	turn_score = 0
	farkle_count += 1
	if penalty != 0:
		banked_score = maxi(0, banked_score - penalty)
	score_changed.emit()

# --- turns -----------------------------------------------------------------

func advance_turn() -> void:
	turn += 1
	energy_spent = 0
	score_changed.emit()

func turns_left() -> int:
	if turn_limit <= 0:
		return -1
	return maxi(0, turn_limit - turn + 1)

func has_turns_left() -> bool:
	return turn_limit <= 0 or turn <= turn_limit

# --- energy ----------------------------------------------------------------

## Takes this turn's budget from the dice on the table. Called once a turn, after
## the opening roll — before it there are no faces to count.
func snapshot_energy() -> void:
	energy_budget = pool.total_value()
	energy_changed.emit()

## What this turn has to spend, budget and all. Set aside dice still count: the
## player's dice are their resources whether or not the turn has committed them.
func total_energy() -> int:
	return energy_budget

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

func refund_energy(amount : int) -> void:
	if amount <= 0:
		return
	energy_spent = maxi(0, energy_spent - amount)
	energy_changed.emit()

## A roll no longer moves the budget — it was taken at the top of the turn — but
## it does change what the dice are worth, and the HUD draws both from here.
func _on_pool_rolled(_dice : Array[Die]) -> void:
	energy_changed.emit()
