class_name RngService
extends RefCounted
## The single source of randomness in the game.
##
## Every shuffle and every roll goes through one instance of this class, so a
## fixed seed reproduces a whole session exactly. That is what makes the rest
## of the engine testable without a running scene tree.
##
## Godot's Array.shuffle() uses the global RNG and cannot be seeded per
## instance, so shuffling is implemented here instead.

var _rng : RandomNumberGenerator

## Pass a non-zero seed for reproducible runs; 0 picks a random seed.
func _init(seed_value : int = 0) -> void:
	_rng = RandomNumberGenerator.new()
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value

## The seed in use. Worth logging so a run can be replayed.
func get_seed() -> int:
	return _rng.seed

func randi_range(from : int, to : int) -> int:
	return _rng.randi_range(from, to)

## Uniform in [0, 1). Used for weighted picks.
func randf() -> float:
	return _rng.randf()

## Fisher-Yates, in place.
func shuffle(array : Array) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap = array[i]
		array[i] = array[j]
		array[j] = swap

## Returns null for an empty array.
func pick(array : Array) -> Variant:
	if array.is_empty():
		return null
	return array[_rng.randi_range(0, array.size() - 1)]
