extends SceneTree

# Master test orchestrator — loads modules, collects results, outputs JSON.
# Usage: godot --headless --path <project> --script res://tests/run_tests.gd

const TEST_MODULES := [
	"res://tests/test_core_logic.gd",
	"res://tests/test_fish_data.gd",
	"res://tests/test_inventory.gd",
	"res://tests/test_scenes.gd",
	"res://tests/test_assets.gd",
]

func _init() -> void:
	var start_time := Time.get_ticks_msec()
	var total_passed := 0
	var total_failed := 0
	var all_details := []

	for module_path in TEST_MODULES:
		var script: GDScript = load(module_path)
		if script == null:
			total_failed += 1
			all_details.append({
				"name": module_path.get_file(),
				"status": "fail",
				"message": "Failed to load test module",
			})
			continue

		var instance: RefCounted = script.new()
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
