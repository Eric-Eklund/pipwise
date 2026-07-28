extends LevelManager
## The template's LevelManager, taught what a run is.
##
## Two things change. The template treats every cleared level as a checkpoint,
## which would make a lost run resume exactly where it died and mean nothing was
## ever at stake; only the bosses count here. And the template answers a loss by
## reloading the same level, which is the same non-event — a loss ends the run
## and sends the player back to their last boss.
##
## Everything else is the template's, including the win flow, which already does
## the right thing.

const CAMPAIGN_PATH := "res://resources/campaign.tres"

func set_current_level_path(value : String) -> void:
	super.set_current_level_path(value)
	GameState.set_current_level_path(value)

## Only bosses persist as checkpoints.
##
## LevelManager sets this on every level won, which for a rogue-lite is the whole
## problem: if a loss resumes from the level you just lost, nothing was ever
## risked and there is no run, only a sequence of retries. Bosses are far enough
## apart to be worth reaching and close enough that failing costs at most five
## levels.
func set_checkpoint_level_path(value : String) -> void:
	super.set_checkpoint_level_path(value)
	if _is_checkpoint(value):
		GameState.set_checkpoint_level_path(value)
		GameState.reach_checkpoint(Campaign.level_number_from_path(value))

func get_checkpoint_level_path() -> String:
	var state_level_path := GameState.get_checkpoint_level_path()
	if not state_level_path.is_empty():
		return state_level_path
	return super.get_checkpoint_level_path()

## Ends the run and falls back to the last boss, rather than reloading the level
## that was just lost.
##
## The level_lost window's "restart" is repointed at the checkpoint for exactly
## that reason: its button says try again, and trying again has to mean the run,
## not the level.
func _on_level_lost() -> void:
	var finished := GameState.end_run()
	if level_lost_scene == null:
		_load_checkpoint_level()
		return
	var instance = level_lost_scene.instantiate()
	get_tree().current_scene.add_child(instance)
	_describe_run(instance, finished)
	_try_connecting_signal_to_node(instance, &"restart_pressed", _load_checkpoint_level)
	_try_connecting_signal_to_node(instance, &"main_menu_pressed", _load_main_menu)

## Turns the loss window's "You lost..." into what the attempt was actually
## worth, and says where the next one starts.
##
## Written into the label rather than through the addon's own `text` property,
## which is applied at _ready() and would need the value set before the node is
## in the tree — a subtlety worth avoiding for one line of text.
func _describe_run(window : Node, finished : RunState) -> void:
	var label : Label = window.find_child("DescriptionLabel", true, false)
	if label == null or finished == null:
		return
	var lines : Array[String] = ["Run over — %s" % finished.summary_text()]
	var checkpoint := GameState.get_or_create_state().checkpoint_level
	if checkpoint > 1:
		lines.append("Your dice are yours. Next run starts at level %d." % checkpoint)
	else:
		lines.append("Your dice are yours. Reach a boss to move your starting point.")
	label.text = "\n".join(lines)

# --- helpers ---------------------------------------------------------------

## Whether [param level_path] is a level a run may restart from. Endless is not:
## it has no level number, and a run that fell back into endless would have
## nowhere to fall back *to*.
func _is_checkpoint(level_path : String) -> bool:
	var number := Campaign.level_number_from_path(level_path)
	if number < 1:
		return false
	var campaign : Campaign = load(CAMPAIGN_PATH) if ResourceLoader.exists(CAMPAIGN_PATH) else null
	if campaign == null:
		return false
	return campaign.is_checkpoint(number)
