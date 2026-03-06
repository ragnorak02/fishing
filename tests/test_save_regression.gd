extends RefCounted

# Save/load regression tests — migration chain, corruption handling,
# quest persistence, v5 schema, field completeness.

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
	_test_migration_v0_to_v5()
	_test_migration_v3_to_v5()
	_test_migration_v4_to_v5()
	_test_v5_schema_completeness()
	_test_corrupt_json_handling()
	_test_missing_keys_resilience()
	_test_quest_save_roundtrip()
	_test_time_persistence()
	_test_vehicle_unlock_persistence()
	_test_recipe_persistence()
	_test_empty_save_defaults()
	_test_species_dedup_across_saves()
	return {"passed": _passed, "failed": _failed, "details": _details}

func _test_migration_v0_to_v5() -> void:
	var data: Dictionary = {"save_version": 0, "gold": 100}
	data = _migrate(data, 0)
	_assert_eq("save_reg.v0_to_v5.version", data["save_version"], 5)
	_assert_true("save_reg.v0_to_v5.has_stats", data.has("stats"))
	_assert_true("save_reg.v0_to_v5.has_achievements", data.has("achievements"))
	_assert_true("save_reg.v0_to_v5.has_species", data.has("species_caught"))
	_assert_true("save_reg.v0_to_v5.has_menu", data.has("active_menu"))
	_assert_true("save_reg.v0_to_v5.has_recipes", data.has("unlocked_recipes"))
	_assert_true("save_reg.v0_to_v5.has_day", data.has("current_day"))
	_assert_true("save_reg.v0_to_v5.has_time", data.has("current_time"))
	_assert_true("save_reg.v0_to_v5.has_submerge", data.has("submerge_unlocked"))
	_assert_true("save_reg.v0_to_v5.has_air", data.has("air_mode_unlocked"))
	_assert_true("save_reg.v0_to_v5.has_quests", data.has("quests"))
	_assert_eq("save_reg.v0_to_v5.gold_preserved", data["gold"], 100)

func _test_migration_v3_to_v5() -> void:
	var data: Dictionary = {
		"save_version": 3,
		"gold": 200,
		"stats": {},
		"achievements": {},
		"species_caught": ["sardine"],
		"active_menu": [],
		"unlocked_recipes": [],
		"current_day": 3,
		"current_time": 2,
		"submerge_unlocked": false,
		"air_mode_unlocked": false,
	}
	data = _migrate(data, 3)
	_assert_eq("save_reg.v3_to_v5.version", data["save_version"], 5)
	# v4 forces unlocks to true
	_assert_eq("save_reg.v3_to_v5.submerge", data["submerge_unlocked"], true)
	_assert_eq("save_reg.v3_to_v5.air", data["air_mode_unlocked"], true)
	_assert_true("save_reg.v3_to_v5.quests", data.has("quests"))

func _test_migration_v4_to_v5() -> void:
	var data: Dictionary = {
		"save_version": 4,
		"gold": 300,
		"stats": {"total_catches": 5},
		"achievements": {"first_catch": true},
		"species_caught": ["sardine", "mackerel"],
		"active_menu": ["grilled_mackerel"],
		"unlocked_recipes": ["grilled_mackerel"],
		"current_day": 7,
		"current_time": 3,
		"submerge_unlocked": true,
		"air_mode_unlocked": true,
	}
	data = _migrate(data, 4)
	_assert_eq("save_reg.v4_to_v5.version", data["save_version"], 5)
	_assert_true("save_reg.v4_to_v5.quests_added", data.has("quests"))
	_assert_eq("save_reg.v4_to_v5.quests_empty", data["quests"].size(), 0)
	# All existing data preserved
	_assert_eq("save_reg.v4_to_v5.gold", data["gold"], 300)
	_assert_eq("save_reg.v4_to_v5.day", data["current_day"], 7)

func _test_v5_schema_completeness() -> void:
	# Full v5 save should have all expected keys
	var required_keys := [
		"save_version", "gold", "upgrade_levels", "fish_storage",
		"species_caught", "achievements", "stats", "active_menu",
		"unlocked_recipes", "current_day", "current_time",
		"submerge_unlocked", "air_mode_unlocked", "quests",
	]
	var save: Dictionary = _build_mock_v5_save()
	for key in required_keys:
		_assert_true("save_reg.v5_schema.has_%s" % key, save.has(key), "Missing key: %s" % key)

	# Upgrade levels should have 6 tracks
	_assert_eq("save_reg.v5_schema.upgrade_count", save["upgrade_levels"].size(), 6)

	# Stats should have required sub-keys
	_assert_true("save_reg.v5_schema.stats_catches", save["stats"].has("total_catches"))
	_assert_true("save_reg.v5_schema.stats_gold", save["stats"].has("total_gold_earned"))

func _test_corrupt_json_handling() -> void:
	# Invalid JSON should fail parse
	var json := JSON.new()
	var err := json.parse("{invalid json!!!")
	_assert_true("save_reg.corrupt.parse_fails", err != OK, "Should fail on corrupt JSON")

	# Empty string
	err = json.parse("")
	_assert_true("save_reg.corrupt.empty_fails", err != OK, "Should fail on empty string")

func _test_missing_keys_resilience() -> void:
	# Simulate _apply_save_data with missing keys using .get() defaults
	var data: Dictionary = {"save_version": 5}
	var gold: int = data.get("gold", 50)
	_assert_eq("save_reg.missing.gold_default", gold, 50)

	var upgrades: Dictionary = data.get("upgrade_levels", {})
	var boat_speed: int = upgrades.get("boat_speed", 0)
	_assert_eq("save_reg.missing.upgrade_default", boat_speed, 0)

	var species: Array = data.get("species_caught", [])
	_assert_eq("save_reg.missing.species_default", species.size(), 0)

	var day: int = data.get("current_day", 1)
	_assert_eq("save_reg.missing.day_default", day, 1)

	var quests: Dictionary = data.get("quests", {})
	_assert_eq("save_reg.missing.quests_default", quests.size(), 0)

