extends SceneTree
## Measures how hard the shipped levels actually are.
##
##     godot --headless --script res://tools/balance_probe.gd
##
## Plays every level many times with a deliberately unsophisticated bot and
## reports the clear rate and the score distribution. The bot is a *floor*, not
## a model of a good player: it always takes every die that scores and banks on
## a fixed threshold, never reading the board and never thinking about elements.
## A human should beat these numbers comfortably, so a level the bot clears
## about half the time is a fair-feeling one rather than a coin flip — the
## design document asks for a 60% human win rate, and the bot sits below that
## on purpose.
##
## This is what the level targets were set from. Rerun it after changing a
## target, a turn count, a bag, or anything in the scoring table — all of them
## move the whole curve.

const RUNS := 400
const TARGET_CLEAR_RATE := 0.50
## A turn is banked once it is worth this share of what one turn needs to
## contribute. Below 1.0 the bot is cautious, which is the point.
const BANK_RATIO := 0.9
## Never push into fewer than this many dice. Two dice Farkle far more often
## than not, so a bot that keeps going is measuring its own recklessness rather
## than the level.
const MINIMUM_DICE_TO_PUSH := 3

func _initialize() -> void:
	var campaign : Campaign = load("res://resources/campaign.tres")
	if campaign == null:
		push_error("no campaign resource — run tools/generate_campaign.gd first")
		quit(1)
		return

	print("Campaign — %d runs per level, bot banks at %d%% of a turn's share\n"
		% [RUNS, int(BANK_RATIO * 100)])
	_print_header("level")
	for level in range(1, campaign.level_count + 1):
		_report(campaign.get_ruleset(level), str(level))

	# Endless is not flagged. It is *meant* to slide from comfortable to
	# impossible — that slide is the mode — so measuring it against a fixed
	# clear rate would mark every row and tell nobody anything. Read the column
	# instead: the round where it crosses 50% is roughly where a run ends.
	print("\nEndless")
	_print_header("round")
	var endless := EndlessRun.new()
	for round_number in [1, 3, 5, 8, 12, 20]:
		_report(endless.get_ruleset(round_number), str(round_number), false)

	quit(0)

func _print_header(first : String) -> void:
	print("%-6s %-16s %7s %6s %6s %8s %8s %8s"
		% [first, "twist", "target", "turns", "clear", "median", "p25", "p75"])

## Plays one ruleset RUNS times and prints a row.
func _report(ruleset : Ruleset, label : String, flag_off_target : bool = true) -> void:
	var wins := 0
	var totals : Array[int] = []
	for run in RUNS:
		var game := FarkleGame.new(ruleset, RngService.new(run + 1))
		game.start()
		_play(game)
		totals.append(game.context.banked_score)
		if game.state == FarkleGame.State.WON:
			wins += 1
	totals.sort()

	var clear_rate := float(wins) / float(RUNS)
	var off_target := absf(clear_rate - TARGET_CLEAR_RATE) > 0.15
	var flag := "  <-- retune" if flag_off_target and off_target else ""

	print("%-6s %-16s %7d %6d %5d%% %8d %8d %8d%s" % [
		label,
		ruleset.boss_name.substr(0, 16),
		ruleset.get_target_score(),
		ruleset.turns,
		int(round(clear_rate * 100.0)),
		_percentile(totals, 0.5),
		_percentile(totals, 0.25),
		_percentile(totals, 0.75),
		flag,
	])

## Drives a game to a win or a loss. Deliberately simple — every decision the
## bot does not make is difficulty it is not hiding from the measurement.
func _play(game : FarkleGame) -> void:
	# The loop cannot run forever on its own: a turn either banks or Farkles,
	# and both end it. The guard is against a rule change that breaks that,
	# because a probe that hangs looks exactly like a probe that is slow.
	var guard := 0
	var limit := 2000
	while guard < limit:
		guard += 1
		match game.state:
			FarkleGame.State.FARKLED:
				game.continue_after_farkle()
				continue
			FarkleGame.State.CHOOSING:
				pass
			_:
				return

		if game.get_scorable_dice().is_empty():
			# _roll already turns a genuine Farkle into State.FARKLED, so this
			# is a boss that has filtered every scoring die away. Nothing the
			# bot does from here changes anything.
			return

		game.select_all_scoring()
		if not game.commit_selection():
			return
		if game.state != FarkleGame.State.CHOOSING:
			continue

		if _should_bank(game):
			# A blocked bank means a minimum the turn has not reached, so the
			# only move left is to push into it.
			if not game.bank() and not game.push():
				return
		elif not game.push() and not game.bank():
			return

	push_error("bot failed to finish a level of %s" % game.ruleset.id)

## Banks once the turn has earned its share of the target, or once pushing would
## mean rolling too few dice to be worth it.
func _should_bank(game : FarkleGame) -> bool:
	if not game.can_bank():
		return false
	if game.context.pool.in_play_count() < MINIMUM_DICE_TO_PUSH:
		return true

	var target := game.ruleset.get_target_score()
	if target <= 0:
		return true
	var share := float(target) / float(maxi(1, game.ruleset.turns))
	return float(game.context.turn_score) >= share * BANK_RATIO

func _percentile(sorted_values : Array[int], fraction : float) -> int:
	if sorted_values.is_empty():
		return 0
	var index := clampi(
		int(floor(fraction * float(sorted_values.size()))), 0, sorted_values.size() - 1
	)
	return sorted_values[index]
