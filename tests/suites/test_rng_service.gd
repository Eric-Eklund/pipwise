extends TestCase
## RngService is the single source of randomness, so determinism starts here.
## Seed 0 is special: it randomizes, and therefore cannot be used in a test.

func test_same_seed_gives_same_shuffle() -> void:
	var a := [1, 2, 3, 4, 5, 6, 7, 8]
	var b := a.duplicate()
	RngService.new(1234).shuffle(a)
	RngService.new(1234).shuffle(b)
	assert_eq(a, b, "same seed must reproduce the order exactly")

func test_different_seeds_diverge() -> void:
	var a := range(32)
	var b := a.duplicate()
	RngService.new(1).shuffle(a)
	RngService.new(2).shuffle(b)
	assert_ne(a, b, "32 elements make an accidental match effectively impossible")

func test_shuffle_preserves_every_element() -> void:
	var values := range(50)
	var shuffled := values.duplicate()
	RngService.new(99).shuffle(shuffled)
	assert_eq(shuffled.size(), values.size(), "size must not change")
	shuffled.sort()
	assert_eq(shuffled, values, "no element may be lost or duplicated")

func test_shuffle_handles_degenerate_sizes() -> void:
	var empty : Array = []
	RngService.new(7).shuffle(empty)
	assert_eq(empty.size(), 0, "empty array must survive a shuffle")
	var single := [42]
	RngService.new(7).shuffle(single)
	assert_eq(single, [42], "single element must survive a shuffle")

func test_randi_range_stays_in_bounds() -> void:
	var rng := RngService.new(5)
	for _i in 200:
		var value := rng.randi_range(3, 6)
		if value < 3 or value > 6:
			fail("randi_range produced %d outside [3, 6]" % value)
			return
	assert_true(true, "200 draws stayed in range")

func test_randf_stays_in_unit_interval() -> void:
	var rng := RngService.new(8)
	for _i in 200:
		var value := rng.randf()
		if value < 0.0 or value >= 1.0:
			fail("randf produced %f outside [0, 1)" % value)
			return
	assert_true(true, "200 draws stayed in range")

func test_pick_returns_null_on_empty() -> void:
	assert_null(RngService.new(3).pick([]), "pick has no element to return")

func test_pick_returns_a_member() -> void:
	var values := ["a", "b", "c"]
	var picked = RngService.new(11).pick(values)
	assert_true(picked in values, "pick must return one of the inputs")
