extends SceneTree

# Master test orchestrator — loads modules, collects results, outputs JSON.
# Usage: godot --headless --path <project> --script res://tests/run_tests.gd

const TEST_MODULES := [
	"res://tests/test_core_logic.gd",
	"res://tests/test_fish_data.gd",
	"res://tests/test_inventory.gd",
	"res://tests/test_scenes.gd",
	"res://tests/test_assets.gd",
	"res://tests/test_achievements.gd",
	"res://tests/test_save_load.gd",
	"res://tests/test_ocean_interaction.gd",
	"res://tests/test_vehicle_controls.gd",
	"res://tests/test_fish_scaling.gd",
	"res://tests/test_market.gd",
	"res://tests/test_event_fish.gd",
]

func _init() -> void:
	var start_time := Time.get_ticks_msec()
	var total_passed := 0
	var total_failed := 0
	var all_details := []

	for module_path in TEST_MODULES:
		var script = load(module_path)
		if script == null or not script.can_instantiate():
			total_failed += 1
			all_details.append({
				"name": module_path.get_file(),
				"status": "fail",
				"message": "Failed to load test module",
			})
			continue

		var instance = script.new()
		if instance == null:
			total_failed += 1
			all_details.append({
				"name": module_path.get_file(),
				"status": "fail",
				"message": "Failed to instantiate test module",
			})
			continue

		var result: Dictionary = instance.run_tests()

		total_passed += result.get("passed", 0)
		total_failed += result.get("failed", 0)
		var details: Array = result.get("details", [])
		all_details.append_array(details)

	var duration := Time.get_ticks_msec() - start_time
	var status := "pass" if total_failed == 0 else "fail"
	var timestamp := Time.get_datetime_string_from_system(true) + "Z"

	# Build JSON output manually for maximum compatibility
	var json := JSON.new()
	var output := {
		"status": status,
		"testsTotal": total_passed + total_failed,
		"testsPassed": total_passed,
		"testsFailed": total_failed,
		"durationMs": duration,
		"timestamp": timestamp,
		"details": all_details,
	}
	var json_string := json.stringify(output, "  ")

	# Write to file for bat wrapper
	var file := FileAccess.open("res://tests/test-results.json", FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	# Also print for direct invocation
	print(json_string)

	quit(0 if total_failed == 0 else 1)
