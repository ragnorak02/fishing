extends RefCounted

# Launcher (Lumina) compliance tests — verifies all required JSON files,
# schema contracts, and automation prerequisites.

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
	_test_game_config_json()
	_test_project_status_json()
	_test_achievements_json()
	_test_test_results_json()
	_test_project_godot()
	_test_test_command_exists()
	_test_iso8601_timestamps()
	_test_required_json_keys()
	return {"passed": _passed, "failed": _failed, "details": _details}

func _test_game_config_json() -> void:
	var file := FileAccess.open("res://game.config.json", FileAccess.READ)
	_assert_true("launcher.game_config.exists", file != null, "game.config.json not found")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	_assert_true("launcher.game_config.valid_json", json.parse(text) == OK, "Invalid JSON")
	var data = json.data
	_assert_true("launcher.game_config.is_dict", data is Dictionary, "Root must be Dictionary")

	# Required keys per Lumina contract
	var required := ["id", "title", "engine", "engineVersion", "entryPoint", "testCommand"]
	for key in required:
		_assert_true("launcher.game_config.has_%s" % key, data.has(key), "Missing key: %s" % key)

	_assert_eq("launcher.game_config.id", data.get("id"), "fishing")
	_assert_eq("launcher.game_config.engine", data.get("engine"), "godot")

	# Metadata block
	_assert_true("launcher.game_config.has_metadata", data.has("metadata"), "Missing metadata")
	if data.has("metadata"):
		var meta: Dictionary = data["metadata"]
		_assert_true("launcher.game_config.meta.has_version", meta.has("buildVersion"))
		_assert_true("launcher.game_config.meta.has_progress", meta.has("progressPercent"))

func _test_project_status_json() -> void:
	var file := FileAccess.open("res://project_status.json", FileAccess.READ)
	_assert_true("launcher.project_status.exists", file != null, "project_status.json not found")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	_assert_true("launcher.project_status.valid_json", json.parse(text) == OK, "Invalid JSON")
	var data = json.data
	_assert_true("launcher.project_status.is_dict", data is Dictionary, "Root must be Dictionary")

	# Required top-level keys per Lumina dashboard contract
	var required := ["schemaVersion", "gameId", "title", "lastUpdated", "health", "tech", "features", "milestones", "testing", "links"]
	for key in required:
		_assert_true("launcher.project_status.has_%s" % key, data.has(key), "Missing key: %s" % key)

	_assert_eq("launcher.project_status.gameId", data.get("gameId"), "fishing")

	# Health block
	if data.has("health"):
		var health: Dictionary = data["health"]
		_assert_true("launcher.project_status.health.has_percent", health.has("progressPercent"))
		_assert_true("launcher.project_status.health.has_version", health.has("buildVersion"))
		var pct = health.get("progressPercent", -1)
		_assert_true("launcher.project_status.health.percent_range",
			pct >= 0 and pct <= 100,
			"progressPercent out of range: %s" % str(pct))

	# Testing block
	if data.has("testing"):
		var testing: Dictionary = data["testing"]
		_assert_true("launcher.project_status.testing.has_command", testing.has("testCommand"))
		_assert_true("launcher.project_status.testing.has_status", testing.has("status"))
		_assert_true("launcher.project_status.testing.has_lastRun", testing.has("lastRunAt"))

func _test_achievements_json() -> void:
	var file := FileAccess.open("res://achievements.json", FileAccess.READ)
	_assert_true("launcher.achievements.exists", file != null, "achievements.json not found")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	_assert_true("launcher.achievements.valid_json", json.parse(text) == OK)
	var data = json.data
	_assert_true("launcher.achievements.has_gameId", data.has("gameId"))
	_assert_true("launcher.achievements.has_achievements", data.has("achievements"))
	_assert_true("launcher.achievements.has_meta", data.has("meta"))

func _test_test_results_json() -> void:
	var file := FileAccess.open("res://tests/test-results.json", FileAccess.READ)
	_assert_true("launcher.test_results.exists", file != null, "test-results.json not found")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	_assert_true("launcher.test_results.valid_json", json.parse(text) == OK)
	var data = json.data
	_assert_true("launcher.test_results.is_dict", data is Dictionary)

	var required := ["status", "testsTotal", "testsPassed", "testsFailed", "timestamp"]
	for key in required:
		_assert_true("launcher.test_results.has_%s" % key, data.has(key), "Missing: %s" % key)

	var status = data.get("status", "")
	_assert_true("launcher.test_results.status_valid",
		status == "pass" or status == "fail",
		"Status must be 'pass' or 'fail', got '%s'" % status)

func _test_project_godot() -> void:
	# project.godot must exist and be parseable
	_assert_true("launcher.project_godot.exists",
		FileAccess.file_exists("res://project.godot"),
		"project.godot not found")

	# Verify main scene is set
	var file := FileAccess.open("res://project.godot", FileAccess.READ)
	if file:
		var text := file.get_as_text()
		file.close()
		_assert_true("launcher.project_godot.has_main_scene",
			text.contains("run/main_scene"),
			"No main scene configured")
		_assert_true("launcher.project_godot.has_autoloads",
			text.contains("[autoload]"),
			"No autoloads section")

func _test_test_command_exists() -> void:
	# Verify the test command file exists
	_assert_true("launcher.test_cmd.bat_exists",
		FileAccess.file_exists("res://tests/run-tests.bat"),
		"run-tests.bat not found")
	_assert_true("launcher.test_cmd.script_exists",
		FileAccess.file_exists("res://tests/run_tests.gd"),
		"run_tests.gd not found")

func _test_iso8601_timestamps() -> void:
	# Verify timestamps in project_status.json are ISO8601 minute precision
	var file := FileAccess.open("res://project_status.json", FileAccess.READ)
	if file == null:
		_assert_true("launcher.iso8601.file", false, "Cannot read project_status.json")
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	json.parse(text)
	var data = json.data

	var timestamp: String = data.get("lastUpdated", "")
	_assert_true("launcher.iso8601.not_empty", timestamp.length() > 0, "Empty lastUpdated")
	# ISO8601 minute precision: YYYY-MM-DDTHH:MMZ
	_assert_true("launcher.iso8601.has_T", "T" in timestamp, "Missing T separator")
	_assert_true("launcher.iso8601.has_Z", timestamp.ends_with("Z"), "Missing Z suffix")
	_assert_true("launcher.iso8601.min_length", timestamp.length() >= 17,
		"Timestamp too short for minute precision: %s" % timestamp)

func _test_required_json_keys() -> void:
	# Cross-reference: game.config.json id must match project_status.json gameId
	var config_file := FileAccess.open("res://game.config.json", FileAccess.READ)
	var status_file := FileAccess.open("res://project_status.json", FileAccess.READ)
	if config_file == null or status_file == null:
		_assert_true("launcher.cross_ref.files", false, "Cannot read both files")
		return

	var json := JSON.new()
	json.parse(config_file.get_as_text())
	config_file.close()
	var config_data = json.data

	json.parse(status_file.get_as_text())
	status_file.close()
	var status_data = json.data

	_assert_eq("launcher.cross_ref.id_match",
		config_data.get("id"), status_data.get("gameId"))
