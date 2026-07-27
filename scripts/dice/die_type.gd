class_name DieType
extends Resource
## A kind of die: its faces, its element, and optionally how likely each face is.
##
## Face count is not fixed at six — nothing in the engine assumes a d6, which is
## the seam the design document's D8/D10/D12 evolution will come through.

@export var id : StringName = &"basic"
@export var faces : Array[DieFace] = []
## Per-face weights. Leave empty, or the wrong length, for a uniform die.
@export var weights : Array[float] = []
## The element every die of this type is minted with. See Element.
@export var element : StringName = Element.NONE
## The level every die of this type is minted at. The shop will hand out types
## at higher levels rather than mutating the dice it sold.
@export_range(1, 15) var level : int = 1

func face_count() -> int:
	return faces.size()

func is_weighted() -> bool:
	return weights.size() == faces.size() and not faces.is_empty()

## Picks a face. Returns null only for a die with no faces.
func roll(rng : RngService) -> DieFace:
	if faces.is_empty():
		return null
	if not is_weighted():
		return faces[rng.randi_range(0, faces.size() - 1)]

	var total := 0.0
	for weight in weights:
		total += weight
	if total <= 0.0:
		return faces[rng.randi_range(0, faces.size() - 1)]

	var target := rng.randf() * total
	var cursor := 0.0
	for i in faces.size():
		cursor += weights[i]
		if target < cursor:
			return faces[i]
	return faces[faces.size() - 1]
