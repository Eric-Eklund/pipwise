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

## Energy already committed. Cards are not in the MVP, so nothing spends this
## yet — the accounting is kept because the design document's energy is the sum
## of the dice, which this already is, and deleting it would mean rebuilding it.
var energy_spent : int = 0

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

## Every pip the player's dice are showing. The design document's "energy = sum
## of the dice symbols", waiting for the cards that will spend it.
func total_energy() -> int:
	return pool.total_value()

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

func _on_pool_rolled(_dice : Array[Die]) -> void:
	energy_changed.emit()
