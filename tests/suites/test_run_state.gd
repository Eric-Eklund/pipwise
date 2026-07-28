extends TestCase
## What a run carries, and what a loss costs.
##
## The split these tests exist to protect: the run is thrown away, the
## collection and the checkpoint are not. Getting that backwards would either
## make death meaningless or make it unbearable, and both are one field in the
## wrong resource away.

var _campaign : Campaign

func before_each() -> void:
	_campaign = Campaign.new()

# --- a run in progress -----------------------------------------------------

func test_a_new_run_starts_at_level_one() -> void:
	var run := RunState.create()
	assert_eq(run.level, 1)
	assert_eq(run.score, 0)
	assert_eq(run.levels_cleared, 0)

## The whole point of a checkpoint: a later run does not replay what it has
## already beaten.
func test_a_run_can_start_at_a_checkpoint() -> void:
	assert_eq(RunState.create(6).level, 6, "straight to the second half")

func test_clearing_a_level_advances_and_banks() -> void:
	var run := RunState.create()
	run.clear_level(1900, 2)
	assert_eq(run.level, 2, "on to the next")
	assert_eq(run.score, 1900, "banked")
	assert_eq(run.levels_cleared, 1)
	assert_eq(run.farkles, 2, "and what it cost")

func test_a_run_accumulates_across_levels() -> void:
	var run := RunState.create()
	run.clear_level(1900, 1)
	run.clear_level(2100, 3)
	assert_eq(run.score, 4000, "both levels")
	assert_eq(run.levels_cleared, 2)
	assert_eq(run.farkles, 4)

func test_a_loss_still_records_its_farkles() -> void:
	var run := RunState.create()
	run.record_loss(5)
	assert_eq(run.farkles, 5)
	assert_eq(run.levels_cleared, 0, "but nothing was cleared")

# --- the summary -----------------------------------------------------------

func test_the_summary_counts_what_happened() -> void:
	var run := RunState.create()
	run.clear_level(1900, 0)
	var text := run.summary_text()
	assert_true(text.contains("1 level cleared"), "singular: got \"%s\"" % text)
	assert_true(text.contains("1900"), "and the score")

func test_the_summary_stays_quiet_about_a_clean_run() -> void:
	var run := RunState.create()
	run.clear_level(1900, 0)
	assert_false(run.summary_text().contains("Farkle"), "nothing to mention")

func test_the_summary_pluralises() -> void:
	var run := RunState.create()
	run.clear_level(1000, 2)
	run.clear_level(1000, 0)
	assert_true(run.summary_text().contains("2 levels cleared"), "plural")
	assert_true(run.summary_text().contains("2 Farkles"), "plural again")

# --- checkpoints -----------------------------------------------------------

## Where a lost run resumes. Level 1 always, then the bosses — close enough
## together that failing costs at most five levels, far enough apart to be worth
## reaching.
func test_the_checkpoints_are_level_one_and_the_bosses() -> void:
	assert_true(_campaign.is_checkpoint(1), "the start")
	for level in range(2, _campaign.level_count + 1):
		assert_eq(
			_campaign.is_checkpoint(level),
			Campaign.BOSSES.has(level),
			"level %d" % level
		)

## A ten-level run at two or three minutes a level is half an hour. If the gap
## between checkpoints ever grew past five, losing would cost more than anyone
## will sit through twice.
func test_no_checkpoint_is_more_than_five_levels_from_the_last() -> void:
	var previous := 1
	for level in range(2, _campaign.level_count + 1):
		if not _campaign.is_checkpoint(level):
			continue
		assert_true(level - previous <= 5, "level %d is reachable from %d" % [level, previous])
		previous = level
	assert_true(
		_campaign.level_count - previous <= 5,
		"and the run ends within five of the last checkpoint"
	)

## The level manager decides checkpoints from a scene path, so the parser it
## uses is part of the rule and worth pinning — the level select menu sorts by
## the same function.
func test_a_level_number_is_read_off_its_path() -> void:
	assert_eq(Campaign.level_number_from_path("res://a/level_7.tscn"), 7)
	assert_eq(Campaign.level_number_from_path("res://a/level_10.tscn"), 10, "not 1")

## Endless has no number, so it can never be a checkpoint — a run that fell back
## into endless would have nowhere to fall back to.
func test_a_path_without_a_number_is_not_a_level() -> void:
	assert_eq(Campaign.level_number_from_path("res://a/endless_level.tscn"), -1)

# --- what survives ---------------------------------------------------------

## The line the rogue-lite is drawn on. A run holds no dice, so ending one
## cannot take any.
func test_a_run_holds_no_dice() -> void:
	var run := RunState.create()
	for property in run.get_property_list():
		var name := String(property.get("name", ""))
		assert_false(
			name.contains("dice") or name.contains("collection"),
			"a run must not own dice, found \"%s\"" % name
		)

## Two runs are independent. Sharing state between them would mean a fresh
## attempt inherited the last one's score.
func test_runs_do_not_share_state() -> void:
	var first := RunState.create()
	var second := RunState.create()
	first.clear_level(5000, 3)
	assert_eq(second.score, 0, "the second run is untouched")
	assert_eq(second.level, 1)
