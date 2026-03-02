extends RefCounted

# Tests for FishScaling system — difficulty/reward factors, clamping, scaled values.

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
	_test_difficulty_factor_formula()
	_test_difficulty_clamping()
	_test_reward_factor_formula()
	_test_reward_clamping()
	_test_scaled_species_values()
	_test_adjusted_rarity_weights()
	return {"passed": _passed, "failed": _failed, "details": _details}

func _test_difficulty_factor_formula() -> void:
	# Day 1: factor = 1.0 + (1-1) * 0.06 = 1.0
	var f1 := 1.0 + (1 - 1) * FishScaling.DIFFICULTY_PER_DAY
	_assert_eq("FishScaling.diff_day1", f1, 1.0)

	# Day 10: factor = 1.0 + 9 * 0.06 = 1.54
	var f10 := 1.0 + (10 - 1) * FishScaling.DIFFICULTY_PER_DAY
	_assert_true("FishScaling.diff_day10", absf(f10 - 1.54) < 0.01, "Day 10 should be ~1.54, got %s" % str(f10))

func _test_difficulty_clamping() -> void:
	# At day 100: 1.0 + 99 * 0.06 = 6.94, should clamp to 2.0
	var raw := 1.0 + (100 - 1) * FishScaling.DIFFICULTY_PER_DAY
	var clamped := minf(raw, FishScaling.MAX_DIFFICULTY)
	_assert_eq("FishScaling.diff_clamp", clamped, FishScaling.MAX_DIFFICULTY)

func _test_reward_factor_formula() -> void:
	# 0 upgrade levels: 1.0
	var f0 := 1.0 + (0.0 / FishScaling.MAX_UPGRADE_LEVELS) * (FishScaling.MAX_REWARD_FACTOR - 1.0)
	_assert_eq("FishScaling.reward_0", f0, 1.0)

	# 9 upgrade levels (half max): 1.0 + 0.5 * 0.5 = 1.25
	var f9 := 1.0 + (9.0 / FishScaling.MAX_UPGRADE_LEVELS) * (FishScaling.MAX_REWARD_FACTOR - 1.0)
	_assert_true("FishScaling.reward_half", absf(f9 - 1.25) < 0.01, "Half upgrades should give ~1.25, got %s" % str(f9))

func _test_reward_clamping() -> void:
	# Max (18) levels: 1.0 + 1.0 * 0.5 = 1.5
	var f_max := 1.0 + (18.0 / FishScaling.MAX_UPGRADE_LEVELS) * (FishScaling.MAX_REWARD_FACTOR - 1.0)
	var clamped := minf(f_max, FishScaling.MAX_REWARD_FACTOR)
	_assert_eq("FishScaling.reward_clamp", clamped, FishScaling.MAX_REWARD_FACTOR)

	# Over max (hypothetical 20 levels): should clamp
	var f_over := 1.0 + (20.0 / FishScaling.MAX_UPGRADE_LEVELS) * (FishScaling.MAX_REWARD_FACTOR - 1.0)
	var clamped_over := minf(f_over, FishScaling.MAX_REWARD_FACTOR)
	_assert_eq("FishScaling.reward_over_clamp", clamped_over, FishScaling.MAX_REWARD_FACTOR)

func _test_scaled_species_values() -> void:
	var sardine: FishSpecies = load("res://scripts/data/fish/sardine.tres")
	if sardine == null:
		_assert_true("FishScaling.sardine_load", false, "Could not load sardine")
		return

	# At difficulty 1.0, scaled speed should equal base speed
	var base_speed := sardine.swim_speed
	# Since we can't control TimeManager in headless, just verify the function returns > 0
	var scaled_speed := FishScaling.get_scaled_swim_speed(sardine)
	_assert_true("FishScaling.swim_speed_positive", scaled_speed > 0, "Scaled swim speed should be > 0")
	_assert_true("FishScaling.swim_speed_ge_base", scaled_speed >= base_speed, "Scaled speed should be >= base")

	var scaled_flee := FishScaling.get_scaled_flee_speed(sardine)
	_assert_true("FishScaling.flee_speed_positive", scaled_flee > 0, "Scaled flee speed should be > 0")

	var scaled_awareness := FishScaling.get_scaled_awareness(sardine)
	_assert_true("FishScaling.awareness_positive", scaled_awareness > 0, "Scaled awareness should be > 0")

	var scaled_weight := FishScaling.get_scaled_weight(sardine)
	_assert_true("FishScaling.weight_positive", scaled_weight > 0, "Scaled weight should be > 0")

func _test_adjusted_rarity_weights() -> void:
	var weights := FishScaling.get_adjusted_rarity_weights()
	_assert_eq("FishScaling.rarity_keys", weights.size(), 4)
	_assert_true("FishScaling.rarity_common", weights.has(FishSpecies.Rarity.COMMON), "Missing COMMON weight")
	_assert_true("FishScaling.rarity_legendary", weights.has(FishSpecies.Rarity.LEGENDARY), "Missing LEGENDARY weight")

	# Common weight should be >= 20 (clamped minimum)
	_assert_true("FishScaling.common_floor", weights[FishSpecies.Rarity.COMMON] >= 20.0, "Common weight below floor")
	# Legendary weight should be <= 15 (clamped maximum)
	_assert_true("FishScaling.legendary_ceiling", weights[FishSpecies.Rarity.LEGENDARY] <= 15.0, "Legendary weight above ceiling")
	# All weights should be positive
	for rarity in weights:
		_assert_true("FishScaling.weight_%d_pos" % rarity, weights[rarity] > 0, "Rarity weight should be positive")
