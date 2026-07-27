extends SceneTree
## Measures how hard the shipped levels actually are.
##
##     godot --headless --script res://tools/balance_probe.gd
##
## Plays every level many times with a deliberately unsophisticated strategy and
## reports the clear rate and the score distribution. The bot is a *floor*, not
## a model of a good player: it rerolls while that helps, then swaps whatever is
## not part of a matched rank. A human should beat these numbers comfortably, so
## a target the bot clears 50% of the time is a fair-feeling level rather than a
## coin flip.
##
## This is what the level targets were set from. Rerun it after changing a
## multiplier, a cost, or the number of dice — all three move the whole curve.

const RUNS := 400

func _initialize() -> void:
	var campaign : Campaign = load("res://resources/campaign.tres")
	for level in range(1, campaign.level_count + 1):
		var ruleset := campaign.get_ruleset(level)
		var target : int = ruleset.get_objective().target_score
		var wins := 0
		var totals : Array[int] = []
		for run in RUNS:
			var game := CardDiceGame.new(ruleset, RngService.new(run + 1))
			game.start()
			_play_greedily(game)
			totals.append(game.context.score)
			if game.state == CardDiceGame.State.WON:
				wins += 1
		totals.sort()
		var notes : Array[String] = []
		if not ruleset.boss_name.is_empty():
			notes.append(ruleset.boss_name)
		if ruleset.max_rerolls != 3:
			notes.append("%d reroll%s" % [
				ruleset.max_rerolls, "" if ruleset.max_rerolls == 1 else "s"
			])
		if ruleset.dice_count != 6:
			notes.append("%d dice" % ruleset.dice_count)
		if ruleset.hand_size != 5:
			notes.append("%d cards" % ruleset.hand_size)
		var objective := ruleset.get_objective()
		if objective is RequiredCategoryObjective:
			notes.append("needs %s" % PokerHandClassifier.category_name(
				(objective as RequiredCategoryObjective).minimum_category
			))
		print("level %-2d  target %4d   win %5.1f%%   median %4d%s" % [
			level, target, 100.0 * wins / RUNS, totals[RUNS / 2],
			"" if notes.is_empty() else "   [%s]" % ", ".join(notes),
		])
	quit(0)

## Reroll while it helps, pay off whatever the boss demands, then spend what is
## left swapping the weakest cards that are not part of a matched rank.
## Deliberately unsophisticated — this is a floor, not a ceiling.
func _play_greedily(game : CardDiceGame) -> void:
	for _i in 3:
		if not game.can_reroll():
			break
		var before := game.context.total_energy()
		game.reroll()
		if game.context.total_energy() < before:
			break

	# Mandatory locks come out of the budget before any of it is spent on
	# cards. Swapping first and discovering the locks are unaffordable is how a
	# player loses a level to bookkeeping rather than to the dice.
	_satisfy_save_requirements(game)

	for _round in 4:
		var junk := _unpaired_cards(game)
		if junk.is_empty():
			break
		game.context.hand.clear_selection()
		var marked := 0
		for card in junk:
			if not game.context.can_afford((marked + 1) * game.swap_cost()):
				break
			game.context.hand.toggle_selection(card)
			marked += 1
		if marked == 0 or not game.swap_selected():
			break
	game.context.hand.clear_selection()

	# A reroll during the swaps could in principle have moved the requirement,
	# so check once more before committing.
	_satisfy_save_requirements(game)
	game.save_hand()

## Locks dice until the level will accept the hand. Gives up rather than
## looping if nothing can be locked, which shows up as a loss.
func _satisfy_save_requirements(game : CardDiceGame) -> void:
	while not game.can_save_hand():
		var locked := false
		for die in game.get_dice():
			if not die.is_locked and game.toggle_lock(die):
				locked = true
				break
		if not locked:
			return

## The cards not contributing to any matched rank, lowest value first.
func _unpaired_cards(game : CardDiceGame) -> Array[Card]:
	var counts : Dictionary = {}
	for card in game.context.hand.cards:
		counts[card.data.rank] = int(counts.get(card.data.rank, 0)) + 1
	var junk : Array[Card] = []
	for card in game.context.hand.cards:
		if int(counts[card.data.rank]) == 1:
			junk.append(card)
	junk.sort_custom(func(a : Card, b : Card) -> bool:
		return PokerHandClassifier.card_value(a.data.rank) \
			< PokerHandClassifier.card_value(b.data.rank))
	return junk
