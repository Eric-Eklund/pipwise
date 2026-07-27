extends TestCase
## DieType does not assume six sides, and treats a malformed weights array as
## "unweighted" rather than erroring.

func _face(id : StringName) -> DieFace:
	var face := DieFace.new()
	face.id = id
	return face

func _die(face_ids : Array) -> DieType:
	var die := DieType.new()
	var faces : Array[DieFace] = []
	for id in face_ids:
		faces.append(_face(id))
	die.faces = faces
	return die

func test_face_count_is_not_fixed_at_six() -> void:
	assert_eq(_die([&"a", &"b", &"c"]).face_count(), 3)
	assert_eq(_die([&"a", &"b", &"c", &"d", &"e", &"f", &"g"]).face_count(), 7)

func test_roll_returns_null_for_a_die_with_no_faces() -> void:
	assert_null(_die([]).roll(RngService.new(1)))

func test_roll_always_returns_one_of_the_faces() -> void:
	var die := _die([&"a", &"b", &"c"])
	var rng := RngService.new(31)
	for _i in 100:
		var rolled := die.roll(rng)
		if rolled not in die.faces:
			fail("roll returned a face that is not on the die")
			return
	assert_true(true, "100 rolls all landed on real faces")

func test_is_weighted_requires_matching_lengths() -> void:
	var die := _die([&"a", &"b"])
	assert_false(die.is_weighted(), "no weights means unweighted")
	die.weights = [1.0]
	assert_false(die.is_weighted(), "a mismatched weights array is ignored")
	die.weights = [1.0, 1.0]
	assert_true(die.is_weighted())

func test_zero_weights_fall_back_to_uniform() -> void:
	var die := _die([&"a", &"b"])
	die.weights = [0.0, 0.0]
	assert_not_null(die.roll(RngService.new(2)), "must still produce a face")

func test_weighting_starves_a_zero_weight_face() -> void:
	var die := _die([&"common", &"never"])
	die.weights = [1.0, 0.0]
	var rng := RngService.new(64)
	for _i in 200:
		if die.roll(rng).id == &"never":
			fail("a zero-weighted face was rolled")
			return
	assert_true(true, "the zero-weighted face never came up in 200 rolls")

func test_same_seed_reproduces_the_roll_sequence() -> void:
	var die := _die([&"a", &"b", &"c", &"d"])
	var first : Array[StringName] = []
	var second : Array[StringName] = []
	var rng_a := RngService.new(1001)
	var rng_b := RngService.new(1001)
	for _i in 20:
		first.append(die.roll(rng_a).id)
		second.append(die.roll(rng_b).id)
	assert_eq(first, second)
