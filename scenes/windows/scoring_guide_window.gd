extends GameOverlay
## What scores, and what the elements on this level do.
##
## Built from the level's own scoring table and the dice actually in the bag,
## rather than from a written list, so it cannot drift from the rules and so it
## only ever mentions elements the player has. A guide that explains Shadow on
## level 3 is a guide nobody finishes reading.

const HEADING_COLOR := Color(0.98, 0.83, 0.36)
const NORMAL_COLOR := Color(0.88, 0.90, 0.94)
const MUTED_COLOR := Color(0.62, 0.66, 0.72)
const TRIO_COLOR := Color(0.42, 0.85, 0.68)

func show_rules(game : FarkleGame) -> void:
	_add_scoring()
	_add_combos()
	_add_mega_combos(game)
	_add_elements(game)
	_add_boss(game)

## The table, read off FarkleScorer rather than typed out again here.
func _add_scoring() -> void:
	add_line("What scores", HEADING_COLOR)
	for value in [1, 5]:
		add_row("A single %d" % value, str(int(FarkleScorer.SINGLE_POINTS[value])), NORMAL_COLOR)
	for value in range(1, 7):
		add_row("Three %ds" % value, str(FarkleScorer.triple_points(value)), NORMAL_COLOR)
	add_row("Each die past the third", "doubles it", NORMAL_COLOR)
	add_row("A straight, 1 to 6", str(FarkleScorer.STRAIGHT_POINTS), NORMAL_COLOR)
	add_row("Three pairs", str(FarkleScorer.THREE_PAIRS_POINTS), NORMAL_COLOR)
	add_line("Anything else scores nothing. A roll with nothing in it is a Farkle, and it takes the whole turn with it.", MUTED_COLOR)

func _add_combos() -> void:
	add_line("Matching elements", HEADING_COLOR)
	add_line("Score several dice of the same element together and the whole selection is multiplied.", MUTED_COLOR)
	var counts := ElementRules.COMBO_MULTIPLIERS.keys()
	counts.sort()
	for count in counts:
		add_row(
			"%d of one element" % count,
			"x%s" % _format(float(ElementRules.COMBO_MULTIPLIERS[count])),
			NORMAL_COLOR
		)

## Section 2.3's combos, and the only place the game explains that taking fewer
## dice can be worth more.
##
## Shown only on a level carrying two or more elements, which is the floor for
## any of them — on a single-element bag none can fire and the page would be
## teaching a rule the player cannot use, which is what the rest of this file
## exists to avoid.
func _add_mega_combos(game : FarkleGame) -> void:
	if _bag_counts(game).size() < MegaCombo.CHAOS_MINIMUM_ELEMENTS:
		return
	add_line("Mega combos", HEADING_COLOR)
	add_line("These read the shape of what you take, not just how much. One extra die can break one — sometimes the best take is not every die that scores.", MUTED_COLOR)
	for id in MegaCombo.ALL:
		add_row(MegaCombo.get_label(id), MegaCombo.get_effect_text(id), MegaCombo.get_color(id))
		add_line("  %s" % MegaCombo.get_description(id), MUTED_COLOR)

## Only the elements this level actually deals out, with the trio line marked
## when three of them are in the bag and the stronger rule is reachable.
func _add_elements(game : FarkleGame) -> void:
	var counts := _bag_counts(game)
	if counts.is_empty():
		return
	add_line("Your elements", HEADING_COLOR)
	for element in Element.ALL:
		if not counts.has(element):
			continue
		add_line(Element.get_label(element), NORMAL_COLOR)
		add_line("  %s" % Element.get_description(element), MUTED_COLOR)
		if int(counts[element]) >= ElementRules.TRIO_THRESHOLD:
			add_line(
				"  Three or more: %s" % Element.get_trio_description(element), TRIO_COLOR
			)

func _add_boss(game : FarkleGame) -> void:
	var ruleset := game.ruleset
	if ruleset.boss_name.is_empty():
		return
	add_line(ruleset.boss_name, HEADING_COLOR)
	add_line(ruleset.boss_description, NORMAL_COLOR)

## How many dice of each element the level handed out. Read off the pool rather
## than the bag definition, so a spell that changed a die mid-level is reflected.
func _bag_counts(game : FarkleGame) -> Dictionary:
	var counts : Dictionary = {}
	for die in game.get_dice():
		if die.element == Element.NONE:
			continue
		counts[die.element] = int(counts.get(die.element, 0)) + 1
	return counts

func _format(value : float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % value
