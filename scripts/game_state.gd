class_name GameState
extends Resource

const STATE_NAME : String = "GameState"
const FILE_PATH = "res://scripts/game_state.gd"

@export var level_states : Dictionary = {}
@export var current_level_path : String
@export var checkpoint_level_path : String
@export var total_games_played : int
@export var play_time : int
@export var total_time : int

## The dice the player owns. The one thing a death does not take.
@export var dice_collection : DiceCollection
## What the player equipped for the current run, as a list of elements. Kept
## rather than rebuilt so that quitting mid-run and coming back does not silently
## re-equip you with something else.
@export var loadout : Array[StringName] = []
## Runs finished, won or lost. Read by the run summary.
@export var runs_played : int = 0
## The attempt in progress. Null between runs.
@export var run : RunState
## The level a lost run starts again from. Permanent progress rather than run
## progress: reaching a boss means every future run begins there.
@export var checkpoint_level : int = 1

## The run in progress, starting a new one from the checkpoint if there is none.
static func get_run() -> RunState:
	var game_state := get_or_create_state()
	if game_state.run == null:
		game_state.run = RunState.create(game_state.checkpoint_level)
		GlobalState.save()
	return game_state.run

## Ends the run and returns what it amounted to, so the summary has something to
## show before it is thrown away.
static func end_run() -> RunState:
	var game_state := get_or_create_state()
	var finished := game_state.run
	game_state.run = null
	game_state.runs_played += 1
	# The loadout goes with the run. Keeping it would mean the next attempt
	# silently starts with whatever lost the last one, which is the opposite of
	# choosing a build.
	game_state.loadout = []
	GlobalState.save()
	return finished if finished != null else RunState.create(game_state.checkpoint_level)

## Raises the checkpoint. Only ever moves forward — a run that falls back and
## re-clears a boss must not be able to lower it.
static func reach_checkpoint(level : int) -> void:
	var game_state := get_or_create_state()
	if level <= game_state.checkpoint_level:
		return
	game_state.checkpoint_level = level
	GlobalState.save()

## Never returns null: a save from before the collection existed, or a brand new
## one, gets the starting six.
static func get_dice_collection() -> DiceCollection:
	var game_state := get_or_create_state()
	if game_state.dice_collection == null:
		game_state.dice_collection = DiceCollection.create_starting()
		GlobalState.save()
	return game_state.dice_collection

## Grants what clearing a level pays, and returns what was actually new so the
## level-won screen can say so. Empty when the player already owned it all.
static func grant_dice(bag : BagDefinition) -> Dictionary:
	var granted := get_dice_collection().grant_up_to(bag)
	if not granted.is_empty():
		GlobalState.save()
	return granted

static func set_loadout(elements : Array[StringName]) -> void:
	var game_state := get_or_create_state()
	game_state.loadout = elements
	GlobalState.save()

## The equipped dice as a bag, or null when nothing has been equipped yet — in
## which case the level falls back to its reference bag and is still playable.
static func get_loadout_bag() -> BagDefinition:
	var game_state := get_or_create_state()
	if game_state.loadout.is_empty():
		return null
	return DiceCollection.build_bag(game_state.loadout)

static func get_level_state(level_state_key : String) -> LevelState:
	if not has_game_state(): 
		return
	var game_state := get_or_create_state()
	if level_state_key.is_empty() : return
	if level_state_key in game_state.level_states:
		return game_state.level_states[level_state_key] 
	else:
		var new_level_state := LevelState.new()
		game_state.level_states[level_state_key] = new_level_state
		GlobalState.save()
		return new_level_state

static func has_game_state() -> bool:
	return GlobalState.has_state(STATE_NAME)

static func get_or_create_state() -> GameState:
	return GlobalState.get_or_create_state(STATE_NAME, FILE_PATH)

static func get_current_level_path() -> String:
	if not has_game_state(): 
		return ""
	var game_state := get_or_create_state()
	return game_state.current_level_path

static func get_checkpoint_level_path() -> String:
	if not has_game_state(): 
		return ""
	var game_state := get_or_create_state()
	return game_state.checkpoint_level_path

static func get_levels_reached() -> int:
	if not has_game_state(): 
		return 0
	var game_state := get_or_create_state()
	return game_state.level_states.size()

static func set_checkpoint_level_path(level_path : String) -> void:
	var game_state := get_or_create_state()
	game_state.checkpoint_level_path = level_path
	get_level_state(level_path)
	GlobalState.save()

static func set_current_level_path(level_path : String) -> void:
	var game_state := get_or_create_state()
	game_state.current_level_path = level_path
	GlobalState.save()

static func start_game() -> void:
	var game_state := get_or_create_state()
	game_state.total_games_played += 1
	GlobalState.save()

static func continue_game() -> void:
	var game_state := get_or_create_state()
	game_state.current_level_path = game_state.checkpoint_level_path
	GlobalState.save()

static func reset() -> void:
	var game_state := get_or_create_state()
	game_state.level_states = {}
	game_state.current_level_path = ""
	game_state.checkpoint_level_path = ""
	game_state.play_time = 0
	game_state.total_time = 0
	# The collection goes too. Losing a run is meant to cost the run; the options
	# menu's reset is meant to cost everything, and a player who wipes their save
	# and still owns six Fire dice has not had it wiped.
	game_state.dice_collection = DiceCollection.create_starting()
	game_state.loadout = []
	game_state.runs_played = 0
	game_state.run = null
	game_state.checkpoint_level = 1
	GlobalState.save()
