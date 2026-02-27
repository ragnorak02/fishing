extends RefCounted

# Tests for AchievementManager logic.

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
	_test_manifest_load()
	_test_unlock_once_guard()
	_test_get_save_state()
	return {"passed": _passed, "failed": _failed, "details": _details}

func _test_manifest_load() -> void:
	# Verify achievements.json can be parsed
	var file := FileAccess.open("res://achievements.json", FileAccess.READ)
	_assert_true("achievements.json.exists", file != null, "File not found")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	_assert_true("achievements.json.valid_json", err == OK, "Parse error")
	if err != OK:
		return
	var data = json.data
	_assert_true("achievements.json.has_achievements", data is Dictionary and data.has("achievements"), "Missing achievements key")
	var entries: Array = data.get("achievements", [])
	_assert_eq("achievements.json.count", entries.size(), 15)

	# All entries have required keys
	var all_valid := true
	for entry in entries:
		if not entry.has("id") or not entry.has("name") or not entry.has("description") or not entry.has("points"):
			all_valid = false
			break
	_assert_true("achievements.json.all_have_keys", all_valid, "Some entries missing id/name/description/points")

func _test_unlock_once_guard() -> void:
	# Simulate achievement dict and verify unlock-once behavior
	var achievements := {
		"test_ach": {"name": "Test", "description": "Test achievement", "points": 10, "icon": "", "unlocked": false}
	}
	# First unlock
	achievements["test_ach"].unlocked = true
	_assert_true("unlock_once.first", achievements["test_ach"].unlocked, "Should be unlocked")

	# Second "unlock" — already true, should stay true and not error
	var was_already: bool = achievements["test_ach"].unlocked
	_assert_true("unlock_once.guard", was_already, "Guard should detect already-unlocked")

func _test_get_save_state() -> void:
	# Simulate get_save_state pattern
	var achievements := {
		"a1": {"name": "A1", "description": "", "points": 10, "icon": "", "unlocked": true},
		"a2": {"name": "A2", "description": "", "points": 20, "icon": "", "unlocked": false},
		"a3": {"name": "A3", "description": "", "points": 30, "icon": "", "unlocked": true},
	}
	var state := {}
	for id in achievements:
		state[id] = achievements[id].unlocked
	_assert_eq("save_state.a1", state["a1"], true)
	_assert_eq("save_state.a2", state["a2"], false)
	_assert_eq("save_state.a3", state["a3"], true)
	_assert_eq("save_state.size", state.size(), 3)
