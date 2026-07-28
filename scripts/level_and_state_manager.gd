extends LevelManager
## The template's LevelManager, taught what a run is.
##
## The template answers a loss by reloading the same level, which for a rogue-lite
## is a non-event: if a loss resumes where it died, nothing was ever risked and
## there is no run, only a sequence of retries. A loss ends the run here and
## sends the player back to level 1, with the dice collection intact — that
## collection is the only progression there is.
##
## ## The way out is built before anything else happens
##
## _on_level_lost() creates and connects the loss window *first*, and only then
## records the run. It used to be the other way round, and a single bad line in
## the bookkeeping — a Label that was really a RichTextLabel — was enough to
## leave the player on a dead board with no window and no way forward. Nothing
## after the window is allowed to be load-bearing for escaping the level.

## Where a lost run starts again. Level 1: the campaign is the run, and the dice
## you keep are what makes the second attempt shorter than the first.
const FIRST_LEVEL := "res://scenes/game_scene/levels/level_1.tscn"

func set_current_level_path(value : String) -> void:
	super.set_current_level_path(value)
	GameState.set_current_level_path(value)

func set_checkpoint_level_path(value : String) -> void:
	super.set_checkpoint_level_path(value)
	GameState.set_checkpoint_level_path(value)

func get_checkpoint_level_path() -> String:
	var state_level_path := GameState.get_checkpoint_level_path()
	if not state_level_path.is_empty():
		return state_level_path
	return super.get_checkpoint_level_path()

## Ends the run and sends the player back to the start of the campaign.
##
## The order is the point. Window, then connections, then bookkeeping — so that
## whatever goes wrong in the bookkeeping, the player still has a button to press.
func _on_level_lost() -> void:
	if level_lost_scene == null:
		_end_run_and_restart()
		return

	var instance = level_lost_scene.instantiate()
	get_tree().current_scene.add_child(instance)
	_try_connecting_signal_to_node(instance, &"restart_pressed", _restart_run)
	_try_connecting_signal_to_node(instance, &"main_menu_pressed", _load_main_menu)

	var finished := GameState.end_run()
	_describe_run(instance, finished)

## Sends the next attempt to level 1, so that Continue from the main menu starts
## a fresh run rather than resuming one that is already over.
func _restart_run() -> void:
	checkpoint_level_path = FIRST_LEVEL
	load_level(FIRST_LEVEL)

func _end_run_and_restart() -> void:
	GameState.end_run()
	_restart_run()

## Turns the window's "You lost..." into what the attempt was actually worth.
##
## The description is a RichTextLabel, not a Label. Assuming otherwise threw on
## every single loss, and because that happened before the window was connected,
## it stranded the player completely. Typed as Node and narrowed here so the same
## mistake cannot be made silently again.
func _describe_run(window : Node, finished : RunState) -> void:
	if finished == null:
		return
	var node := window.find_child("DescriptionLabel", true, false)
	if node == null:
		return
	var text := "Run over — %s\nYour dice are yours. The next run starts at level 1." \
		% finished.summary_text()
	if node is RichTextLabel:
		(node as RichTextLabel).text = text
	elif node is Label:
		(node as Label).text = text
