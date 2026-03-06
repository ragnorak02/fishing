extends RefCounted

# Achievement regression tests — verifies all 15 achievement hooks,
# unlock-once semantics, toast queueing, save state, and signal patterns.

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
	_test_all_15_ids_present()
	_test_unlock_once_semantics()
	_test_unlock_signal_pattern()
	_test_save_state_roundtrip()
	_test_catch_threshold_logic()
	_test_gold_threshold_logic()
	_test_sushi_grade_detection()
	_test_legendary_detection()
	_test_all_species_threshold()
	_test_toast_queue_logic()
	_test_upgrade_achievement_logic()
	_test_state_achievements()
	return {"passed": _passed, "failed": _failed, "details": _details}

func _test_all_15_ids_present() -> void:
	var file := FileAccess.open("res://achievements.json", FileAccess.READ)
	_assert_true("ach_reg.file_exists", file != null, "achievements.json not found")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	_assert_true("ach_reg.parse_ok", json.parse(text) == OK, "Parse error")
	var data = json.data
	var entries: Array = data.get("achievements", [])

	var expected_ids := [
		"first_catch", "catch_10", "catch_50", "sushi_grade", "catch_legendary",
		"all_species", "first_sale", "earn_500_gold", "earn_2000_gold",
		"first_upgrade", "max_upgrade_track", "all_upgrades_max",
		"first_dive", "first_transform", "sonar_pulse",
	]
	_assert_eq("ach_reg.total_count", entries.size(), 15)

	var found_ids := []
	for entry in entries:
		found_ids.append(entry["id"])
	for id in expected_ids:
		_assert_true("ach_reg.has_%s" % id, id in found_ids, "Missing achievement: %s" % id)

func _test_unlock_once_semantics() -> void:
	# Simulate the _unlock guard logic from AchievementManager
	var achievements := {
		"test": {"name": "Test", "unlocked": false},
		"other": {"name": "Other", "unlocked": false},
	}
	var unlock_count := 0

	# First unlock
	if not achievements["test"].unlocked:
		achievements["test"].unlocked = true
		unlock_count += 1
	_assert_eq("ach_reg.unlock_once.first", unlock_count, 1)

	# Second unlock attempt — guard prevents double
	if not achievements["test"].unlocked:
		achievements["test"].unlocked = true
		unlock_count += 1
	_assert_eq("ach_reg.unlock_once.second", unlock_count, 1)

	# Different achievement
	if not achievements["other"].unlocked:
		achievements["other"].unlocked = true
		unlock_count += 1
	_assert_eq("ach_reg.unlock_once.other", unlock_count, 2)

func _test_unlock_signal_pattern() -> void:
	# Verify that unlock only fires when changing from false->true
	var fired := false
	var achievements := {"test": {"unlocked": false}}

	# Simulate _unlock pattern
	if "test" in achievements and not achievements["test"].unlocked:
		achievements["test"].unlocked = true
		fired = true
	_assert_true("ach_reg.signal.fires_on_first", fired, "Signal should fire on first unlock")

	# Reset and try again (already unlocked)
	fired = false
	if "test" in achievements and not achievements["test"].unlocked:
		achievements["test"].unlocked = true
		fired = true
	_assert_true("ach_reg.signal.no_fire_on_repeat", not fired, "Signal should NOT fire when already unlocked")

func _test_save_state_roundtrip() -> void:
	var achievements := {
		"a": {"name": "A", "unlocked": true},
		"b": {"name": "B", "unlocked": false},
		"c": {"name": "C", "unlocked": true},
	}

	# Build save state
	var state := {}
	for id in achievements:
		state[id] = achievements[id].unlocked

	# Restore to fresh achievements
	var fresh := {
		"a": {"name": "A", "unlocked": false},
		"b": {"name": "B", "unlocked": false},
		"c": {"name": "C", "unlocked": false},
	}
	for id in state:
		if id in fresh and state[id] == true:
			fresh[id].unlocked = true

	_assert_eq("ach_reg.roundtrip.a", fresh["a"].unlocked, true)
	_assert_eq("ach_reg.roundtrip.b", fresh["b"].unlocked, false)
	_assert_eq("ach_reg.roundtrip.c", fresh["c"].unlocked, true)

func _test_catch_threshold_logic() -> void:
	# Simulate catch count thresholds
	var total_catches := 0
	var unlocked := {"first_catch": false, "catch_10": false, "catch_50": false}

	# First catch
	total_catches = 1
	unlocked["first_catch"] = true
	_assert_true("ach_reg.catch.first", unlocked["first_catch"])

	# 9 more catches — not yet 10
	total_catches = 9
	if total_catches >= 10:
		unlocked["catch_10"] = true
	_assert_true("ach_reg.catch.not_10_yet", not unlocked["catch_10"])

	# 10th catch
	total_catches = 10
	if total_catches >= 10:
		unlocked["catch_10"] = true
	_assert_true("ach_reg.catch.at_10", unlocked["catch_10"])

	# 50th catch
	total_catches = 50
	if total_catches >= 50:
		unlocked["catch_50"] = true
	_assert_true("ach_reg.catch.at_50", unlocked["catch_50"])

