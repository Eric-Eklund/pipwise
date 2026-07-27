class_name HandEvaluator
extends Resource
## Turns a set of played cards into a score.
##
## Abstract. Scoring is a swappable resource so a level can change what counts
## as a good hand without any code change — that is the whole reason the rules
## live in resources rather than in the game loop.

## Whether these cards form a legal play at all. The default accepts any
## non-empty selection; subclasses can demand a minimum size or a shape.
func is_valid_play(cards : Array[Card]) -> bool:
	return not cards.is_empty()

func evaluate(_cards : Array[Card], _context : GameContext) -> HandScore:
	push_error("HandEvaluator.evaluate() not overridden in %s" % get_script().resource_path)
	return HandScore.new()
