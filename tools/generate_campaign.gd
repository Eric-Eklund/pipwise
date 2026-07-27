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
	quit(0)

## A level scene inherits the shared one and sets its number. The next-level
## path is left empty so LevelManager falls back to its own SceneLister.
func _write_level(level : int) -> void:
	var text := """[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="%s" id="1_base"]
[ext_resource type="Resource" path="%s" id="2_campaign"]

[node name="Level%d" instance=ExtResource("1_base")]
level_number = %d
campaign = ExtResource("2_campaign")
""" % [BASE_SCENE, CAMPAIGN_PATH, level, level]

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
