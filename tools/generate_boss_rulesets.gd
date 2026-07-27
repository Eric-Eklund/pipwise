extends SceneTree
## Authors the five boss rulesets.
##
##     godot --headless --script res://tools/generate_boss_rulesets.gd
##
## Written as a script rather than by hand because a Ruleset holds a typed array
## of LevelModifier, and getting that serialisation right in a .tres by hand is
## fiddly and easy to break silently. Rerun it after retuning a boss; it
## overwrites resources/rulesets/level_{5,10,15,20,25}.tres in place.
##
## Note that ResourceSaver omits any property still at its default, so the
## generated files are shorter than what is set here. That is normal.

const C := PokerHandClassifier.Category

func _initialize() -> void:
	# Targets read off tools/balance_probe.gd at roughly the 40% mark for its
	# deliberately weak bot, which should put a human near the design spec's
	# ~60% boss clear rate. Short Deck's is far lower because four cards score
	# less, not because it is an easier level.
	_write(5, 140, "Frost King",
		"One die is frozen: it cannot be locked or rerolled.", _frost())
	_write(10, 130, "The Gambler",
		"Lock at least 2 dice before you can save your hand.", _gambler())
	_write(15, 140, "Mirror Master",
		"Pairs score as nothing. Straights and flushes pay 50% more.", _mirror())
	_write(20, 105, "Short Deck",
		"Four cards only — no room for a straight or a flush.", [], 4)
	_write(25, 140, "Wild Card",
		"Suits and runs count for nothing. Match ranks instead.", _wild())
	quit(0)

func _write(
	level : int,
	target : int,
	boss_name : String,
	boss_description : String,
	modifiers : Array,
	hand_size : int = 5
) -> void:
	var ruleset := Ruleset.new()
	ruleset.id = StringName("level_%d" % level)
	ruleset.boss_name = boss_name
	ruleset.boss_description = boss_description
	ruleset.hand_size = hand_size
	ruleset.dice_count = 6
	ruleset.max_rerolls = 3
	ruleset.card_swap_cost = 3
	ruleset.die_lock_cost = 4
	ruleset.evaluator = PokerHandEvaluator.new()

	var objective := ScoreTargetObjective.new()
	objective.target_score = target
	ruleset.objective = objective

	var typed : Array[LevelModifier] = []
	for modifier in modifiers:
		typed.append(modifier)
	ruleset.modifiers = typed

	var path := "res://resources/rulesets/level_%d.tres" % level
	var error := ResourceSaver.save(ruleset, path)
	print("%s  %s  -> %s" % [path, boss_name, "ok" if error == OK else "ERROR %d" % error])

func _frost() -> Array:
	var frost := FrozenDieModifier.new()
	frost.count = 1
	return [frost]

func _gambler() -> Array:
	var gambler := MinimumLocksModifier.new()
	gambler.minimum = 2
	return [gambler]

## Two modifiers rather than one class: the ban and the bonus are independent
## rules that this boss happens to use together.
func _mirror() -> Array:
	var ban := CategoryBanModifier.new()
	ban.banned = [C.PAIR]
	var bonus := CategoryBonusModifier.new()
	bonus.categories = [C.STRAIGHT, C.FLUSH, C.STRAIGHT_FLUSH]
	bonus.bonus = 0.5
	return [ban, bonus]

func _wild() -> Array:
	var ban := CategoryBanModifier.new()
	ban.banned = [C.STRAIGHT, C.FLUSH, C.STRAIGHT_FLUSH]
	return [ban]