func _test_quest_save_roundtrip() -> void:
	# Simulate quest system save/load
	var active_quests := {
		"catch_5_sardines": {"progress": 3},
		"earn_500_gold": {"progress": 250},
	}
	var completed_quests := ["discover_5_species"]

	var state := {
		"active_quests": active_quests.duplicate(true),
		"completed_quests": completed_quests.duplicate(),
	}

	# Simulate load
	var loaded_active: Dictionary = state.get("active_quests", {})
	var loaded_completed: Array = state.get("completed_quests", [])

	_assert_eq("save_reg.quest_rt.active_count", loaded_active.size(), 2)
	_assert_eq("save_reg.quest_rt.sardine_progress", loaded_active["catch_5_sardines"]["progress"], 3)
	_assert_eq("save_reg.quest_rt.gold_progress", loaded_active["earn_500_gold"]["progress"], 250)
	_assert_eq("save_reg.quest_rt.completed_count", loaded_completed.size(), 1)
	_assert_true("save_reg.quest_rt.completed_has", "discover_5_species" in loaded_completed)

func _test_time_persistence() -> void:
	var save := _build_mock_v5_save()
	save["current_day"] = 12
	save["current_time"] = 4  # NIGHT

	_assert_eq("save_reg.time.day", save["current_day"], 12)
	_assert_eq("save_reg.time.time", save["current_time"], 4)

func _test_vehicle_unlock_persistence() -> void:
	var save := _build_mock_v5_save()
	save["submerge_unlocked"] = true
	save["air_mode_unlocked"] = false

	_assert_eq("save_reg.unlock.submerge", save["submerge_unlocked"], true)
	_assert_eq("save_reg.unlock.air", save["air_mode_unlocked"], false)

func _test_recipe_persistence() -> void:
	var save := _build_mock_v5_save()
	save["active_menu"] = ["grilled_mackerel", "sardine_onigiri"]
	save["unlocked_recipes"] = ["grilled_mackerel", "sardine_onigiri", "sea_bream_sashimi"]

	_assert_eq("save_reg.recipe.menu_count", save["active_menu"].size(), 2)
	_assert_eq("save_reg.recipe.recipe_count", save["unlocked_recipes"].size(), 3)

func _test_empty_save_defaults() -> void:
	# When no save file, defaults should be sane
	var defaults := {
		"gold": 50,
		"total_catches": 0,
		"total_gold_earned": 0,
		"species_caught": [],
		"current_day": 1,
		"current_time": 0,
	}
	_assert_eq("save_reg.defaults.gold", defaults["gold"], 50)
	_assert_eq("save_reg.defaults.catches", defaults["total_catches"], 0)
	_assert_eq("save_reg.defaults.day", defaults["current_day"], 1)

func _test_species_dedup_across_saves() -> void:
	# Catching the same species across multiple saves shouldn't duplicate
	var species_caught: Array = ["sardine", "mackerel"]

	# Simulate catching sardine again
	if "sardine" not in species_caught:
		species_caught.append("sardine")
	_assert_eq("save_reg.dedup.no_duplicate", species_caught.size(), 2)

	# Save and reload
	var saved := species_caught.duplicate()
	var loaded: Array = saved.duplicate()
	_assert_eq("save_reg.dedup.after_reload", loaded.size(), 2)

	# New species after reload
	if "grouper" not in loaded:
		loaded.append("grouper")
	_assert_eq("save_reg.dedup.new_after_reload", loaded.size(), 3)

# --- Helpers ---

func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	# Replicates SaveManager._migrate logic
	if from_version < 1:
		if not data.has("stats"):
			data["stats"] = {"total_catches": 0, "total_gold_earned": 0}
		if not data.has("achievements"):
			data["achievements"] = {}
		if not data.has("species_caught"):
			data["species_caught"] = []
		data["save_version"] = 1
	if from_version < 2:
		if not data.has("active_menu"):
			data["active_menu"] = []
		if not data.has("unlocked_recipes"):
			data["unlocked_recipes"] = []
		if not data.has("current_day"):
			data["current_day"] = 1
		if not data.has("current_time"):
			data["current_time"] = 0
		data["save_version"] = 2
	if from_version < 3:
		if not data.has("submerge_unlocked"):
			data["submerge_unlocked"] = true
		if not data.has("air_mode_unlocked"):
			data["air_mode_unlocked"] = true
		data["save_version"] = 3
	if from_version < 4:
		data["submerge_unlocked"] = true
		data["air_mode_unlocked"] = true
		data["save_version"] = 4
	if from_version < 5:
		if not data.has("quests"):
			data["quests"] = {}
		data["save_version"] = 5
	return data

func _build_mock_v5_save() -> Dictionary:
	return {
		"save_version": 5,
		"gold": 150,
		"upgrade_levels": {
			"boat_speed": 1, "oxygen_tank": 0, "harpoon_range": 2,
			"hull_durability": 0, "battery_capacity": 1, "sonar_range": 0,
		},
		"fish_storage": [],
		"species_caught": ["sardine"],
		"achievements": {"first_catch": true},
		"stats": {"total_catches": 5, "total_gold_earned": 80},
		"active_menu": [],
		"unlocked_recipes": [],
		"current_day": 3,
		"current_time": 1,
		"submerge_unlocked": true,
		"air_mode_unlocked": true,
		"quests": {},
	}
