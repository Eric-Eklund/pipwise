extends GameOverlay
## The walkthrough, shown once on the first level.
##
## Four lines, in the order the player will do them. Level 1 is plain dice and
## no elements on purpose, so this explains the Farkle loop and nothing else —
## the elements introduce themselves from level 3, one at a time, and the ?
## button explains whichever ones the player actually has.

const HEADING_COLOR := Color(0.98, 0.83, 0.36)
const BODY_COLOR := Color(0.84, 0.87, 0.92)

func _ready() -> void:
	super()
	_step(
		"1 · Roll six dice",
		"1s are worth 100 and 5s are worth 50. Three of anything is worth much more. Everything else is worth nothing at all."
	)
	_step(
		"2 · Take what scores",
		"Tap the dice you want and press Take. They move aside and their points ride on this turn."
	)
	_step(
		"3 · Roll again, or bank",
		"Rolling again uses only the dice you left. More dice aside means fewer to roll, and fewer dice means a worse chance."
	)
	_step(
		"4 · A Farkle takes everything",
		"If a roll scores nothing, the whole turn is gone. Banking is the only way to keep it. That is the entire game."
	)
	add_line("Clear every die and you get all six back with your points intact.", BODY_COLOR)

func _step(heading : String, body : String) -> void:
	add_line(heading, HEADING_COLOR)
	add_line(body, BODY_COLOR)
