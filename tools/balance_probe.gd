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
	for level in range(1, 6):
		var ruleset : Ruleset = load("res://resources/rulesets/level_%d.tres" % level)
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
		print("level %d  target %4d   win %5.1f%%" % [level, target, 100.0 * wins / RUNS])
		if level == 1:
			# One distribution serves every level: the levels differ only in
			# their target, so the score spread is the same curve each time.
			var line := "  score at each win rate: "
			for rate in [90, 80, 70, 60, 50, 40, 30, 20]:
				line += "%d%%=%d  " % [rate, totals[RUNS * (100 - rate) / 100]]
			print(line)
	quit(0)

## Reroll while it helps, then swap the weakest cards that are not part of a
## pair. Deliberately unsophisticated — this is a floor, not a ceiling.
func _play_greedily(game : CardDiceGame) -> void:
	for _i in 3:
		if not game.can_reroll():
			break
		var before := game.context.total_energy()
		game.reroll()
		if game.context.total_energy() < before:
			break
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
	game.save_hand()

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
