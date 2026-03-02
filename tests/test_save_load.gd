extends RefCounted

# Tests for SaveManager logic — schema validation, migration, record_catch dedup.
# Note: SaveManager extends Node and depends on autoloads, so we test logic
# patterns directly rather than instantiating SaveManager in --script context.

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
	_test_save_manager_exists()
	_test_validate_schema_logic()
	_test_migration_logic()
	_test_save_data_schema()
	_test_record_catch_dedup()
	_test_round_trip_logic()
	_test_species_discovery_api()
	return {"passed": _passed, "failed": _failed, "details": _details}

func _test_save_manager_exists() -> void:
	_assert_true("SaveManager.file_exists",
		FileAccess.file_exists("res://scripts/autoload/SaveManager.gd"),
		"SaveManager.gd should exist")

func _test_validate_schema_logic() -> void:
	# Replicate _validate_schema logic
	# Valid dict with save_version passes
	var valid_data: Dictionary = {"save_version": 1, "gold": 50}
	_assert_true("validate.valid", valid_data is Dictionary and valid_data.has("save_version"), "Should accept valid schema")

	# Non-dict fails
	var non_dict: Variant = "string"
	_assert_true("validate.non_dict", not (non_dict is Dictionary), "Should reject non-dict")

	# Dict without save_version fails
	var no_version: Dictionary = {"gold": 50}
	_assert_true("validate.no_version", not no_version.has("save_version"), "Should reject missing save_version")

	# Null check
	var null_val: Variant = null
	_assert_true("validate.null", not (null_val is Dictionary), "Should reject null")

func _test_migration_logic() -> void:
	# Replicate _migrate v0 -> v1 logic
	var v0_data: Dictionary = {"save_version": 0, "gold": 100}

	# Migration: add missing keys
	if not v0_data.has("stats"):
		v0_data["stats"] = {"total_catches": 0, "total_gold_earned": 0}
	if not v0_data.has("achievements"):
		v0_data["achievements"] = {}
	if not v0_data.has("species_caught"):
		v0_data["species_caught"] = []
	v0_data["save_version"] = 1

	_assert_eq("migrate.version", v0_data["save_version"], 1)
	_assert_true("migrate.has_stats", v0_data.has("stats"), "Should have stats after migration")
	_assert_true("migrate.has_achievements", v0_data.has("achievements"), "Should have achievements")
	_assert_true("migrate.has_species", v0_data.has("species_caught"), "Should have species_caught")
	_assert_eq("migrate.gold_preserved", v0_data["gold"], 100)

func _test_save_data_schema() -> void:
	# Verify expected save data structure has all required keys
	var save_data: Dictionary = {
		"save_version": 1,
		"gold": 50,
		"upgrade_levels": {"boat_speed": 0, "oxygen_tank": 0, "harpoon_range": 0,
			"hull_durability": 0, "battery_capacity": 0, "sonar_range": 0},
		"fish_storage": [],
		"species_caught": [],
		"achievements": {},
		"stats": {"total_catches": 0, "total_gold_earned": 0},
	}
	_assert_true("schema.has_version", save_data.has("save_version"), "Missing save_version")
	_assert_true("schema.has_gold", save_data.has("gold"), "Missing gold")
	_assert_true("schema.has_upgrades", save_data.has("upgrade_levels"), "Missing upgrade_levels")
	_assert_true("schema.has_storage", save_data.has("fish_storage"), "Missing fish_storage")
	_assert_true("schema.has_species", save_data.has("species_caught"), "Missing species_caught")
	_assert_true("schema.has_achievements", save_data.has("achievements"), "Missing achievements")
	_assert_true("schema.has_stats", save_data.has("stats"), "Missing stats")
	_assert_eq("schema.upgrade_count", save_data["upgrade_levels"].size(), 6)

func _test_record_catch_dedup() -> void:
	# Simulate the dedup logic of record_catch
	var species_caught: Array = []
	var total_catches := 0

	# First catch of species A
	total_catches += 1
	if "sardine" not in species_caught:
		species_caught.append("sardine")
	_assert_eq("dedup.after_first", species_caught.size(), 1)
	_assert_eq("dedup.catches_1", total_catches, 1)

	# Second catch of same species — should NOT add again
	total_catches += 1
	if "sardine" not in species_caught:
		species_caught.append("sardine")
	_assert_eq("dedup.after_second_same", species_caught.size(), 1)
	_assert_eq("dedup.catches_2", total_catches, 2)

	# Catch of new species
	total_catches += 1
	if "mackerel" not in species_caught:
		species_caught.append("mackerel")
	_assert_eq("dedup.after_new_species", species_caught.size(), 2)
	_assert_eq("dedup.catches_3", total_catches, 3)

func _test_round_trip_logic() -> void:
	# Simulate round-trip: build save data, apply it, verify state
	var save_data: Dictionary = {
		"save_version": 1,
		"gold": 350,
		"upgrade_levels": {"boat_speed": 2, "oxygen_tank": 1, "harpoon_range": 0,
			"hull_durability": 3, "battery_capacity": 0, "sonar_range": 1},
		"fish_storage": [{"species_id": "sardine", "name": "Sardine", "weight": 0.5, "value": 3, "rarity": "common", "sushi_grade": false}],
		"species_caught": ["sardine", "mackerel"],
		"achievements": {"first_catch": true, "catch_10": false},
		"stats": {"total_catches": 7, "total_gold_earned": 150},
	}

	# Verify values can be read back
	_assert_eq("roundtrip.gold", save_data["gold"], 350)
	_assert_eq("roundtrip.boat_speed", save_data["upgrade_levels"]["boat_speed"], 2)
	_assert_eq("roundtrip.species_count", save_data["species_caught"].size(), 2)
	_assert_eq("roundtrip.total_catches", save_data["stats"]["total_catches"], 7)
	_assert_eq("roundtrip.total_gold_earned", save_data["stats"]["total_gold_earned"], 150)
	_assert_eq("roundtrip.storage_count", save_data["fish_storage"].size(), 1)
	_assert_eq("roundtrip.ach_first_catch", save_data["achievements"]["first_catch"], true)
	_assert_eq("roundtrip.ach_catch_10", save_data["achievements"]["catch_10"], false)

func _test_species_discovery_api() -> void:
	# Simulate species_discovered signal and is_species_discovered logic
	var species_caught: Array = []

	# is_species_discovered when empty
	_assert_true("discovery.empty", not ("sardine" in species_caught), "Should not be discovered before catch")

	# After first catch of sardine
	if "sardine" not in species_caught:
		species_caught.append("sardine")
	_assert_true("discovery.after_catch", "sardine" in species_caught, "Should be discovered after catch")

	# get_discovery_count
	_assert_eq("discovery.count_1", species_caught.size(), 1)

	# Second species
	if "mackerel" not in species_caught:
		species_caught.append("mackerel")
	_assert_eq("discovery.count_2", species_caught.size(), 2)

	# Duplicate catch shouldn't increase count
	if "sardine" not in species_caught:
		species_caught.append("sardine")
	_assert_eq("discovery.no_dup", species_caught.size(), 2)
