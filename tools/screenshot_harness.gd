extends Node
## Renders a scene and writes a PNG, so UI work can be checked without a device.
##
##     godot --resolution 405x720 res://tools/screenshot_harness.tscn \
##         -- --scene=res://scenes/game_scene/levels/level_1.tscn \
##            --out=user://shot.png --frames=60
##
## Development tool. Nothing in the game references it.
##
## Good for level scenes, which stand on their own. Not good for the menus: they
## are driven by the SceneLoader autoload, which swaps get_tree().current_scene
## — and under this harness that is the harness itself, so the flow replaces the
## thing taking the picture. Check menus by running the game.

const DEFAULT_SCENE := "res://scenes/game_scene/levels/level_1.tscn"
const DEFAULT_OUT := "user://screenshot.png"
const DEFAULT_FRAMES := 60

func _ready() -> void:
	var args := _parse_args()
	var scene_path : String = args.get("scene", DEFAULT_SCENE)
	var out_path : String = args.get("out", DEFAULT_OUT)
	var frames := int(args.get("frames", DEFAULT_FRAMES))

	# Godot falls back to a 64x64 window under a headless X server, so the size
	# is set here rather than left to --resolution.
	var size := _parse_size(String(args.get("size", "405x720")))
	DisplayServer.window_set_size(size)
	get_window().size = size

	var packed : PackedScene = load(scene_path)
	if packed == null:
		push_error("cannot load %s" % scene_path)
		get_tree().quit(1)
		return
	var scene := packed.instantiate()
	# Set before the scene enters the tree, because _ready() is what rolls the
	# opening dice — a seed applied afterwards would come one roll too late.
	if args.has("seed") and scene is FarkleLevel:
		(scene as FarkleLevel).rng_seed = int(args["seed"])
	add_child(scene)
	await get_tree().process_frame
	_drive(scene, args)

	# Tweens and deferred layout need a few frames to settle before the frame
	# is worth looking at.
	for _i in frames:
		await get_tree().process_frame

	print("viewport=%s window=%s screen=%s" % [
		get_viewport().size,
		DisplayServer.window_get_size(),
		DisplayServer.screen_get_size(),
	])
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(out_path)
	if error != OK:
		push_error("could not write %s (error %d)" % [out_path, error])
		get_tree().quit(1)
		return
	print("wrote %s (%dx%d)" % [out_path, image.get_width(), image.get_height()])
	get_tree().quit(0)

## Puts a level into a particular state before the shot, so the marked and set
## aside styling can be checked and not just the opening roll.
##
##     --seed=7      reproduce a particular roll
##     --mark=0,1    mark those dice
##     --take=1      commit whatever is marked, or everything that scores
##     --farkle=800  force a Farkle that costs that many points
##     --guide=1     open the scoring guide
##
## The animations settle over about a second, so --frames decides whether a shot
## catches the banner mid-flight or after it has faded. Around 20 frames is the
## middle of it; the default 60 is after.
func _drive(scene : Node, args : Dictionary) -> void:
	var level := scene as FarkleLevel
	if level == null or level.game == null:
		return
	for index in _parse_indices(String(args.get("mark", ""))):
		var dice := level.game.get_dice()
		if index < dice.size():
			level.game.toggle_selection(dice[index])
	if args.has("take"):
		if level.game.get_selection().is_empty():
			level.game.select_all_scoring()
		level.game.commit_selection()
	if args.has("farkle"):
		# Forced rather than rolled for, so the Farkle feedback can be looked at
		# without hunting for a seed that produces one.
		level.game.context.add_turn_score(int(args["farkle"]))
		level.game._farkle()
	if args.has("guide"):
		var button := level.find_child("GuideButton", true, false) as Button
		if button != null:
			button.pressed.emit()

func _parse_indices(text : String) -> Array[int]:
	var indices : Array[int] = []
	if text.is_empty():
		return indices
	for part in text.split(","):
		if part.is_valid_int():
			indices.append(int(part))
	return indices

func _parse_size(text : String) -> Vector2i:
	var parts := text.split("x")
	if parts.size() != 2:
		return Vector2i(405, 720)
	return Vector2i(int(parts[0]), int(parts[1]))

## Reads --key=value pairs from after the `--` separator.
func _parse_args() -> Dictionary:
	var parsed : Dictionary = {}
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if pair.size() == 2:
			parsed[pair[0]] = pair[1]
	return parsed
