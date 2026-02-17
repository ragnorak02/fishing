extends RefCounted

# Tests for EconomySystem, UpgradeSystem data, and GameManager multipliers.

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
	_test_economy_system()
	_test_upgrade_system_data()
	_test_game_manager()
	return {"passed": _passed, "failed": _failed, "details": _details}

# --- EconomySystem ---

func _test_economy_system() -> void:
	var script: GDScript = load("res://scripts/systems/EconomySystem.gd")
	_assert_true("EconomySystem.load", script != null, "Failed to load EconomySystem.gd")
	if script == null:
		return

	# SUSHI_BONUS constant
	_assert_eq("EconomySystem.SUSHI_BONUS", script.SUSHI_BONUS, 1.5)

	# calculate_fish_value with a normal fish
	var species := _make_test_species(false, 10, Vector2(1.0, 2.0))
	var value: int = script.calculate_fish_value(species, 2.0)
	_assert_eq("EconomySystem.calc_normal_fish", value, 10)

	# calculate_fish_value with sushi-grade fish (1.5x)
	var sushi_species := _make_test_species(true, 10, Vector2(1.0, 2.0))
	var sushi_value: int = script.calculate_fish_value(sushi_species, 2.0)
	_assert_eq("EconomySystem.calc_sushi_fish", sushi_value, 15)

	# Minimum value floor of 1
	var tiny_species := _make_test_species(false, 1, Vector2(1.0, 100.0))
	var tiny_value: int = script.calculate_fish_value(tiny_species, 0.01)
	_assert_true("EconomySystem.min_value_floor", tiny_value >= 1, "Value %d < 1" % tiny_value)

	# Weight at minimum range
	var half_weight_value: int = script.calculate_fish_value(species, 1.0)
	_assert_eq("EconomySystem.half_weight", half_weight_value, 5)

func _make_test_species(sushi: bool, base_val: int, weight_r: Vector2) -> FishSpecies:
	var s := FishSpecies.new()
	s.id = "test"
	s.display_name = "Test Fish"
	s.base_value = base_val
	s.sushi_grade = sushi
	s.weight_range = weight_r
	s.rarity = FishSpecies.Rarity.COMMON
	return s

# --- UpgradeSystem Data ---

func _test_upgrade_system_data() -> void:
	var script: GDScript = load("res://scripts/systems/UpgradeSystem.gd")
	_assert_true("UpgradeSystem.load", script != null, "Failed to load UpgradeSystem.gd")
	if script == null:
		return

	_assert_eq("UpgradeSystem.MAX_LEVEL", script.MAX_LEVEL, 3)

	# All 6 UpgradeType enum values exist in UPGRADE_DATA
	var data: Dictionary = script.UPGRADE_DATA
	_assert_eq("UpgradeSystem.data_count", data.size(), 6)

	# Validate each entry
	for key in data:
		var entry: Dictionary = data[key]
		var type_name: String = "UpgradeType_%d" % key

		# costs array has exactly 3 elements, all positive
		var costs: Array = entry["costs"]
		_assert_eq("%s.costs_length" % type_name, costs.size(), 3)
		var all_positive := true
		for c in costs:
			if c <= 0:
				all_positive = false
		_assert_true("%s.costs_positive" % type_name, all_positive, "Some costs <= 0")

		# level_names array has exactly 4 elements
		var names: Array = entry["level_names"]
		_assert_eq("%s.level_names_length" % type_name, names.size(), 4)

		# name and description are non-empty
		_assert_true("%s.name_nonempty" % type_name, entry["name"].length() > 0, "Empty name")
		_assert_true("%s.desc_nonempty" % type_name, entry["description"].length() > 0, "Empty description")

# --- GameManager ---

func _test_game_manager() -> void:
	var script: GDScript = load("res://scripts/autoload/GameManager.gd")
	_assert_true("GameManager.load", script != null, "Failed to load GameManager.gd")
	if script == null:
		return

	var gm: Node = script.new()

	# Initial state
	_assert_eq("GameManager.initial_state", gm.current_state, 0)  # MAIN_MENU = 0
	_assert_eq("GameManager.initial_transitioning", gm.is_transitioning, false)

	# All upgrade levels start at 0
	_assert_eq("GameManager.boat_speed_init", gm.boat_speed_level, 0)
	_assert_eq("GameManager.oxygen_tank_init", gm.oxygen_tank_level, 0)
	_assert_eq("GameManager.harpoon_range_init", gm.harpoon_range_level, 0)
	_assert_eq("GameManager.hull_durability_init", gm.hull_durability_level, 0)
	_assert_eq("GameManager.battery_capacity_init", gm.battery_capacity_level, 0)
	_assert_eq("GameManager.sonar_range_init", gm.sonar_range_level, 0)

	# Multiplier at level 0
	_assert_eq("GameManager.boat_speed_mult_0", gm.get_boat_speed_multiplier(), 1.0)
	_assert_eq("GameManager.oxygen_mult_0", gm.get_oxygen_multiplier(), 1.0)

	# Multiplier at level 3
	gm.boat_speed_level = 3
	_assert_eq("GameManager.boat_speed_mult_3", gm.get_boat_speed_multiplier(), 1.75)

	gm.oxygen_tank_level = 3
	_assert_eq("GameManager.oxygen_mult_3", gm.get_oxygen_multiplier(), 1.9)

	# _detect_state
	_assert_eq("GameManager.detect_hub", gm._detect_state("res://scenes/hub_town/HubTown.tscn"), 1)
	_assert_eq("GameManager.detect_ocean", gm._detect_state("res://scenes/ocean_surface/OceanSurface.tscn"), 2)
	_assert_eq("GameManager.detect_dive", gm._detect_state("res://scenes/dive_scene/DiveScene.tscn"), 3)
	_assert_eq("GameManager.detect_haul", gm._detect_state("res://scenes/haul_summary/HaulSummary.tscn"), 4)
	_assert_eq("GameManager.detect_menu", gm._detect_state("res://scenes/main_menu/MainMenu.tscn"), 0)
	_assert_eq("GameManager.detect_unknown", gm._detect_state("res://scenes/unknown.tscn"), 0)

	# set_vehicle_mode
	gm.set_vehicle_mode(1)
	_assert_eq("GameManager.vehicle_mode_set", gm.vehicle_mode, 1)

	gm.free()
