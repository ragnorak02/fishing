extends RefCounted

# Tests for EventFishSystem — eligibility conditions, biome/day/time filtering.

var _passed := 0
var _failed := 0
var _details := []

func _assert_true(name: String, condition: bool, message: String = "") -> void:
	if condition:
		_passed += 1
		_details.append({"name": name, "status": "pass", "message": ""})
	else:
		_failed += 1
		_details.append({"name": name, "status": "fail", "message": message})

func _assert_eq(name: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		_passed += 1
		_details.append({"name": name, "status": "pass", "message": ""})
	else:
		_failed += 1
		_details.append({"name": name, "status": "fail", "message": "Expected %s, got %s" % [str(expected), str(actual)]})

func run_tests() -> Dictionary:
	_test_event_fish_loading()
	_test_event_fish_properties()
	_test_eligibility_logic()
	_test_biome_filtering()
	_test_spawn_chance()
	return {"passed": _passed, "failed": _failed, "details": _details}

func _test_event_fish_loading() -> void:
	var ghost: FishSpecies = load("res://scripts/data/fish/ghost_jellyfish.tres")
	_assert_true("EventFish.ghost_loads", ghost != null, "Ghost jellyfish should load")

	var marlin: FishSpecies = load("res://scripts/data/fish/storm_marlin.tres")
	_assert_true("EventFish.marlin_loads", marlin != null, "Storm marlin should load")

	var coral: FishSpecies = load("res://scripts/data/fish/sunrise_coral_fish.tres")
	_assert_true("EventFish.coral_loads", coral != null, "Sunrise coral fish should load")

func _test_event_fish_properties() -> void:
	var ghost: FishSpecies = load("res://scripts/data/fish/ghost_jellyfish.tres")
	if ghost:
		_assert_eq("EventFish.ghost_id", ghost.id, "ghost_jellyfish")
		_assert_true("EventFish.ghost_event", ghost.is_event_fish, "Should be event fish")
		_assert_eq("EventFish.ghost_min_day", ghost.event_min_day, 1)
		_assert_eq("EventFish.ghost_biome", ghost.event_biome, "")  # Any biome
		_assert_true("EventFish.ghost_night", 4 in ghost.event_times, "Should require NIGHT")

	var marlin: FishSpecies = load("res://scripts/data/fish/storm_marlin.tres")
	if marlin:
		_assert_eq("EventFish.marlin_id", marlin.id, "storm_marlin")
		_assert_eq("EventFish.marlin_biome", marlin.event_biome, "deep")
		_assert_eq("EventFish.marlin_divisor", marlin.event_day_divisor, 5)
		_assert_true("EventFish.marlin_sushi", marlin.sushi_grade, "Should be sushi grade")

	var coral: FishSpecies = load("res://scripts/data/fish/sunrise_coral_fish.tres")
	if coral:
		_assert_eq("EventFish.coral_id", coral.id, "sunrise_coral_fish")
		_assert_eq("EventFish.coral_biome", coral.event_biome, "shallow")
		_assert_eq("EventFish.coral_min_day", coral.event_min_day, 3)
		_assert_true("EventFish.coral_morning", 0 in coral.event_times, "Should require MORNING")

func _test_eligibility_logic() -> void:
	# Test direct eligibility check logic (simulated since we can't set TimeManager)
	# In headless mode, day=1, time=MORNING(0) by default

	# Ghost jellyfish needs NIGHT(4) — should NOT be eligible at MORNING
	var ghost: FishSpecies = load("res://scripts/data/fish/ghost_jellyfish.tres")
	if ghost:
		# Manually check: time 0 not in [4]
		var morning_eligible := ghost.event_times.size() == 0 or 0 in ghost.event_times
		_assert_true("EventFish.ghost_not_morning", not morning_eligible, "Ghost should not be eligible at morning")

	# Sunrise coral fish needs MORNING(0), day>=3 — day check fails (day=1)
	var coral: FishSpecies = load("res://scripts/data/fish/sunrise_coral_fish.tres")
	if coral:
		var day_check := 1 >= coral.event_min_day
		_assert_true("EventFish.coral_day_fail", not day_check, "Coral should not be eligible on day 1")

	# Storm marlin needs day divisible by 5 — day 1 fails
	var marlin: FishSpecies = load("res://scripts/data/fish/storm_marlin.tres")
	if marlin:
		var divisor_check := marlin.event_day_divisor == 0 or 1 % marlin.event_day_divisor == 0
		_assert_true("EventFish.marlin_day_fail", not divisor_check, "Marlin should not be eligible on day 1")

func _test_biome_filtering() -> void:
	# Storm marlin requires "deep" biome
	var marlin: FishSpecies = load("res://scripts/data/fish/storm_marlin.tres")
	if marlin:
		_assert_true("EventFish.marlin_shallow_fail",
			marlin.event_biome != "" and marlin.event_biome != "shallow",
			"Marlin should not be eligible in shallow biome")
		_assert_true("EventFish.marlin_deep_pass",
			marlin.event_biome == "deep",
			"Marlin should be eligible in deep biome")

	# Ghost jellyfish: any biome (event_biome="")
	var ghost: FishSpecies = load("res://scripts/data/fish/ghost_jellyfish.tres")
	if ghost:
		_assert_true("EventFish.ghost_any_biome",
			ghost.event_biome == "",
			"Ghost should be eligible in any biome")

func _test_spawn_chance() -> void:
	# EventFishSystem.SPAWN_CHANCE should be 0.1 (10%)
	_assert_eq("EventFish.spawn_chance", EventFishSystem.SPAWN_CHANCE, 0.10)

	# try_spawn_event_fish should return null or FishSpecies
	# In day 1 morning, no event fish should be eligible
	# Run multiple times — all should return null
	var any_spawned := false
	for i in 50:
		var result := EventFishSystem.try_spawn_event_fish("shallow")
		if result != null:
			any_spawned = true
			break
	_assert_true("EventFish.none_eligible_day1", not any_spawned,
		"No event fish should spawn on day 1 morning in shallow")
