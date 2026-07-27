class_name ScorePart
extends RefCounted
## One scoring unit inside a selection: "three 4s", "a single 1", "a straight".
##
## The scorer breaks a selection into these rather than returning one number,
## because almost everything downstream needs the pieces. The element bonuses
## are a percentage of a die's *share of its own part*, so a Fire die in a
## triple has to know it is in a triple. The HUD wants to name what scored. And
## a player who cannot see why 550 was 550 stops trusting the game.

enum Kind {
	## One die scoring on its own: a 1 or a 5.
	SINGLE,
	## Three or more of the same value — or two, once Ice makes pairs count.
	SET,
	## 1 through 6, one of each.
	STRAIGHT,
	## Three separate pairs.
	THREE_PAIRS,
}

var kind : Kind = Kind.SINGLE
## The dice that make up this part. Never empty.
var dice : Array[Die] = []
## The face value this part is built on. Meaningless for STRAIGHT and
## THREE_PAIRS, which are built on the whole set, and left at 0 for them.
var value : int = 0
## What the part is worth before any element bonus or combo multiplier.
var base_points : int = 0
## Flat points added by an element trio, e.g. Fire's +200 on a triple of 6.
## Kept apart from base_points so the breakdown can show where it came from.
var bonus_points : int = 0

func _init(
	part_kind : Kind = Kind.SINGLE,
	part_dice : Array[Die] = [],
	part_value : int = 0,
	points : int = 0
) -> void:
	kind = part_kind
	dice = part_dice
	value = part_value
	base_points = points

func size() -> int:
	return dice.size()

## What one die in this part contributes, which is what the element bonuses are
## a percentage of. Integer division would lose points on a straight (1500 over
## six dice divides evenly, but a future part might not), so this stays a float
## and only the final total is rounded.
func share_per_die() -> float:
	if dice.is_empty():
		return 0.0
	return float(base_points) / float(dice.size())

## Whether this part is a matched set of the same value. Ice keys off this, and
## a pair promoted by an Ice trio counts — it is a matched set that happens to
## be two dice long.
func is_matched_set() -> bool:
	return kind == Kind.SET

func get_label() -> String:
	match kind:
		Kind.STRAIGHT:
			return "Straight"
		Kind.THREE_PAIRS:
			return "Three pairs"
		Kind.SET:
			return "%s %ds" % [_count_word(dice.size()), value]
		_:
			return "Single %d" % value

func _count_word(count : int) -> String:
	match count:
		2: return "Two"
		3: return "Three"
		4: return "Four"
		5: return "Five"
		6: return "Six"
		_: return str(count)

func _to_string() -> String:
	return "%s = %d" % [get_label(), base_points + bonus_points]
