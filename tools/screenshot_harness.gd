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

## Puts a level into a particular state before the shot, so the marked-card and
## locked-die styling can be checked and not just the opening deal.
##
##     --select=0,1  mark those cards for swapping
##     --lock=2      pay to keep that die
##     --guide=1     open the hand guide
func _drive(scene : Node, args : Dictionary) -> void:
	var level := scene as CardDiceLevel
	if level == null or level.game == null:
		return
	for index in _parse_indices(String(args.get("select", ""))):
		if index < level.game.context.hand.size():
			level.game.context.hand.toggle_selection(level.game.context.hand.cards[index])
	for index in _parse_indices(String(args.get("lock", ""))):
		if index < level.game.get_dice().size():
			level.game.toggle_lock(level.game.get_dice()[index])
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