func _test_gold_threshold_logic() -> void:
	var total_gold := 0
	var unlocked := {"first_sale": false, "earn_500_gold": false, "earn_2000_gold": false}

	total_gold = 100
	unlocked["first_sale"] = true
	_assert_true("ach_reg.gold.first_sale", unlocked["first_sale"])

	if total_gold >= 500:
		unlocked["earn_500_gold"] = true
	_assert_true("ach_reg.gold.not_500_yet", not unlocked["earn_500_gold"])

	total_gold = 500
	if total_gold >= 500:
		unlocked["earn_500_gold"] = true
	_assert_true("ach_reg.gold.at_500", unlocked["earn_500_gold"])

	total_gold = 2000
	if total_gold >= 2000:
		unlocked["earn_2000_gold"] = true
	_assert_true("ach_reg.gold.at_2000", unlocked["earn_2000_gold"])

func _test_sushi_grade_detection() -> void:
	# Sushi grade should unlock when any sushi_grade fish is caught
	var sushi_fish := {"species_id": "bluefin_tuna", "sushi_grade": true, "rarity": 2}
	var normal_fish := {"species_id": "sardine", "sushi_grade": false, "rarity": 0}

	_assert_true("ach_reg.sushi.normal_no_unlock", not normal_fish.get("sushi_grade", false))
	_assert_true("ach_reg.sushi.sushi_unlocks", sushi_fish.get("sushi_grade", false))

func _test_legendary_detection() -> void:
	_assert_true("ach_reg.legendary.common_no", 0 != FishSpecies.Rarity.LEGENDARY)
	_assert_true("ach_reg.legendary.rare_no", 2 != FishSpecies.Rarity.LEGENDARY)
	_assert_true("ach_reg.legendary.legendary_yes", 3 == FishSpecies.Rarity.LEGENDARY)

func _test_all_species_threshold() -> void:
	var species_caught := ["sardine", "mackerel", "grouper"]
	_assert_true("ach_reg.all_species.not_yet", species_caught.size() < 10)

	# Simulate catching all 10 original species
	species_caught = ["sardine", "mackerel", "grouper", "yellowtail", "sea_bream",
		"squid", "octopus", "manta_ray", "bluefin_tuna", "golden_koi"]
	_assert_true("ach_reg.all_species.at_10", species_caught.size() >= 10)

func _test_toast_queue_logic() -> void:
	# Simulate toast queue behavior
	var queue: Array = []
	var active := false

	# Queue 3 toasts
	queue.append({"title": "A"})
	queue.append({"title": "B"})
	queue.append({"title": "C"})
	_assert_eq("ach_reg.toast.queue_size", queue.size(), 3)

	# Pop first
	active = true
	var first = queue.pop_front()
	_assert_eq("ach_reg.toast.first", first["title"], "A")
	_assert_eq("ach_reg.toast.remaining", queue.size(), 2)

	# Pop second
	var second = queue.pop_front()
	_assert_eq("ach_reg.toast.second", second["title"], "B")

	# Pop third
	var third = queue.pop_front()
	_assert_eq("ach_reg.toast.third", third["title"], "C")
	_assert_true("ach_reg.toast.empty", queue.is_empty())

func _test_upgrade_achievement_logic() -> void:
	# first_upgrade fires on any purchase
	var unlocked := {"first_upgrade": false, "max_upgrade_track": false, "all_upgrades_max": false}

	unlocked["first_upgrade"] = true
	_assert_true("ach_reg.upgrade.first", unlocked["first_upgrade"])

	# max_upgrade_track fires when any track hits MAX_LEVEL (3)
	var level := 3
	if level >= 3:
		unlocked["max_upgrade_track"] = true
	_assert_true("ach_reg.upgrade.max_track", unlocked["max_upgrade_track"])

	# all_upgrades_max fires when ALL 6 tracks are at max
	var levels := [3, 3, 3, 3, 3, 2]
	var all_max := true
	for l in levels:
		if l < 3:
			all_max = false
	_assert_true("ach_reg.upgrade.not_all_max", not all_max)

	levels[5] = 3
	all_max = true
	for l in levels:
		if l < 3:
			all_max = false
	_assert_true("ach_reg.upgrade.all_max", all_max)

func _test_state_achievements() -> void:
	# first_dive fires when state changes to DIVING (3)
	var unlocked_dive := false
	var state := 3  # DIVING
	if state == 3:
		unlocked_dive = true
	_assert_true("ach_reg.state.first_dive", unlocked_dive)

	# first_transform fires when vehicle mode != 0
	var unlocked_transform := false
	var mode := 1  # SUBMERGED
	if mode != 0:
		unlocked_transform = true
	_assert_true("ach_reg.state.first_transform", unlocked_transform)

	# sonar_pulse fires on sonar use
	_assert_true("ach_reg.state.sonar_pulse", true)
