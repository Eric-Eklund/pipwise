extends SceneTree
## Writes the campaign resource and one scene per level.
##
##     godot --headless --script res://tools/generate_campaign.gd
##
## Every level scene is the same four lines with a different number, so they are
## generated rather than hand-made. Rerun after changing level_count; it
## overwrites scenes/game_scene/levels/level_N.tscn and deletes any that fall
## outside the campaign.

const CAMPAIGN_PATH := "res://resources/campaign.tres"
const LEVEL_DIR := "res://scenes/game_scene/levels"
const BASE_SCENE := "res://scenes/game_scene/levels/card_dice_level.tscn"
const ENDLESS_SCENE := "res://scenes/game_scene/levels/endless_level.tscn"
const TUTORIAL_SCENE := "res://scenes/windows/tutorial_window.tscn"
const GAME_UI_PATH := "res://scenes/game_scene/game_ui.tscn"

func _initialize() -> void:
	var campaign := Campaign.new()
	var error := ResourceSaver.save(campaign, CAMPAIGN_PATH)
	if error != OK:
		push_error("could not write %s (error %d)" % [CAMPAIGN_PATH, error])
		quit(1)
		return
	print("wrote %s" % CAMPAIGN_PATH)

	for level in range(1, campaign.level_count + 1):
		_write_level(level)
	_remove_stale(campaign.level_count)
	print("wrote %d level scenes" % campaign.level_count)
	_write_scene_list(campaign.level_count)
	quit(0)

## Rewrites the SceneLister in game_ui.tscn, which is what LevelManager walks to
## decide what comes after what. Done here so changing level_count cannot leave
## the campaign and the level order disagreeing.
func _write_scene_list(level_count : int) -> void:
	var paths : Array[String] = []
	for level in range(1, level_count + 1):
		paths.append("\"%s/level_%d.tscn\"" % [LEVEL_DIR, level])
	# Endless sits after the last level, so clearing the campaign runs straight
	# into it rather than needing a menu of its own.
	paths.append("\"%s\"" % ENDLESS_SCENE)

	var file := FileAccess.open(GAME_UI_PATH, FileAccess.READ)
	if file == null:
		push_error("cannot read %s" % GAME_UI_PATH)
		return
	var text := file.get_as_text()
	file.close()

	var expression := RegEx.create_from_string("(?m)^files = Array\\[String\\]\\(.*\\)$")
	var replacement := "files = Array[String]([%s])" % ", ".join(paths)
	if expression.search(text) == null:
		push_error("no SceneLister files line in %s" % GAME_UI_PATH)
		return
	text = expression.sub(text, replacement.replace("\\", "\\\\"))

	var out := FileAccess.open(GAME_UI_PATH, FileAccess.WRITE)
	if out == null:
		push_error("cannot write %s" % GAME_UI_PATH)
		return
	out.store_string(text)
	print("listed %d levels plus endless in game_ui.tscn" % level_count)

## A level scene inherits the shared one and sets its number. The next-level
## path is left empty so LevelManager falls back to its own SceneLister.
##
## Level 1 also carries the walkthrough. It is the only level that does — the
## rest would be nagging.
func _write_level(level : int) -> void:
	var steps := 4 if level == 1 else 3
	var text := """[gd_scene load_steps=%d format=3]

[ext_resource type="PackedScene" path="%s" id="1_base"]
[ext_resource type="Resource" path="%s" id="2_campaign"]
""" % [steps, BASE_SCENE, CAMPAIGN_PATH]
	if level == 1:
		text += '[ext_resource type="PackedScene" path="%s" id="3_tutorial"]\n' % TUTORIAL_SCENE
	text += """
[node name="Level%d" instance=ExtResource("1_base")]
level_number = %d
campaign = ExtResource("2_campaign")
""" % [level, level]
	if level == 1:
		text += 'tutorial_scene = ExtResource("3_tutorial")\n'

	var path := "%s/level_%d.tscn" % [LEVEL_DIR, level]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("could not write %s" % path)
		return
	file.store_string(text)

## Deletes level scenes past the end of the campaign, so shrinking level_count
## does not leave orphans that the level select would still list.
func _remove_stale(level_count : int) -> void:
	var directory := DirAccess.open(LEVEL_DIR)
	if directory == null:
		return
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if file_name.begins_with("level_") and file_name.ends_with(".tscn"):
			var number := file_name.trim_prefix("level_").trim_suffix(".tscn")
			if number.is_valid_int() and int(number) > level_count:
				print("removing stale %s" % file_name)
				DirAccess.remove_absolute("%s/%s" % [LEVEL_DIR, file_name])
		file_name = directory.get_next()
	directory.list_dir_end()
